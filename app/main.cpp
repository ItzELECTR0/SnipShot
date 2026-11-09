#include "capturebackend.h"

#include <LayerShellQt/Window>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QMargins>
#include <QProcess>
#include <QQuickWindow>
#include <QScreen>
#include <QTimer>
#include <QUrl>

#include <cstdio>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("SnipShot");
    QGuiApplication::setOrganizationName("SnipShot");

    CaptureBackend backend;
    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, &app,
                     [](const QList<QQmlError> &warnings) {
                         for (const auto &warning : warnings)
                             std::fprintf(stderr, "%s\n", qPrintable(warning.toString()));
                     });
    engine.rootContext()->setContextProperty("capture", &backend);
    engine.load(QUrl("qrc:/qt/qml/SnipShot/Main.qml"));
    if (engine.rootObjects().isEmpty()) {
        std::fprintf(stderr, "SnipShot could not load its QML interface\n");
        return 1;
    }

    auto *toolbar = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
    auto *outline = toolbar ? toolbar->findChild<QQuickWindow *>("recordingOutline") : nullptr;
    auto *textResult = toolbar ? toolbar->findChild<QQuickWindow *>("textResultWindow") : nullptr;
    if (!toolbar || !outline || !textResult) {
        std::fprintf(stderr, "SnipShot could not prepare its overlay windows\n");
        return 1;
    }

    auto *toolbarLayer = LayerShellQt::Window::get(toolbar);
    toolbarLayer->setLayer(LayerShellQt::Window::LayerOverlay);
    toolbarLayer->setAnchors({LayerShellQt::Window::AnchorTop, LayerShellQt::Window::AnchorBottom,
                              LayerShellQt::Window::AnchorLeft, LayerShellQt::Window::AnchorRight});
    toolbarLayer->setMargins(QMargins(0, 0, 0, 0));
    toolbarLayer->setExclusiveZone(-1);
    toolbarLayer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityExclusive);
    toolbarLayer->setActivateOnShow(true);
    QScreen *primaryScreen = QGuiApplication::primaryScreen();
    toolbarLayer->setScreen(primaryScreen);
    toolbarLayer->setDesiredSize(primaryScreen->geometry().size());

    auto *outlineLayer = LayerShellQt::Window::get(outline);
    outlineLayer->setLayer(LayerShellQt::Window::LayerOverlay);
    outlineLayer->setAnchors({LayerShellQt::Window::AnchorTop, LayerShellQt::Window::AnchorLeft});
    outlineLayer->setExclusiveZone(-1);
    outlineLayer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
    outlineLayer->setActivateOnShow(false);

    auto *textResultLayer = LayerShellQt::Window::get(textResult);
    textResultLayer->setLayer(LayerShellQt::Window::LayerOverlay);
    textResultLayer->setAnchors(LayerShellQt::Window::AnchorTop);
    textResultLayer->setMargins(QMargins(0, 92, 0, 0));
    textResultLayer->setExclusiveZone(-1);
    textResultLayer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityOnDemand);
    textResultLayer->setActivateOnShow(false);
    textResultLayer->setScreen(QGuiApplication::primaryScreen());
    textResultLayer->setDesiredSize(textResult->size());

    QObject::connect(&backend, &CaptureBackend::recordingRegionChanged, &app,
                     [toolbar, outline, outlineLayer, textResultLayer, &backend] {
        const QRect region(backend.recordingX(), backend.recordingY(), backend.recordingWidth(), backend.recordingHeight());
        QScreen *screen = nullptr;
        for (auto *candidate : QGuiApplication::screens()) {
            const QRect geometry = candidate->geometry();
            if (geometry.contains(region.topLeft()) && geometry.contains(region.bottomRight())) {
                screen = candidate;
                break;
            }
        }
        if (!screen) return;
        toolbar->setScreen(screen);
        outlineLayer->setScreen(screen);
        textResultLayer->setScreen(screen);
        outlineLayer->setMargins(QMargins(region.x() - screen->geometry().x() - 3,
                                           region.y() - screen->geometry().y() - 3, 0, 0));
        outlineLayer->setDesiredSize(region.size() + QSize(6, 6));
        outline->resize(region.size() + QSize(6, 6));
    });
    QObject::connect(&backend, &CaptureBackend::recordingChanged, &app,
                     [toolbar, toolbarLayer, primaryScreen, &backend] {
        if (backend.recording()) {
            toolbarLayer->setAnchors(LayerShellQt::Window::AnchorTop);
            toolbarLayer->setMargins(QMargins(0, 16, 0, 0));
            toolbarLayer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityOnDemand);
            toolbarLayer->setDesiredSize(QSize(434, 68));
            toolbar->setScreen(primaryScreen);
            toolbar->setVisible(true);
        } else {
            toolbar->setVisible(false);
        }
    });
    QObject::connect(&backend, &CaptureBackend::previewOpenChanged, &app,
                     [&app, &backend] {
        if (!backend.previewOpen() || qEnvironmentVariableIsEmpty("HYPRLAND_INSTANCE_SIGNATURE")) return;
        const QString title = backend.resultType() == "image" ? "Screenshot preview" : "Recording preview";
        QTimer::singleShot(150, &app, [title] {
            const QString command = QStringLiteral(
                "local title = '%1'; for _, w in ipairs(hl.get_windows({ title = title })) do "
                "if w.title == title then hl.dispatch(hl.dsp.window.float({ action = 'set', window = w })); "
                "hl.dispatch(hl.dsp.window.center({ window = w })); end end").arg(title);
            QProcess::startDetached("hyprctl", {"eval", command});
        });
    });

    toolbar->setVisible(true);
    return app.exec();
}
