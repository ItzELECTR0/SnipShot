#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QUrl>

class CaptureBackend final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString savedPath READ savedPath NOTIFY savedPathChanged)
    Q_PROPERTY(QString recognizedText READ recognizedText NOTIFY recognizedTextChanged)
    Q_PROPERTY(QString resultPath READ resultPath NOTIFY resultChanged)
    Q_PROPERTY(QUrl resultUrl READ resultUrl NOTIFY resultChanged)
    Q_PROPERTY(QString resultType READ resultType NOTIFY resultChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(bool previewOpen READ previewOpen NOTIFY previewOpenChanged)
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(bool paused READ paused NOTIFY pausedChanged)
    Q_PROPERTY(int recordingX READ recordingX NOTIFY recordingRegionChanged)
    Q_PROPERTY(int recordingY READ recordingY NOTIFY recordingRegionChanged)
    Q_PROPERTY(int recordingWidth READ recordingWidth NOTIFY recordingRegionChanged)
    Q_PROPERTY(int recordingHeight READ recordingHeight NOTIFY recordingRegionChanged)

public:
    explicit CaptureBackend(QObject *parent = nullptr);
    ~CaptureBackend() override;

    QString status() const;
    QString savedPath() const;
    QString recognizedText() const;
    QString resultPath() const;
    QUrl resultUrl() const;
    QString resultType() const;
    bool busy() const;
    bool previewOpen() const;
    bool recording() const;
    bool paused() const;
    int recordingX() const;
    int recordingY() const;
    int recordingWidth() const;
    int recordingHeight() const;

    Q_INVOKABLE void captureImage();
    Q_INVOKABLE void extractText();
    Q_INVOKABLE void recordRegion();
    Q_INVOKABLE void stopRecording();
    Q_INVOKABLE void toggleRecordingPause();
    Q_INVOKABLE void copyText();
    Q_INVOKABLE void copyResult();
    Q_INVOKABLE void saveResult();
    Q_INVOKABLE void openPreview();
    Q_INVOKABLE void closePreview();

signals:
    void statusChanged();
    void savedPathChanged();
    void recognizedTextChanged();
    void resultChanged();
    void previewOpenChanged();
    void busyChanged();
    void recordingChanged();
    void pausedChanged();
    void recordingRegionChanged();

private:
    void setStatus(QString status);
    void setBusy(bool busy);
    void setRecording(bool recording);
    void capture(bool extractText);
    void clearResult();
    void setResult(QString path, QString type);
    void sendResultNotification();
    void saveResultToFile(QString path);

private slots:
    void notificationAction(uint notificationId, const QString &action);
    void saveFileDialogResponse(uint response, const QVariantMap &results);

private:
    QString m_status{"Ready when you are"};
    QString m_savedPath;
    QString m_recognizedText;
    QString m_resultPath;
    QString m_resultType;
    bool m_busy{false};
    bool m_previewOpen{false};
    uint m_notificationId{0};
    QString m_saveDialogSourcePath;
    QString m_saveRequestPath;
    bool m_saveDialogPending{false};
    bool m_recording{false};
    bool m_paused{false};
    int m_recordingX{0};
    int m_recordingY{0};
    int m_recordingWidth{0};
    int m_recordingHeight{0};
};
