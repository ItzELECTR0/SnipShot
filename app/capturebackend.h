#pragma once

#include <QElapsedTimer>
#include <QImage>
#include <QObject>
#include <QPointF>
#include <QRect>
#include <QRectF>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>

class OverlayController;
class Settings;

class CaptureBackend final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)
    Q_PROPERTY(QString purpose READ purpose WRITE setPurpose NOTIFY purposeChanged)
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY modeChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(int countdown READ countdown NOTIFY countdownChanged)
    Q_PROPERTY(int frozenSerial READ frozenSerial NOTIFY frozenSerialChanged)
    Q_PROPERTY(QRectF selection READ selection WRITE setSelection NOTIFY selectionChanged)
    Q_PROPERTY(QVariantList freeformPath READ freeformPath WRITE setFreeformPath NOTIFY freeformPathChanged)
    Q_PROPERTY(QVariantList windowRects READ windowRects NOTIFY windowRectsChanged)
    Q_PROPERTY(bool windowModeAvailable READ windowModeAvailable NOTIFY windowRectsChanged)
    Q_PROPERTY(QString activeScreen READ activeScreen WRITE setActiveScreen NOTIFY activeScreenChanged)
    Q_PROPERTY(QRect recordRegion READ recordRegion NOTIFY recordRegionChanged)
    Q_PROPERTY(bool paused READ paused NOTIFY pausedChanged)
    Q_PROPERTY(qint64 elapsed READ elapsed NOTIFY elapsedChanged)
    Q_PROPERTY(bool microphone READ microphone WRITE setMicrophone NOTIFY microphoneChanged)
    Q_PROPERTY(bool systemAudio READ systemAudio WRITE setSystemAudio NOTIFY systemAudioChanged)
    Q_PROPERTY(QString recorderName READ recorderName NOTIFY recorderNameChanged)
    Q_PROPERTY(QString resultPath READ resultPath NOTIFY resultChanged)
    Q_PROPERTY(QUrl resultUrl READ resultUrl NOTIFY resultChanged)
    Q_PROPERTY(QString resultType READ resultType NOTIFY resultChanged)
    Q_PROPERTY(QSize resultSize READ resultSize NOTIFY resultChanged)
    Q_PROPERTY(bool resultSaved READ resultSaved NOTIFY resultChanged)
    Q_PROPERTY(QString recognizedText READ recognizedText NOTIFY recognizedTextChanged)
    Q_PROPERTY(QString pillText READ pillText NOTIFY pillChanged)
    Q_PROPERTY(QString pillIcon READ pillIcon NOTIFY pillChanged)
    Q_PROPERTY(bool pillVisible READ pillVisible NOTIFY pillChanged)
    Q_PROPERTY(bool pillBusy READ pillBusy NOTIFY pillChanged)
    Q_PROPERTY(bool mainOpen READ mainOpen NOTIFY windowsChanged)
    Q_PROPERTY(bool settingsOpen READ settingsOpen NOTIFY windowsChanged)
    Q_PROPERTY(bool snipOpen READ snipOpen NOTIFY windowsChanged)
    Q_PROPERTY(bool textOpen READ textOpen NOTIFY windowsChanged)
    Q_PROPERTY(QStringList ocrLanguages READ ocrLanguages NOTIFY ocrLanguagesChanged)
    Q_PROPERTY(QVariantList recorderBackends READ recorderBackends CONSTANT)

public:
    CaptureBackend(Settings *settings, QObject *parent = nullptr);
    ~CaptureBackend() override;

    void setOverlays(OverlayController *overlays) { m_overlays = overlays; }
    void handleCommand(const QStringList &arguments);

    QString state() const { return m_state; }
    QString purpose() const { return m_purpose; }
    QString mode() const { return m_mode; }
    QString status() const { return m_status; }
    int countdown() const { return m_countdown; }
    int frozenSerial() const { return m_frozenSerial; }
    QRectF selection() const { return m_selection; }
    QVariantList freeformPath() const { return m_freeformPath; }
    QVariantList windowRects() const { return m_windowRects; }
    bool windowModeAvailable() const { return m_windowModeAvailable; }
    QString activeScreen() const { return m_activeScreen; }
    QRect recordRegion() const { return m_recordRegion; }
    bool paused() const { return m_paused; }
    qint64 elapsed() const;
    bool microphone() const;
    bool systemAudio() const;
    QString recorderName() const { return m_recorderName; }
    QString resultPath() const { return m_resultPath; }
    QUrl resultUrl() const;
    QString resultType() const { return m_resultType; }
    QSize resultSize() const { return m_resultSize; }
    bool resultSaved() const { return m_resultSaved; }
    QString recognizedText() const { return m_recognizedText; }
    QString pillText() const { return m_pillText; }
    QString pillIcon() const { return m_pillIcon; }
    bool pillVisible() const { return m_pillVisible; }
    bool pillBusy() const { return m_pillBusy; }
    bool mainOpen() const { return m_mainOpen; }
    bool settingsOpen() const { return m_settingsOpen; }
    bool snipOpen() const { return m_snipOpen; }
    bool textOpen() const { return m_textOpen; }
    QStringList ocrLanguages() const { return m_ocrLanguages; }
    QVariantList recorderBackends() const;

    void setPurpose(const QString &purpose);
    void setMode(const QString &mode);
    void setSelection(const QRectF &selection);
    void setFreeformPath(const QVariantList &path);
    void setActiveScreen(const QString &screen);
    void setMicrophone(bool enabled);
    void setSystemAudio(bool enabled);

    Q_INVOKABLE void start(const QString &purpose, int delaySeconds = -1);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void commit();
    Q_INVOKABLE void startRecording();
    Q_INVOKABLE void togglePause();
    Q_INVOKABLE void stopRecording();
    Q_INVOKABLE void discardRecording();
    Q_INVOKABLE void copyResult();
    Q_INVOKABLE void saveResult();
    Q_INVOKABLE void openResultFolder();
    Q_INVOKABLE void openResultExternally();
    Q_INVOKABLE void copyText();
    Q_INVOKABLE void showMain();
    Q_INVOKABLE void closeMain();
    Q_INVOKABLE void showSettings();
    Q_INVOKABLE void closeSettings();
    Q_INVOKABLE void showSnip();
    Q_INVOKABLE void closeSnip();
    Q_INVOKABLE void closeText();
    Q_INVOKABLE void showPill(const QString &text, const QString &icon = QString(), bool busy = false, int timeoutMs = 2500);
    Q_INVOKABLE void restart();
    Q_INVOKABLE void quit();
    Q_INVOKABLE QString screenNameAt(const QPointF &globalPoint) const;
    Q_INVOKABLE void floatWindow(const QString &title, int width, int height) const;

signals:
    void stateChanged();
    void purposeChanged();
    void modeChanged();
    void statusChanged();
    void countdownChanged();
    void frozenSerialChanged();
    void selectionChanged();
    void freeformPathChanged();
    void windowRectsChanged();
    void activeScreenChanged();
    void recordRegionChanged();
    void pausedChanged();
    void elapsedChanged();
    void microphoneChanged();
    void systemAudioChanged();
    void recorderNameChanged();
    void resultChanged();
    void recognizedTextChanged();
    void pillChanged();
    void windowsChanged();
    void ocrLanguagesChanged();

private slots:
    void notificationAction(uint notificationId, const QString &action);
    void saveFileDialogResponse(uint response, const QVariantMap &results);

private:
    void setState(const QString &state);
    void setStatus(const QString &status);
    void setCountdown(int value);
    void setWindows(bool &flag, bool value);
    void hidePill();
    void freeze();
    void finishFreeze(QHash<QString, QImage> images, QVariantList windows, bool windowsSupported, QString focused, QString error);
    QImage compose(const QRectF &rect, const QVariantList &path) const;
    void finishSnip(QImage image, bool extractText);
    void beginRecorder();
    void endRecording();
    void resetSelection();
    void setResult(const QString &path, const QString &type, QSize size, bool saved);
    void sendResultNotification(const QString &title, const QString &body);
    void closeNotification();
    void saveResultToFile(const QString &targetPath);
    void loadOcrLanguages();
    QString folderFor(const QString &type) const;

    Settings *m_settings;
    OverlayController *m_overlays{nullptr};
    QString m_state{"idle"};
    QString m_purpose{"snip"};
    QString m_mode;
    QString m_status;
    int m_countdown{0};
    int m_frozenSerial{0};
    QRectF m_selection;
    QVariantList m_freeformPath;
    QVariantList m_windowRects;
    bool m_windowModeAvailable{false};
    QString m_activeScreen;
    QRect m_recordRegion;
    bool m_paused{false};
    qint64 m_elapsedBefore{0};
    QElapsedTimer m_segmentClock;
    QTimer m_elapsedTicker;
    QTimer m_countdownTimer;
    QTimer m_pillTimer;
    QString m_recorderName;
    QString m_pendingRecording;
    bool m_recorderBusy{false};
    QString m_resultPath;
    QString m_resultType;
    QSize m_resultSize;
    bool m_resultSaved{false};
    QString m_recognizedText;
    QString m_pillText;
    QString m_pillIcon;
    bool m_pillVisible{false};
    bool m_pillBusy{false};
    bool m_mainOpen{false};
    bool m_settingsOpen{false};
    bool m_snipOpen{false};
    bool m_textOpen{false};
    bool m_openSnipAfterCapture{false};
    QString m_fullscreen;
    QStringList m_ocrLanguages;
    uint m_notificationId{0};
    QString m_saveSourcePath;
    QString m_saveRequestPath;
    bool m_savePending{false};
};
