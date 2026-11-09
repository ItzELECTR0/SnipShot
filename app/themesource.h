#pragma once

#include <QObject>
#include <QQuickImageProvider>
#include <QStringList>
#include <QVariantMap>

class ThemeSource final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString themesFolder READ themesFolder CONSTANT)
    Q_PROPERTY(QStringList customThemes READ customThemes NOTIFY customThemesChanged)

public:
    explicit ThemeSource(QString configFolder, QObject *parent = nullptr);

    QString themesFolder() const;
    QStringList customThemes() const;

    Q_INVOKABLE QVariantMap loadTheme(const QString &name) const;
    Q_INVOKABLE bool hasDesktopIcon(const QString &name) const;
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void openThemesFolder() const;

signals:
    void customThemesChanged();

private:
    QString m_folder;
    QStringList m_themes;
};

class DesktopIconProvider final : public QQuickImageProvider {
public:
    DesktopIconProvider();
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
};
