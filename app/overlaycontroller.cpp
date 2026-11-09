#include "overlaycontroller.h"

#include <LayerShellQt/Window>
#include <QGuiApplication>
#include <QMutexLocker>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickWindow>
#include <QScreen>
#include <QTimer>

#include <algorithm>
#include <cstdio>

using LayerWindow = LayerShellQt::Window;

FrozenImageProvider::FrozenImageProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}

QImage FrozenImageProvider::requestImage(const QString &id, QSize *size, const QSize &) {
    const QImage frozen = image(id.section('/', 0, 0));
    if (size) *size = frozen.size();
    return frozen;
}

void FrozenImageProvider::setImages(QHash<QString, QImage> images) {
    QMutexLocker lock(&m_mutex);
    m_images = std::move(images);
}

QImage FrozenImageProvider::image(const QString &screenName) const {
    QMutexLocker lock(&m_mutex);
    return m_images.value(screenName);
}

OverlayController::OverlayController(QQmlEngine *engine, FrozenImageProvider *images, QObject *parent)
    : QObject(parent), m_engine(engine), m_images(images) {
    connect(qApp, &QGuiApplication::screenRemoved, this, [this](QScreen *screen) {
        if (auto window = m_overlays.take(screen)) window->deleteLater();
    });
}

static QQuickWindow *namedWindow(QObject *root, const char *property) {
    return qobject_cast<QQuickWindow *>(root->property(property).value<QObject *>());
}

static void followSize(QQuickWindow *window) {
    auto *layer = LayerWindow::get(window);
    layer->setDesiredSize(window->size());
    QObject::connect(window, &QWindow::widthChanged, window, [window, layer] { layer->setDesiredSize(window->size()); });
    QObject::connect(window, &QWindow::heightChanged, window, [window, layer] { layer->setDesiredSize(window->size()); });
}

void OverlayController::attach(QObject *root) {
    m_recordBar = namedWindow(root, "recordBar");
    m_recordFrame = namedWindow(root, "recordFrame");
    m_statusPill = namedWindow(root, "statusPill");
    m_textFlyout = namedWindow(root, "textFlyout");
    if (!m_recordBar || !m_recordFrame || !m_statusPill || !m_textFlyout) {
        std::fprintf(stderr, "SnipShot could not find its overlay windows\n");
        return;
    }
    configureTopCenter(m_statusPill, 16, false);
    configureTopCenter(m_textFlyout, 72, true);

    for (QQuickWindow *window : {m_recordBar.data(), m_recordFrame.data()}) {
        auto *layer = LayerWindow::get(window);
        layer->setScope("snipshot");
        layer->setLayer(LayerWindow::LayerOverlay);
        layer->setAnchors({LayerWindow::AnchorTop, LayerWindow::AnchorLeft});
        layer->setExclusiveZone(-1);
        layer->setActivateOnShow(false);
        layer->setKeyboardInteractivity(window == m_recordBar ? LayerWindow::KeyboardInteractivityOnDemand
                                                              : LayerWindow::KeyboardInteractivityNone);
        followSize(window);
    }
    connect(m_recordBar, &QWindow::widthChanged, this, [this] {
        if (m_recordRegion.isValid()) placeRecording(m_recordRegion);
    });
}

void OverlayController::configureTopCenter(QQuickWindow *window, int topMargin, bool keyboard) {
    auto *layer = LayerWindow::get(window);
    layer->setScope("snipshot");
    layer->setLayer(LayerWindow::LayerOverlay);
    layer->setAnchors(LayerWindow::AnchorTop);
    layer->setMargins(QMargins(0, topMargin, 0, 0));
    layer->setExclusiveZone(-1);
    layer->setActivateOnShow(false);
    layer->setKeyboardInteractivity(keyboard ? LayerWindow::KeyboardInteractivityOnDemand
                                             : LayerWindow::KeyboardInteractivityNone);
    layer->setWantsToBeOnActiveScreen(true);
    followSize(window);
}

QQuickWindow *OverlayController::overlayFor(QScreen *screen) {
    if (auto existing = m_overlays.value(screen)) return existing;
    QQmlComponent component(m_engine, "SnipShot", "CaptureOverlay");
    QObject *object = component.createWithInitialProperties({{"targetScreen", QVariant::fromValue(screen)}});
    auto *window = qobject_cast<QQuickWindow *>(object);
    if (!window) {
        std::fprintf(stderr, "SnipShot could not create a capture overlay: %s\n", qPrintable(component.errorString()));
        delete object;
        return nullptr;
    }
    window->setScreen(screen);
    auto *layer = LayerWindow::get(window);
    layer->setScope("snipshot");
    layer->setLayer(LayerWindow::LayerOverlay);
    layer->setAnchors({LayerWindow::AnchorTop, LayerWindow::AnchorBottom, LayerWindow::AnchorLeft, LayerWindow::AnchorRight});
    layer->setExclusiveZone(-1);
    layer->setActivateOnShow(true);
    layer->setScreen(screen);
    layer->setDesiredSize(screen->geometry().size());
    window->resize(screen->geometry().size());
    m_overlays.insert(screen, window);
    return window;
}

void OverlayController::showOverlays() {
    QScreen *primary = QGuiApplication::primaryScreen();
    for (QScreen *screen : QGuiApplication::screens()) {
        QQuickWindow *window = overlayFor(screen);
        if (!window) continue;
        LayerWindow::get(window)->setKeyboardInteractivity(screen == primary ? LayerWindow::KeyboardInteractivityExclusive
                                                                             : LayerWindow::KeyboardInteractivityOnDemand);
        window->setVisible(true);
        if (screen == primary) window->requestActivate();
    }
}

void OverlayController::hideOverlays() {
    for (const auto &window : std::as_const(m_overlays)) {
        if (!window || !window->isVisible()) continue;
        LayerWindow::get(window)->setKeyboardInteractivity(LayerWindow::KeyboardInteractivityNone);
        window->update();
        QTimer::singleShot(50, window, [window] { window->setVisible(false); });
    }
}

QScreen *OverlayController::screenFor(const QRect &region) {
    const QPoint center = region.center();
    for (QScreen *screen : QGuiApplication::screens())
        if (screen->geometry().contains(center)) return screen;
    return QGuiApplication::primaryScreen();
}

void OverlayController::placeAt(QQuickWindow *window, QScreen *screen, const QPoint &globalTopLeft) {
    auto *layer = LayerWindow::get(window);
    const bool moveScreen = window->isVisible() && window->screen() != screen;
    if (moveScreen) window->setVisible(false);
    window->setScreen(screen);
    layer->setScreen(screen);
    const QPoint local = globalTopLeft - screen->geometry().topLeft();
    layer->setMargins(QMargins(local.x(), local.y(), 0, 0));
    if (moveScreen) window->setVisible(true);
}

void OverlayController::placeRecording(const QRect &region) {
    if (!m_recordBar || !m_recordFrame) return;
    m_recordRegion = region;
    QScreen *screen = screenFor(region);
    const QRect bounds = screen->geometry();
    const int border = 3;
    m_recordFrame->resize(region.size() + QSize(border * 2, border * 2));
    placeAt(m_recordFrame, screen, region.topLeft() - QPoint(border, border));

    const QSize bar = m_recordBar->size();
    const int gap = 12;
    int y = region.top() - border - gap - bar.height();
    if (y < bounds.top() + gap) y = region.bottom() + border + gap;
    if (y + bar.height() > bounds.bottom() - gap) y = bounds.top() + gap;
    int x = region.center().x() - bar.width() / 2;
    x = std::clamp(x, bounds.left() + gap, std::max(bounds.left() + gap, bounds.right() - gap - bar.width()));
    placeAt(m_recordBar, screen, QPoint(x, y));
}

void OverlayController::raiseRecordBar() {
    if (!m_recordBar || !m_recordBar->isVisible()) return;
    m_recordBar->setVisible(false);
    m_recordBar->setVisible(true);
}
