#include "capturebackend.h"
#include "core.h"
#include "instance.h"
#include "overlaycontroller.h"
#include "settings.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QMetaObject>
#include <QMimeData>
#include <QMutex>
#include <QPainter>
#include <QPainterPath>
#include <QPointer>
#include <QProcess>
#include <QSaveFile>
#include <QScreen>
#include <QStandardPaths>
#include <QThreadPool>
#include <QUuid>

#include <array>
#include <atomic>
#include <memory>
#include <utility>
#include <vector>

namespace {
template <typename Work, typename Done>
void inBackground(CaptureBackend *owner, Work work, Done done) {
    QPointer<CaptureBackend> self(owner);
    QThreadPool::globalInstance()->start([self, work, done]() mutable {
        auto result = work();
        if (!self) return;
        QMetaObject::invokeMethod(self, [self, done, result]() mutable {
            if (self) done(result);
        }, Qt::QueuedConnection);
    });
}

QString text(const char *data) { return QString::fromUtf8(data); }

QString runtimeFolder() {
    std::array<char, 4096> path{};
    snipshot_temp_path("", path.data(), path.size());
    return text(path.data());
}

bool recordingState(const QString &state) {
    return state == "countdown" || state == "starting" || state == "recording" || state == "finishing";
}
}

CaptureBackend::CaptureBackend(Settings *settings, QObject *parent) : QObject(parent), m_settings(settings) {
    m_mode = m_settings->text("snipMode");
    QDBusConnection::sessionBus().connect("org.freedesktop.Notifications", "/org/freedesktop/Notifications",
                                          "org.freedesktop.Notifications", "ActionInvoked", this,
                                          SLOT(notificationAction(uint,QString)));
    m_elapsedTicker.setInterval(200);
    connect(&m_elapsedTicker, &QTimer::timeout, this, &CaptureBackend::elapsedChanged);
    m_countdownTimer.setInterval(1000);
    connect(&m_countdownTimer, &QTimer::timeout, this, [this] {
        setCountdown(m_countdown - 1);
        if (m_state == "delaying") {
            if (m_countdown > 0) {
                showPill(tr("Snipping in %1").arg(m_countdown), "timer_regular", true, 0);
                return;
            }
            m_countdownTimer.stop();
            hidePill();
            QTimer::singleShot(150, this, &CaptureBackend::freeze);
        } else if (m_state == "countdown" && m_countdown <= 0) {
            m_countdownTimer.stop();
            beginRecorder();
        }
    });
    m_pillTimer.setSingleShot(true);
    connect(&m_pillTimer, &QTimer::timeout, this, &CaptureBackend::hidePill);
    connect(m_settings, &QQmlPropertyMap::valueChanged, this, [this](const QString &key) {
        if (key == "microphone") emit microphoneChanged();
        if (key == "systemAudio") emit systemAudioChanged();
    });
    loadOcrLanguages();
}

CaptureBackend::~CaptureBackend() {
    if (recordingState(m_state)) {
        std::array<char, 512> error{};
        snipshot_record_stop(error.data(), error.size());
    }
}

void CaptureBackend::handleCommand(const QStringList &arguments) {
    QString command = "open";
    QString fullscreen;
    int delay = -1;
    for (int index = 0; index < arguments.size(); ++index) {
        const QString &argument = arguments.at(index);
        if (argument == "--delay" && index + 1 < arguments.size()) {
            delay = arguments.at(++index).toInt();
        } else if (argument == "--mode" && index + 1 < arguments.size()) {
            setMode(arguments.at(++index));
        } else if (argument == "--fullscreen") {
            const QString next = arguments.value(index + 1);
            fullscreen = next == "focused" || next == "all" ? arguments.at(++index) : "all";
        } else if (!argument.startsWith("--")) {
            command = argument;
        } else if (argument == "--daemon") {
            command.clear();
        }
    }
    if (command == "open") showMain();
    else if (command == "snip") {
        if (m_state == "idle") m_fullscreen = fullscreen;
        start("snip", delay);
    }
    else if (command == "text") start("text", delay);
    else if (command == "record") recordingState(m_state) ? stopRecording() : start("record", delay);
    else if (command == "stop") stopRecording();
    else if (command == "pause") togglePause();
    else if (command == "settings") showSettings();
    else if (command == "quit") quit();
}

qint64 CaptureBackend::elapsed() const {
    if (m_state != "recording" && m_state != "finishing") return m_elapsedBefore;
    return m_elapsedBefore + (m_paused || !m_segmentClock.isValid() ? 0 : m_segmentClock.elapsed());
}

bool CaptureBackend::microphone() const { return m_settings->flag("microphone"); }
bool CaptureBackend::systemAudio() const { return m_settings->flag("systemAudio"); }
QUrl CaptureBackend::resultUrl() const { return m_resultPath.isEmpty() ? QUrl() : QUrl::fromLocalFile(m_resultPath); }

QVariantList CaptureBackend::recorderBackends() const {
    QVariantList backends;
    const std::array<std::pair<int, QString>, 3> entries{{
        {SNIPSHOT_BACKEND_AUTO, tr("Automatic")},
        {SNIPSHOT_BACKEND_GPU_SCREEN_RECORDER, QStringLiteral("gpu-screen-recorder")},
        {SNIPSHOT_BACKEND_WF_RECORDER, QStringLiteral("wf-recorder")},
    }};
    for (const auto &[value, name] : entries)
        backends << QVariantMap{{"value", value}, {"name", name}, {"available", snipshot_backend_available(value) != 0}};
    return backends;
}

void CaptureBackend::setState(const QString &state) {
    if (m_state == state) return;
    m_state = state;
    emit stateChanged();
}

void CaptureBackend::setStatus(const QString &status) {
    if (m_status == status) return;
    m_status = status;
    emit statusChanged();
}

void CaptureBackend::setCountdown(int value) {
    if (m_countdown == value) return;
    m_countdown = value;
    emit countdownChanged();
}

void CaptureBackend::setWindows(bool &flag, bool value) {
    if (flag == value) return;
    flag = value;
    emit windowsChanged();
}

void CaptureBackend::setPurpose(const QString &purpose) {
    if (m_purpose == purpose) return;
    m_purpose = purpose;
    if (purpose == "record" && m_mode == "freeform") setMode("rectangle");
    if (m_state == "armed") {
        setState("selecting");
        m_recordRegion = {};
        emit recordRegionChanged();
    }
    resetSelection();
    emit purposeChanged();
}

void CaptureBackend::setMode(const QString &mode) {
    static const QStringList modes{"rectangle", "window", "fullscreen", "freeform"};
    if (!modes.contains(mode) || m_mode == mode) return;
    if (m_purpose == "record" && mode == "freeform") return;
    m_mode = mode;
    m_settings->set("snipMode", mode);
    resetSelection();
    emit modeChanged();
}

void CaptureBackend::setSelection(const QRectF &selection) {
    if (m_selection == selection) return;
    m_selection = selection;
    emit selectionChanged();
}

void CaptureBackend::setFreeformPath(const QVariantList &path) {
    m_freeformPath = path;
    emit freeformPathChanged();
}

void CaptureBackend::setActiveScreen(const QString &screen) {
    if (m_activeScreen == screen) return;
    m_activeScreen = screen;
    emit activeScreenChanged();
}

void CaptureBackend::setMicrophone(bool enabled) {
    m_settings->set("microphone", enabled);
    emit microphoneChanged();
}

void CaptureBackend::setSystemAudio(bool enabled) {
    m_settings->set("systemAudio", enabled);
    emit systemAudioChanged();
}

void CaptureBackend::resetSelection() {
    setSelection({});
    if (!m_freeformPath.isEmpty()) setFreeformPath({});
}

void CaptureBackend::showPill(const QString &text, const QString &icon, bool busy, int timeoutMs) {
    m_pillText = text;
    m_pillIcon = icon;
    m_pillBusy = busy;
    m_pillVisible = true;
    emit pillChanged();
    if (timeoutMs > 0) m_pillTimer.start(timeoutMs);
    else m_pillTimer.stop();
}

void CaptureBackend::hidePill() {
    m_pillTimer.stop();
    if (!m_pillVisible) return;
    m_pillVisible = false;
    emit pillChanged();
}

void CaptureBackend::start(const QString &purpose, int delaySeconds) {
    if (recordingState(m_state)) {
        showPill(tr("A recording is in progress"), "record_filled");
        return;
    }
    if (m_state == "selecting" || m_state == "armed") {
        setPurpose(purpose);
        return;
    }
    if (m_state != "idle") return;

    m_openSnipAfterCapture = m_mainOpen;
    const bool windowsOpen = m_mainOpen || m_settingsOpen || m_pillVisible || m_textOpen;
    setWindows(m_mainOpen, false);
    setWindows(m_textOpen, false);
    hidePill();
    m_purpose.clear();
    setPurpose(purpose);
    const int delay = delaySeconds >= 0 ? delaySeconds : m_settings->number("delay");
    if (delay > 0) {
        setState("delaying");
        setCountdown(delay);
        showPill(tr("Snipping in %1").arg(delay), "timer_regular", true, 0);
        m_countdownTimer.start();
        return;
    }
    setState("freezing");
    QTimer::singleShot(windowsOpen ? 150 : 0, this, &CaptureBackend::freeze);
}

void CaptureBackend::freeze() {
    setState("freezing");
    struct Shared {
        QMutex mutex;
        QHash<QString, QImage> images;
        QVariantList windows;
        bool windowsSupported{false};
        QString focused;
        QString error;
        std::atomic<int> remaining{0};
    };
    auto shared = std::make_shared<Shared>();
    const auto screens = QGuiApplication::screens();
    shared->remaining = int(screens.size()) + 1;
    QPointer<CaptureBackend> self(this);
    auto finished = [self, shared] {
        if (--shared->remaining != 0) return;
        QMetaObject::invokeMethod(self, [self, shared] {
            if (self) self->finishFreeze(shared->images, shared->windows, shared->windowsSupported, shared->focused, shared->error);
        }, Qt::QueuedConnection);
    };
    for (QScreen *screen : screens) {
        const QByteArray name = screen->name().toUtf8();
        QThreadPool::globalInstance()->start([name, shared, finished] {
            std::array<char, 4096> path{};
            std::array<char, 512> error{};
            QImage image;
            if (snipshot_freeze(name.constData(), path.data(), path.size(), error.data(), error.size()) == SNIPSHOT_OK) {
                image.load(text(path.data()), "PPM");
                QFile::remove(text(path.data()));
            }
            {
                QMutexLocker lock(&shared->mutex);
                if (image.isNull()) shared->error = error[0] ? text(error.data()) : QObject::tr("Could not capture %1").arg(QString::fromUtf8(name));
                else shared->images.insert(QString::fromUtf8(name), image);
            }
            finished();
        });
    }
    QThreadPool::globalInstance()->start([shared, finished, focusedOnly = m_fullscreen == "focused"] {
        if (focusedOnly) {
            std::array<char, 256> name{};
            std::array<char, 512> error{};
            const bool found = snipshot_focused_output(name.data(), name.size(), error.data(), error.size()) == SNIPSHOT_OK;
            QMutexLocker lock(&shared->mutex);
            if (found) shared->focused = text(name.data());
            else shared->error = text(error.data());
        }
        std::array<char, 65536> rects{};
        std::array<char, 512> error{};
        const int result = snipshot_windows(rects.data(), rects.size(), error.data(), error.size());
        QVariantList windows;
        if (result == SNIPSHOT_OK) {
            for (const QString &line : text(rects.data()).split('\n', Qt::SkipEmptyParts)) {
                const QStringList parts = line.split(' ');
                if (parts.size() == 4)
                    windows << QRectF(parts[0].toDouble(), parts[1].toDouble(), parts[2].toDouble(), parts[3].toDouble());
            }
        }
        {
            QMutexLocker lock(&shared->mutex);
            shared->windows = windows;
            shared->windowsSupported = result == SNIPSHOT_OK;
        }
        finished();
    });
}

void CaptureBackend::finishFreeze(QHash<QString, QImage> images, QVariantList windows, bool windowsSupported, QString focused,
                                  QString error) {
    if (m_state != "freezing") return;
    const QString fullscreen = std::exchange(m_fullscreen, QString());
    if (!error.isEmpty() || images.isEmpty()) {
        setState("idle");
        setStatus(error);
        showPill(error.isEmpty() ? tr("Could not capture the screen") : error, "dismiss_regular", false, 5000);
        if (m_openSnipAfterCapture) setWindows(m_mainOpen, true);
        return;
    }
    m_overlays->images()->setImages(std::move(images));
    if (!fullscreen.isEmpty()) {
        QRectF rect;
        for (QScreen *screen : QGuiApplication::screens())
            if (fullscreen == "all" || screen->name() == focused) rect |= QRectF(screen->geometry());
        if (rect.isEmpty()) {
            m_overlays->images()->setImages({});
            setState("idle");
            showPill(tr("Could not find the focused screen"), "dismiss_regular", false, 5000);
            return;
        }
        const QImage image = compose(rect, {});
        m_overlays->images()->setImages({});
        setState("processing");
        finishSnip(image, false);
        return;
    }
    ++m_frozenSerial;
    emit frozenSerialChanged();
    m_windowRects = windows;
    m_windowModeAvailable = windowsSupported;
    emit windowRectsChanged();
    if (m_mode == "window" && !windowsSupported) setMode("rectangle");
    resetSelection();
    setActiveScreen(QGuiApplication::primaryScreen()->name());
    setState("selecting");
    m_overlays->showOverlays();
}

void CaptureBackend::cancel() {
    if (m_state == "delaying") m_fullscreen.clear();
    if (m_state == "delaying" || m_state == "countdown") m_countdownTimer.stop();
    if (m_state == "delaying") hidePill();
    if (m_state == "selecting" || m_state == "armed" || m_state == "countdown") {
        m_overlays->hideOverlays();
        m_overlays->images()->setImages({});
    }
    if (m_state == "delaying" || m_state == "selecting" || m_state == "armed" || m_state == "countdown") {
        resetSelection();
        m_recordRegion = {};
        emit recordRegionChanged();
        setState("idle");
        if (m_openSnipAfterCapture) setWindows(m_mainOpen, true);
    }
}

QString CaptureBackend::screenNameAt(const QPointF &globalPoint) const {
    for (QScreen *screen : QGuiApplication::screens())
        if (QRectF(screen->geometry()).contains(globalPoint)) return screen->name();
    return {};
}

void CaptureBackend::commit() {
    if (m_state != "selecting" && m_state != "armed") return;
    QRectF desktop;
    for (QScreen *screen : QGuiApplication::screens()) desktop |= QRectF(screen->geometry());
    const QRectF rect = m_selection.normalized().intersected(desktop);
    if (rect.width() < 2 || rect.height() < 2) return;

    if (m_purpose == "record") {
        QRect region = rect.toAlignedRect();
        region = region.intersected(OverlayController::screenFor(region)->geometry());
        m_recordRegion = region;
        emit recordRegionChanged();
        m_overlays->placeRecording(region);
        setState("armed");
        return;
    }

    const QImage image = compose(rect, m_mode == "freeform" ? m_freeformPath : QVariantList{});
    m_overlays->hideOverlays();
    m_overlays->images()->setImages({});
    resetSelection();
    setState("processing");
    finishSnip(image, m_purpose == "text");
}

QImage CaptureBackend::compose(const QRectF &rect, const QVariantList &path) const {
    const auto screens = QGuiApplication::screens();
    qreal scale = 1;
    for (QScreen *screen : screens) {
        const QImage image = m_overlays->images()->image(screen->name());
        if (!image.isNull() && rect.intersects(screen->geometry()))
            scale = std::max(scale, qreal(image.width()) / screen->geometry().width());
    }
    const QSize size = (rect.size() * scale).toSize();
    QImage output(size, QImage::Format_ARGB32_Premultiplied);
    output.fill(Qt::transparent);
    QPainter painter(&output);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);

    QPainterPath outline;
    if (path.size() > 2) {
        for (int index = 0; index < path.size(); ++index) {
            const QPointF point = (path.at(index).toPointF() - rect.topLeft()) * scale;
            index == 0 ? outline.moveTo(point) : outline.lineTo(point);
        }
        outline.closeSubpath();
        painter.setRenderHint(QPainter::Antialiasing);
        painter.setClipPath(outline);
    }
    for (QScreen *screen : screens) {
        const QRectF geometry = screen->geometry();
        const QRectF overlap = rect.intersected(geometry);
        const QImage image = m_overlays->images()->image(screen->name());
        if (overlap.isEmpty() || image.isNull()) continue;
        const qreal ratio = qreal(image.width()) / geometry.width();
        const QRectF source((overlap.topLeft() - geometry.topLeft()) * ratio, overlap.size() * ratio);
        const QRectF target((overlap.topLeft() - rect.topLeft()) * scale, overlap.size() * scale);
        painter.drawImage(target, image, source);
    }
    if (m_settings->flag("border")) {
        painter.setClipping(false);
        const qreal width = std::max(1, m_settings->number("borderWidth")) * scale;
        QPen pen(QColor(m_settings->text("borderColor")), width);
        pen.setJoinStyle(Qt::MiterJoin);
        painter.setPen(pen);
        painter.setBrush(Qt::NoBrush);
        if (!outline.isEmpty()) painter.drawPath(outline);
        else painter.drawRect(QRectF(output.rect()).adjusted(width / 2, width / 2, -width / 2, -width / 2));
    }
    painter.end();
    return outline.isEmpty() ? output.convertToFormat(QImage::Format_RGB32) : output;
}

void CaptureBackend::finishSnip(QImage image, bool extractText) {
    struct Outcome {
        QString path;
        QString text;
        QString error;
        int copied{SNIPSHOT_FAILED};
        bool saved{false};
    };
    const bool autoSave = m_settings->flag("autoSave");
    const bool autoCopy = m_settings->flag("autoCopy");
    const QByteArray folder = m_settings->text("screenshotFolder").toUtf8();
    const QByteArray languages = m_settings->text("ocrLanguages").toUtf8();
    if (extractText) showPill(tr("Reading text"), "scan_text_regular", true, 0);

    inBackground(this, [=] {
        Outcome outcome;
        std::array<char, 4096> path{};
        std::array<char, 512> error{};
        if (extractText) {
            snipshot_temp_path("ocr.png", path.data(), path.size());
            if (!image.save(text(path.data()), "PNG")) {
                outcome.error = QObject::tr("Could not prepare the image for text recognition");
                return outcome;
            }
            std::vector<char> recognized(1 << 20);
            if (snipshot_ocr(path.data(), languages.constData(), recognized.data(), recognized.size(), error.data(), error.size()) != SNIPSHOT_OK)
                outcome.error = text(error.data());
            else
                outcome.text = text(recognized.data());
            QFile::remove(text(path.data()));
            if (!outcome.text.isEmpty()) outcome.copied = snipshot_copy_text(recognized.data());
            return outcome;
        }
        const QByteArray directory = autoSave ? folder : runtimeFolder().toUtf8();
        if (snipshot_output_path(SNIPSHOT_KIND_SCREENSHOT, directory.constData(), "png", path.data(), path.size(), error.data(), error.size()) != SNIPSHOT_OK) {
            outcome.error = text(error.data());
            return outcome;
        }
        outcome.path = text(path.data());
        if (!image.save(outcome.path, "PNG")) {
            outcome.error = QObject::tr("Could not write %1").arg(outcome.path);
            return outcome;
        }
        outcome.saved = autoSave;
        if (autoCopy) outcome.copied = snipshot_copy_file(path.data(), "image/png");
        return outcome;
    }, [this, image, extractText, autoCopy](Outcome outcome) {
        setState("idle");
        if (!outcome.error.isEmpty()) {
            setStatus(outcome.error);
            showPill(outcome.error, "dismiss_regular", false, 5000);
            return;
        }
        if (extractText) {
            m_recognizedText = outcome.text;
            emit recognizedTextChanged();
            if (outcome.text.isEmpty()) {
                showPill(tr("No text found in that area"), "scan_text_regular");
                return;
            }
            if (outcome.copied == SNIPSHOT_UNSUPPORTED) QGuiApplication::clipboard()->setText(outcome.text);
            showPill(outcome.copied == SNIPSHOT_FAILED ? tr("Text extracted") : tr("Text copied to clipboard"), "checkmark_regular");
            setWindows(m_textOpen, true);
            return;
        }
        if (autoCopy && outcome.copied == SNIPSHOT_UNSUPPORTED) QGuiApplication::clipboard()->setImage(image);
        const bool copied = autoCopy && outcome.copied != SNIPSHOT_FAILED;
        setResult(outcome.path, "image", image.size(), outcome.saved);
        const QString title = copied ? tr("Snip copied to clipboard") : outcome.saved ? tr("Snip saved") : tr("Snip ready");
        showPill(title, "checkmark_regular");
        setStatus(title);
        if (m_openSnipAfterCapture) showSnip();
        else sendResultNotification(title, tr("Select to open it in SnipShot"));
    });
}

void CaptureBackend::startRecording() {
    if (m_state != "armed" || !m_recordRegion.isValid()) return;
    m_overlays->hideOverlays();
    m_overlays->images()->setImages({});
    resetSelection();
    m_elapsedBefore = 0;
    m_segmentClock.invalidate();
    emit elapsedChanged();
    setState("countdown");
    setCountdown(3);
    m_countdownTimer.start();
}

void CaptureBackend::beginRecorder() {
    setState("starting");
    SnipShotRecordOptions options{};
    options.region = {m_recordRegion.x(), m_recordRegion.y(), m_recordRegion.width(), m_recordRegion.height()};
    options.backend = m_settings->number("recorderBackend");
    options.microphone = microphone();
    options.system_audio = systemAudio();
    options.framerate = m_settings->number("framerate");
    const QByteArray folder = m_settings->text("recordingFolder").toUtf8();
    struct Outcome {
        int result;
        int backend;
        QString path;
        QString error;
    };
    inBackground(this, [options, folder]() mutable {
        options.directory = folder.constData();
        std::array<char, 4096> path{};
        std::array<char, 1024> error{};
        int backend = 0;
        const int result = snipshot_record_start(&options, path.data(), path.size(), &backend, error.data(), error.size());
        return Outcome{result, backend, text(path.data()), text(error.data())};
    }, [this](Outcome outcome) {
        if (outcome.result != SNIPSHOT_OK) {
            setState("idle");
            setStatus(outcome.error);
            showPill(outcome.error.isEmpty() ? tr("Recording could not start") : outcome.error, "dismiss_regular", false, 6000);
            return;
        }
        m_resultPath.clear();
        m_pendingRecording = outcome.path;
        m_recorderName = outcome.backend == SNIPSHOT_BACKEND_GPU_SCREEN_RECORDER ? "gpu-screen-recorder" : "wf-recorder";
        emit recorderNameChanged();
        m_paused = false;
        emit pausedChanged();
        m_segmentClock.start();
        m_elapsedTicker.start();
        setState("recording");
        setStatus(tr("Recording"));
    });
}

void CaptureBackend::togglePause() {
    if (m_state != "recording" || m_recorderBusy) return;
    m_recorderBusy = true;
    const bool pause = !m_paused;
    inBackground(this, [pause] {
        std::array<char, 1024> error{};
        const int result = snipshot_record_pause(pause, error.data(), error.size());
        return std::make_pair(result, text(error.data()));
    }, [this, pause](std::pair<int, QString> outcome) {
        m_recorderBusy = false;
        if (outcome.first != SNIPSHOT_OK) {
            showPill(outcome.second, "dismiss_regular", false, 5000);
            return;
        }
        if (pause) m_elapsedBefore += m_segmentClock.elapsed();
        else m_segmentClock.restart();
        m_paused = pause;
        emit pausedChanged();
        emit elapsedChanged();
    });
}

void CaptureBackend::stopRecording() {
    if (m_state == "armed" || m_state == "countdown") {
        cancel();
        return;
    }
    if (m_state != "recording" || m_recorderBusy) return;
    m_recorderBusy = true;
    if (!m_paused) m_elapsedBefore += m_segmentClock.elapsed();
    m_paused = true;
    emit pausedChanged();
    m_elapsedTicker.stop();
    setState("finishing");
    QTimer::singleShot(400, this, [this] {
        if (m_state == "finishing") showPill(tr("Saving recording"), "video_regular", true, 0);
    });
    inBackground(this, [] {
        std::array<char, 1024> error{};
        const int result = snipshot_record_stop(error.data(), error.size());
        return std::make_pair(result, text(error.data()));
    }, [this](std::pair<int, QString> outcome) {
        m_recorderBusy = false;
        endRecording();
        if (outcome.first != SNIPSHOT_OK) {
            setStatus(outcome.second);
            showPill(outcome.second, "dismiss_regular", false, 6000);
            return;
        }
        setResult(m_pendingRecording, "video", m_recordRegion.size(), true);
        showPill(tr("Recording saved"), "checkmark_regular");
        setStatus(tr("Recording saved"));
        showSnip();
    });
}

void CaptureBackend::discardRecording() {
    if (m_state == "armed" || m_state == "countdown") {
        cancel();
        return;
    }
    if (m_state != "recording" || m_recorderBusy) return;
    m_recorderBusy = true;
    m_elapsedTicker.stop();
    setState("finishing");
    inBackground(this, [] { return snipshot_record_abort(); }, [this](int) {
        m_recorderBusy = false;
        endRecording();
        showPill(tr("Recording discarded"), "delete_regular");
    });
}

void CaptureBackend::endRecording() {
    m_elapsedTicker.stop();
    m_paused = false;
    emit pausedChanged();
    setState("idle");
}

void CaptureBackend::setResult(const QString &path, const QString &type, QSize size, bool saved) {
    closeNotification();
    m_resultPath = path;
    m_resultType = type;
    m_resultSize = size;
    m_resultSaved = saved;
    emit resultChanged();
}

void CaptureBackend::closeNotification() {
    if (m_notificationId == 0) return;
    QDBusMessage close = QDBusMessage::createMethodCall("org.freedesktop.Notifications", "/org/freedesktop/Notifications",
                                                        "org.freedesktop.Notifications", "CloseNotification");
    close << m_notificationId;
    QDBusConnection::sessionBus().asyncCall(close);
    m_notificationId = 0;
}

void CaptureBackend::sendResultNotification(const QString &title, const QString &body) {
    if (m_resultPath.isEmpty() || !m_settings->flag("notifications")) return;
    const bool image = m_resultType == "image";
    const QString path = m_resultPath;
    QDBusMessage notify = QDBusMessage::createMethodCall("org.freedesktop.Notifications", "/org/freedesktop/Notifications",
                                                         "org.freedesktop.Notifications", "Notify");
    QVariantMap hints;
    hints.insert("desktop-entry", QString::fromLatin1(SnipShotService));
    if (image) hints.insert("image-path", QFileInfo(path).absoluteFilePath());
    notify << QStringLiteral("SnipShot") << m_notificationId << (image ? path : QStringLiteral("video-x-generic")) << title << body
           << QStringList{"default", tr("Open"), "copy", tr("Copy"), "save", tr("Save as")} << hints << 8000;
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(notify), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, path] {
        QDBusPendingReply<uint> reply = *watcher;
        watcher->deleteLater();
        if (reply.isError()) return;
        if (m_resultPath == path) {
            m_notificationId = reply.value();
            return;
        }
        QDBusMessage close = QDBusMessage::createMethodCall("org.freedesktop.Notifications", "/org/freedesktop/Notifications",
                                                            "org.freedesktop.Notifications", "CloseNotification");
        close << reply.value();
        QDBusConnection::sessionBus().asyncCall(close);
    });
}

void CaptureBackend::notificationAction(uint notificationId, const QString &action) {
    if (notificationId == 0 || notificationId != m_notificationId) return;
    m_notificationId = 0;
    if (action == "default") showSnip();
    else if (action == "copy") copyResult();
    else if (action == "save") saveResult();
}

void CaptureBackend::copyResult() {
    if (m_resultPath.isEmpty()) return;
    if (m_resultType == "image") {
        const int copied = snipshot_copy_file(QFile::encodeName(m_resultPath).constData(), "image/png");
        if (copied == SNIPSHOT_UNSUPPORTED) QGuiApplication::clipboard()->setImage(QImage(m_resultPath));
        showPill(copied == SNIPSHOT_FAILED ? tr("Could not copy the snip") : tr("Snip copied to clipboard"),
                 copied == SNIPSHOT_FAILED ? "dismiss_regular" : "checkmark_regular");
        return;
    }
    auto *mimeData = new QMimeData;
    mimeData->setUrls({QUrl::fromLocalFile(m_resultPath)});
    QGuiApplication::clipboard()->setMimeData(mimeData);
    showPill(tr("Recording copied to clipboard"), "checkmark_regular");
}

void CaptureBackend::copyText() {
    if (m_recognizedText.isEmpty()) return;
    const int copied = snipshot_copy_text(m_recognizedText.toUtf8().constData());
    if (copied == SNIPSHOT_UNSUPPORTED) QGuiApplication::clipboard()->setText(m_recognizedText);
    showPill(tr("Text copied to clipboard"), "checkmark_regular");
}

QString CaptureBackend::folderFor(const QString &type) const {
    const QString configured = m_settings->text(type == "image" ? "screenshotFolder" : "recordingFolder");
    if (!configured.isEmpty()) return configured;
    return QStandardPaths::writableLocation(type == "image" ? QStandardPaths::PicturesLocation : QStandardPaths::MoviesLocation);
}

void CaptureBackend::saveResult() {
    if (m_resultPath.isEmpty() || m_savePending) return;
    m_saveSourcePath = m_resultPath;
    m_savePending = true;

    const QString token = QStringLiteral("snipshot_%1").arg(QUuid::createUuid().toString(QUuid::Id128));
    const QString sender = QDBusConnection::sessionBus().baseService().mid(1).replace('.', '_');
    m_saveRequestPath = QStringLiteral("/org/freedesktop/portal/desktop/request/%1/%2").arg(sender, token);
    QDBusConnection::sessionBus().connect("org.freedesktop.portal.Desktop", m_saveRequestPath, "org.freedesktop.portal.Request",
                                          "Response", this, SLOT(saveFileDialogResponse(uint,QVariantMap)));

    QString folder = folderFor(m_resultType);
    if (folder.isEmpty()) folder = QFileInfo(m_resultPath).absolutePath();
    QByteArray folderBytes = QFile::encodeName(folder);
    folderBytes.append('\0');
    QVariantMap options;
    options.insert("handle_token", token);
    options.insert("accept_label", tr("Save"));
    options.insert("modal", true);
    options.insert("current_name", QFileInfo(m_resultPath).fileName());
    options.insert("current_folder", folderBytes);

    QDBusMessage save = QDBusMessage::createMethodCall("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
                                                       "org.freedesktop.portal.FileChooser", "SaveFile");
    save << QString() << tr("Save as") << options;
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(save), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher] {
        QDBusPendingReply<QDBusObjectPath> reply = *watcher;
        watcher->deleteLater();
        if (reply.isError()) {
            QDBusConnection::sessionBus().disconnect("org.freedesktop.portal.Desktop", m_saveRequestPath, "org.freedesktop.portal.Request",
                                                     "Response", this, SLOT(saveFileDialogResponse(uint,QVariantMap)));
            m_savePending = false;
            m_saveRequestPath.clear();
            m_saveSourcePath.clear();
            showPill(tr("The desktop save dialog could not be opened"), "dismiss_regular", false, 5000);
            return;
        }
        if (!m_savePending) return;
        const QString actualPath = reply.value().path();
        if (actualPath == m_saveRequestPath) return;
        QDBusConnection::sessionBus().disconnect("org.freedesktop.portal.Desktop", m_saveRequestPath, "org.freedesktop.portal.Request",
                                                 "Response", this, SLOT(saveFileDialogResponse(uint,QVariantMap)));
        m_saveRequestPath = actualPath;
        QDBusConnection::sessionBus().connect("org.freedesktop.portal.Desktop", m_saveRequestPath, "org.freedesktop.portal.Request",
                                              "Response", this, SLOT(saveFileDialogResponse(uint,QVariantMap)));
    });
}

void CaptureBackend::saveFileDialogResponse(uint response, const QVariantMap &results) {
    QDBusConnection::sessionBus().disconnect("org.freedesktop.portal.Desktop", m_saveRequestPath, "org.freedesktop.portal.Request",
                                             "Response", this, SLOT(saveFileDialogResponse(uint,QVariantMap)));
    m_saveRequestPath.clear();
    m_savePending = false;
    const QUrl selected(results.value("uris").toStringList().value(0));
    if (response != 0 || !selected.isLocalFile()) {
        m_saveSourcePath.clear();
        if (response == 2) showPill(tr("The desktop save dialog failed"), "dismiss_regular", false, 5000);
        return;
    }
    saveResultToFile(selected.toLocalFile());
}

void CaptureBackend::saveResultToFile(const QString &targetPath) {
    const QString sourcePath = m_saveSourcePath;
    m_saveSourcePath.clear();
    if (sourcePath.isEmpty()) return;
    inBackground(this, [sourcePath, targetPath] {
        const QFileInfo sourceInfo(sourcePath);
        const QFileInfo targetInfo(targetPath);
        if (sourceInfo.absoluteFilePath() == targetInfo.absoluteFilePath() ||
            (!sourceInfo.canonicalFilePath().isEmpty() && sourceInfo.canonicalFilePath() == targetInfo.canonicalFilePath()))
            return true;
        QFile source(sourcePath);
        QSaveFile target(targetPath);
        if (!source.open(QIODevice::ReadOnly) || !target.open(QIODevice::WriteOnly)) return false;
        std::array<char, 65536> buffer{};
        while (true) {
            const qint64 count = source.read(buffer.data(), buffer.size());
            if (count == 0) break;
            if (count < 0 || target.write(buffer.data(), count) != count) {
                target.cancelWriting();
                return false;
            }
        }
        return target.commit();
    }, [this, targetPath](bool saved) {
        if (!saved) {
            showPill(tr("Could not save the capture there"), "dismiss_regular", false, 5000);
            return;
        }
        if (!m_resultSaved) {
            m_resultPath = targetPath;
            m_resultSaved = true;
            emit resultChanged();
        }
        showPill(tr("Saved to %1").arg(QFileInfo(targetPath).fileName()), "checkmark_regular");
    });
}

void CaptureBackend::openResultFolder() {
    if (m_resultPath.isEmpty()) return;
    QDBusMessage show = QDBusMessage::createMethodCall("org.freedesktop.FileManager1", "/org/freedesktop/FileManager1",
                                                       "org.freedesktop.FileManager1", "ShowItems");
    show << QStringList{QUrl::fromLocalFile(m_resultPath).toString()} << QString();
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(show), this);
    const QString folder = QFileInfo(m_resultPath).absolutePath();
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [watcher, folder] {
        if (watcher->isError()) QDesktopServices::openUrl(QUrl::fromLocalFile(folder));
        watcher->deleteLater();
    });
}

void CaptureBackend::openResultExternally() {
    if (!m_resultPath.isEmpty()) QDesktopServices::openUrl(QUrl::fromLocalFile(m_resultPath));
}

void CaptureBackend::showMain() { setWindows(m_mainOpen, true); }
void CaptureBackend::closeMain() { setWindows(m_mainOpen, false); }
void CaptureBackend::showSettings() {
    loadOcrLanguages();
    setWindows(m_settingsOpen, true);
}
void CaptureBackend::closeSettings() { setWindows(m_settingsOpen, false); }
void CaptureBackend::showSnip() {
    if (m_resultPath.isEmpty()) return;
    closeNotification();
    setWindows(m_snipOpen, true);
}
void CaptureBackend::closeSnip() {
    setWindows(m_snipOpen, false);
    if (!m_resultSaved && !m_resultPath.isEmpty() && QFileInfo(m_resultPath).absolutePath() == QDir(runtimeFolder()).absolutePath())
        QFile::remove(m_resultPath);
}
void CaptureBackend::closeText() { setWindows(m_textOpen, false); }

void CaptureBackend::floatWindow(const QString &title, int width, int height) const {
    const QByteArray name = title.toUtf8();
    // Windows can map after the first attempt (a video loading, a slow compositor), so try once more.
    for (int delay : {120, 600})
        QTimer::singleShot(delay, [name, width, height] {
            QThreadPool::globalInstance()->start([name, width, height] { snipshot_float_window(name.constData(), width, height); });
        });
}

void CaptureBackend::loadOcrLanguages() {
    inBackground(this, [] {
        std::array<char, 8192> output{};
        snipshot_ocr_languages(output.data(), output.size());
        return text(output.data()).split('\n', Qt::SkipEmptyParts);
    }, [this](QStringList languages) {
        if (languages == m_ocrLanguages) return;
        m_ocrLanguages = languages;
        emit ocrLanguagesChanged();
    });
}

void CaptureBackend::quit() {
    if (recordingState(m_state)) {
        showPill(tr("Stop the recording before quitting"), "record_filled");
        return;
    }
    QCoreApplication::quit();
}
