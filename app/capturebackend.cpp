#include "capturebackend.h"
#include "core.h"

#include <QGuiApplication>
#include <QClipboard>
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QMetaObject>
#include <QMimeData>
#include <QPointer>
#include <QRect>
#include <QSaveFile>
#include <QScreen>
#include <QStandardPaths>
#include <QThreadPool>
#include <QUuid>

#include <algorithm>
#include <array>

CaptureBackend::CaptureBackend(QObject *parent) : QObject(parent) {
    QDBusConnection::sessionBus().connect(
        "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
        "org.freedesktop.Notifications", "ActionInvoked", this,
        SLOT(notificationAction(uint,QString)));
}

CaptureBackend::~CaptureBackend() {
    if (m_recording) {
        std::array<char, 512> error{};
        snipshot_record_stop(error.data(), error.size());
    }
}

QString CaptureBackend::status() const { return m_status; }
QString CaptureBackend::savedPath() const { return m_savedPath; }
QString CaptureBackend::recognizedText() const { return m_recognizedText; }
QString CaptureBackend::resultPath() const { return m_resultPath; }
QUrl CaptureBackend::resultUrl() const { return QUrl::fromLocalFile(m_resultPath); }
QString CaptureBackend::resultType() const { return m_resultType; }
bool CaptureBackend::busy() const { return m_busy; }
bool CaptureBackend::previewOpen() const { return m_previewOpen; }
bool CaptureBackend::recording() const { return m_recording; }
bool CaptureBackend::paused() const { return m_paused; }
int CaptureBackend::recordingX() const { return m_recordingX; }
int CaptureBackend::recordingY() const { return m_recordingY; }
int CaptureBackend::recordingWidth() const { return m_recordingWidth; }
int CaptureBackend::recordingHeight() const { return m_recordingHeight; }

void CaptureBackend::setStatus(QString status) {
    if (m_status == status) return;
    m_status = std::move(status);
    emit statusChanged();
}

void CaptureBackend::setBusy(bool busy) {
    if (m_busy == busy) return;
    m_busy = busy;
    emit busyChanged();
}

void CaptureBackend::setRecording(bool recording) {
    if (m_recording == recording) return;
    m_recording = recording;
    emit recordingChanged();
}

void CaptureBackend::clearResult() {
    if (m_notificationId != 0) {
        QDBusMessage close = QDBusMessage::createMethodCall(
            "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
            "org.freedesktop.Notifications", "CloseNotification");
        close << m_notificationId;
        QDBusConnection::sessionBus().asyncCall(close);
        m_notificationId = 0;
    }
    m_resultPath.clear();
    m_resultType.clear();
    emit resultChanged();
    if (m_previewOpen) {
        m_previewOpen = false;
        emit previewOpenChanged();
    }
}

void CaptureBackend::setResult(QString path, QString type) {
    m_resultPath = std::move(path);
    m_resultType = std::move(type);
    emit resultChanged();
    sendResultNotification();
}

void CaptureBackend::captureImage() { capture(false); }
void CaptureBackend::extractText() { capture(true); }

void CaptureBackend::capture(bool extractText) {
    if (m_busy || m_recording) return;
    clearResult();
    setBusy(true);
    setStatus(extractText ? "Choose a region to read" : "Choose a region to capture");
    QPointer<CaptureBackend> self(this);
    QThreadPool::globalInstance()->start([self, extractText] {
        std::array<char, 4096> path{};
        std::array<char, 65536> text{};
        std::array<char, 512> error{};
        const int result = snipshot_capture(extractText, path.data(), path.size(),
                                            text.data(), text.size(), error.data(), error.size());
        if (!self) return;
        QMetaObject::invokeMethod(self, [self, result, path, text, error, extractText] {
            if (!self) return;
            self->setBusy(false);
            if (result == 1) {
                self->setStatus("Selection cancelled");
            } else if (result != 0) {
                if (path[0] != '\0') {
                    self->m_savedPath = QString::fromUtf8(path.data());
                    emit self->savedPathChanged();
                }
                self->setStatus(QString::fromUtf8(error.data()));
            } else {
                self->m_savedPath = QString::fromUtf8(path.data());
                emit self->savedPathChanged();
                if (extractText) {
                    self->m_recognizedText = QString::fromUtf8(text.data()).trimmed();
                    emit self->recognizedTextChanged();
                    self->setStatus(self->m_recognizedText.isEmpty()
                                        ? "No text found in that region"
                                        : "Text extracted from the selected region");
                } else {
                    self->setResult(self->m_savedPath, "image");
                    self->setStatus("Screenshot saved");
                }
            }
        }, Qt::QueuedConnection);
    });
}

void CaptureBackend::recordRegion() {
    if (m_busy || m_recording) return;
    clearResult();
    setBusy(true);
    setStatus("Choose a region to record");
    QPointer<CaptureBackend> self(this);
    QThreadPool::globalInstance()->start([self] {
        std::array<char, 4096> path{};
        SnipShotRegion region{};
        std::array<char, 512> error{};
        const int result = snipshot_record_start(path.data(), path.size(), &region, error.data(), error.size());
        if (!self) {
            if (result == 0) snipshot_record_stop(error.data(), error.size());
            return;
        }
        QMetaObject::invokeMethod(self, [self, result, path, error, region] {
            if (!self) return;
            self->setBusy(false);
            if (result == 1) {
                self->setStatus("Selection cancelled");
            } else if (result != 0) {
                self->setStatus(QString::fromUtf8(error.data()));
            } else {
                self->m_savedPath = QString::fromUtf8(path.data());
                emit self->savedPathChanged();
                const QRect selectedRegion(region.x, region.y, region.width, region.height);
                const auto screens = QGuiApplication::screens();
                const bool fitsScreen = std::any_of(screens.cbegin(), screens.cend(),
                                                    [&selectedRegion](QScreen *screen) {
                    const QRect geometry = screen->geometry();
                    return geometry.contains(selectedRegion.topLeft()) &&
                           geometry.contains(selectedRegion.bottomRight());
                });
                if (!fitsScreen) {
                    self->setBusy(true);
                    self->setStatus("Choose a recording region on one screen");
                    QPointer<CaptureBackend> backend(self);
                    QThreadPool::globalInstance()->start([backend] {
                        std::array<char, 512> stopError{};
                        snipshot_record_abort(stopError.data(), stopError.size());
                        if (!backend) return;
                        QMetaObject::invokeMethod(backend, [backend] {
                            if (backend) backend->setBusy(false);
                        }, Qt::QueuedConnection);
                    });
                    return;
                }
                self->m_recordingX = region.x;
                self->m_recordingY = region.y;
                self->m_recordingWidth = region.width;
                self->m_recordingHeight = region.height;
                emit self->recordingRegionChanged();
                self->m_paused = false;
                emit self->pausedChanged();
                self->setRecording(true);
                self->setStatus("Recording region");
            }
        }, Qt::QueuedConnection);
    });
}

void CaptureBackend::toggleRecordingPause() {
    if (!m_recording || m_busy) return;
    const bool pause = !m_paused;
    setBusy(true);
    setStatus(pause ? "Pausing recording" : "Resuming recording");
    QPointer<CaptureBackend> self(this);
    QThreadPool::globalInstance()->start([self, pause] {
        std::array<char, 512> error{};
        const int result = snipshot_record_pause(pause, error.data(), error.size());
        if (!self) return;
        QMetaObject::invokeMethod(self, [self, pause, result, error] {
            if (!self) return;
            self->setBusy(false);
            if (result == 0) {
                self->m_paused = pause;
                emit self->pausedChanged();
                self->setStatus(pause ? "Recording paused" : "Recording region");
            } else {
                self->setStatus(QString::fromUtf8(error.data()));
            }
        }, Qt::QueuedConnection);
    });
}

void CaptureBackend::stopRecording() {
    if (!m_recording || m_busy) return;
    setBusy(true);
    setStatus("Finishing recording");
    QPointer<CaptureBackend> self(this);
    QThreadPool::globalInstance()->start([self] {
        std::array<char, 512> error{};
        const int result = snipshot_record_stop(error.data(), error.size());
        if (!self) return;
        QMetaObject::invokeMethod(self, [self, result, error] {
            if (!self) return;
            self->setBusy(false);
            self->setRecording(false);
            self->m_paused = false;
            emit self->pausedChanged();
            self->setStatus(result == 0 ? "Recording saved" : QString::fromUtf8(error.data()));
            if (result == 0) self->setResult(self->m_savedPath, "video");
        }, Qt::QueuedConnection);
    });
}

void CaptureBackend::copyText() {
    if (m_recognizedText.isEmpty()) return;
    QGuiApplication::clipboard()->setText(m_recognizedText);
    setStatus("Text copied to clipboard");
}

void CaptureBackend::copyResult() {
    if (m_resultPath.isEmpty()) return;
    if (m_resultType == "image") {
        const QImage image(m_resultPath);
        if (image.isNull()) {
            setStatus("Could not read the captured image");
            return;
        }
        QGuiApplication::clipboard()->setImage(image);
    } else {
        auto *mimeData = new QMimeData;
        mimeData->setUrls({QUrl::fromLocalFile(m_resultPath)});
        QGuiApplication::clipboard()->setMimeData(mimeData);
    }
    setStatus(m_resultType == "image" ? "Image copied to clipboard" : "Recording copied to clipboard");
}

void CaptureBackend::sendResultNotification() {
    if (m_resultPath.isEmpty()) return;
    const bool image = m_resultType == "image";
    const QString path = m_resultPath;
    QDBusMessage notify = QDBusMessage::createMethodCall(
        "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
        "org.freedesktop.Notifications", "Notify");
    QVariantMap hints;
    if (image) hints.insert("image-path", QFileInfo(path).absoluteFilePath());
    notify << QStringLiteral("SnipShot") << m_notificationId
           << (image ? path : QStringLiteral("video-x-generic"))
           << (image ? QStringLiteral("Screenshot captured") : QStringLiteral("Recording saved"))
           << QStringLiteral("Click to open a preview")
           << QStringList{QStringLiteral("default"), QStringLiteral("Open preview"),
                          QStringLiteral("copy"), QStringLiteral("Copy to Clipboard"),
                          QStringLiteral("save"), QStringLiteral("Save to File")}
           << hints << 10000;
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(notify), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, path] {
        QDBusPendingReply<uint> reply = *watcher;
        watcher->deleteLater();
        if (reply.isError()) {
            if (m_resultPath == path) setStatus("Desktop notification could not be shown");
        } else if (m_resultPath == path) {
            m_notificationId = reply.value();
        } else {
            QDBusMessage close = QDBusMessage::createMethodCall(
                "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
                "org.freedesktop.Notifications", "CloseNotification");
            close << reply.value();
            QDBusConnection::sessionBus().asyncCall(close);
        }
    });
}

void CaptureBackend::notificationAction(uint notificationId, const QString &action) {
    if (notificationId != m_notificationId) return;
    m_notificationId = 0;
    if (action == "default") openPreview();
    else if (action == "copy") copyResult();
    else if (action == "save") saveResult();
}

void CaptureBackend::saveResult() {
    if (m_resultPath.isEmpty() || m_saveDialogPending || m_busy) return;
    m_saveDialogSourcePath = m_resultPath;
    m_saveDialogPending = true;
    setBusy(true);
    setStatus("Choose where to save the capture");

    const QString token = QStringLiteral("snipshot_%1").arg(QUuid::createUuid().toString(QUuid::Id128));
    const QString sender = QDBusConnection::sessionBus().baseService().mid(1).replace('.', '_');
    m_saveRequestPath = QStringLiteral("/org/freedesktop/portal/desktop/request/%1/%2").arg(sender, token);
    QDBusConnection::sessionBus().connect(
        "org.freedesktop.portal.Desktop", m_saveRequestPath,
        "org.freedesktop.portal.Request", "Response", this,
        SLOT(saveFileDialogResponse(uint,QVariantMap)));

    QString folder = QStandardPaths::writableLocation(
        m_resultType == "image" ? QStandardPaths::PicturesLocation : QStandardPaths::MoviesLocation);
    if (folder.isEmpty()) folder = QFileInfo(m_resultPath).absolutePath();
    QByteArray folderBytes = QFile::encodeName(folder);
    folderBytes.append('\0');
    QVariantMap options;
    options.insert("handle_token", token);
    options.insert("accept_label", QStringLiteral("Save"));
    options.insert("modal", true);
    options.insert("current_name", QFileInfo(m_resultPath).fileName());
    options.insert("current_folder", folderBytes);

    QDBusMessage save = QDBusMessage::createMethodCall(
        "org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
        "org.freedesktop.portal.FileChooser", "SaveFile");
    save << QString() << QStringLiteral("Save capture") << options;
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(save), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher] {
        QDBusPendingReply<QDBusObjectPath> reply = *watcher;
        watcher->deleteLater();
        if (reply.isError()) {
            QDBusConnection::sessionBus().disconnect(
                "org.freedesktop.portal.Desktop", m_saveRequestPath,
                "org.freedesktop.portal.Request", "Response", this,
                SLOT(saveFileDialogResponse(uint,QVariantMap)));
            m_saveDialogPending = false;
            m_saveRequestPath.clear();
            m_saveDialogSourcePath.clear();
            setBusy(false);
            setStatus("The desktop save dialog could not be opened");
            return;
        }
        if (!m_saveDialogPending) return;
        const QString actualPath = reply.value().path();
        if (actualPath != m_saveRequestPath) {
            QDBusConnection::sessionBus().disconnect(
                "org.freedesktop.portal.Desktop", m_saveRequestPath,
                "org.freedesktop.portal.Request", "Response", this,
                SLOT(saveFileDialogResponse(uint,QVariantMap)));
            m_saveRequestPath = actualPath;
            QDBusConnection::sessionBus().connect(
                "org.freedesktop.portal.Desktop", m_saveRequestPath,
                "org.freedesktop.portal.Request", "Response", this,
                SLOT(saveFileDialogResponse(uint,QVariantMap)));
        }
    });
}

void CaptureBackend::saveFileDialogResponse(uint response, const QVariantMap &results) {
    QDBusConnection::sessionBus().disconnect(
        "org.freedesktop.portal.Desktop", m_saveRequestPath,
        "org.freedesktop.portal.Request", "Response", this,
        SLOT(saveFileDialogResponse(uint,QVariantMap)));
    m_saveRequestPath.clear();
    m_saveDialogPending = false;
    if (response != 0) {
        m_saveDialogSourcePath.clear();
        setBusy(false);
        setStatus(response == 1 ? "Save cancelled" : "The desktop save dialog failed");
        return;
    }
    const QStringList uris = results.value("uris").toStringList();
    const QUrl selected(uris.value(0));
    const QString targetPath = selected.isLocalFile() ? selected.toLocalFile() : QString();
    if (targetPath.isEmpty()) {
        m_saveDialogSourcePath.clear();
        setBusy(false);
        setStatus("The save dialog did not return a local file");
        return;
    }
    saveResultToFile(targetPath);
}

void CaptureBackend::saveResultToFile(QString targetPath) {
    const QString sourcePath = m_saveDialogSourcePath;
    m_saveDialogSourcePath.clear();
    if (sourcePath.isEmpty() || targetPath.isEmpty()) {
        setBusy(false);
        setStatus("Could not save the capture there");
        return;
    }
    setStatus("Saving capture");
    setBusy(true);
    QPointer<CaptureBackend> self(this);
    QThreadPool::globalInstance()->start([self, sourcePath, targetPath] {
        QString status = "Could not save the capture there";
        const QFileInfo sourceInfo(sourcePath);
        const QFileInfo targetInfo(targetPath);
        const QString canonicalSource = sourceInfo.canonicalFilePath();
        const QString canonicalTarget = targetInfo.canonicalFilePath();
        if (sourceInfo.absoluteFilePath() == targetInfo.absoluteFilePath() ||
            (!canonicalSource.isEmpty() && canonicalSource == canonicalTarget)) {
            status = "That capture is already saved there";
        } else {
            QFile source(sourcePath);
            QSaveFile target(targetPath);
            if (source.open(QIODevice::ReadOnly) && target.open(QIODevice::WriteOnly)) {
                std::array<char, 65536> buffer{};
                bool copied = true;
                while (true) {
                    const qint64 count = source.read(buffer.data(), buffer.size());
                    if (count == 0) break;
                    if (count < 0 || target.write(buffer.data(), count) != count) {
                        copied = false;
                        break;
                    }
                }
                if (copied && target.commit()) {
                    status = "Saved capture to file";
                } else {
                    target.cancelWriting();
                }
            }
        }
        if (!self) return;
        QMetaObject::invokeMethod(self, [self, status] {
            if (!self) return;
            self->setBusy(false);
            self->setStatus(status);
        }, Qt::QueuedConnection);
    });
}

void CaptureBackend::openPreview() {
    if (m_resultPath.isEmpty() || m_previewOpen) return;
    m_previewOpen = true;
    emit previewOpenChanged();
}

void CaptureBackend::closePreview() {
    if (!m_previewOpen) return;
    m_previewOpen = false;
    emit previewOpenChanged();
    QCoreApplication::quit();
}
