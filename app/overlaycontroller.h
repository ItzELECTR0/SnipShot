#pragma once

#include <QHash>
#include <QImage>
#include <QMutex>
#include <QObject>
#include <QPointer>
#include <QQuickImageProvider>
#include <QRect>

class QQmlEngine;
class QQuickWindow;
class QScreen;

class FrozenImageProvider final : public QQuickImageProvider {
public:
    FrozenImageProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
    void setImages(QHash<QString, QImage> images);
    QImage image(const QString &screenName) const;

private:
    mutable QMutex m_mutex;
    QHash<QString, QImage> m_images;
};

class OverlayController final : public QObject {
    Q_OBJECT

public:
    OverlayController(QQmlEngine *engine, FrozenImageProvider *images, QObject *parent = nullptr);

    void attach(QObject *root);
    void showOverlays();
    void hideOverlays();
    void placeRecording(const QRect &region);
    void raiseRecordBar();
    FrozenImageProvider *images() const { return m_images; }
    static QScreen *screenFor(const QRect &region);

private:
    QQuickWindow *overlayFor(QScreen *screen);
    void configureTopCenter(QQuickWindow *window, int topMargin, bool keyboard);
    void placeAt(QQuickWindow *window, QScreen *screen, const QPoint &globalTopLeft);

    QQmlEngine *m_engine;
    FrozenImageProvider *m_images;
    QHash<QScreen *, QPointer<QQuickWindow>> m_overlays;
    QPointer<QQuickWindow> m_recordBar;
    QPointer<QQuickWindow> m_recordFrame;
    QPointer<QQuickWindow> m_statusPill;
    QPointer<QQuickWindow> m_textFlyout;
    QRect m_recordRegion;
};
