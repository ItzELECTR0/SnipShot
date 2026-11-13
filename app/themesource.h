#pragma once

#include <QColor>
#include <QDBusVariant>
#include <QFileSystemWatcher>
#include <QObject>
#include <QQuickImageProvider>
#include <QSettings>
#include <QStringList>
#include <QVariantMap>

// Resolves the colours from the chosen theme, light or dark mode and accent, and owns those settings.
class ThemeSource final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap colors READ colors NOTIFY changed)
    Q_PROPERTY(bool dark READ dark NOTIFY changed)
    Q_PROPERTY(int radius READ radius NOTIFY changed)
    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY changed)
    Q_PROPERTY(QStringList themes READ themes NOTIFY themesChanged)
    Q_PROPERTY(QString themesFolder READ themesFolder CONSTANT)
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY changed)
    Q_PROPERTY(bool modeFixed READ modeFixed NOTIFY changed)
    Q_PROPERTY(QString accent READ accent WRITE setAccent NOTIFY changed)
    Q_PROPERTY(QColor customAccent READ customAccent WRITE setCustomAccent NOTIFY changed)
    Q_PROPERTY(QVariantList accents READ accents NOTIFY changed)

public:
    explicit ThemeSource(QString configFolder, QObject *parent = nullptr);

    QVariantMap colors() const { return m_colors; }
    bool dark() const { return m_dark; }
    int radius() const { return m_radius; }
    QString theme() const { return m_theme; }
    void setTheme(const QString &theme);
    QStringList themes() const { return m_themes; }
    QString themesFolder() const { return m_folder; }
    QString mode() const { return m_mode; }
    void setMode(const QString &mode);
    // A theme file with a "base" decides light or dark itself.
    bool modeFixed() const { return m_modeFixed; }
    QString accent() const { return m_accent; }
    void setAccent(const QString &accent);
    QColor customAccent() const { return m_customAccent; }
    void setCustomAccent(const QColor &color);
    // [{id, label, color}] for the current mode; "system" only when the portal publishes an accent.
    QVariantList accents() const;

    // The themes folder is only watched once it exists, so the settings window rescans when it opens.
    Q_INVOKABLE void rescan();
    Q_INVOKABLE void openThemesFolder() const;
    Q_INVOKABLE bool hasDesktopIcon(const QString &name) const;

signals:
    void changed();
    void themesChanged();

private slots:
    void portalSettingChanged(const QString &ns, const QString &key, const QDBusVariant &value);

private:
    void readPortal();
    void rebuild();
    QColor accentColor(const QString &id, bool dark, const QColor &themePrimary) const;
    QString themeFile(const QString &name) const;

    QSettings m_settings;
    QFileSystemWatcher m_watcher;
    QString m_folder;
    QString m_theme;
    QStringList m_themes;
    QString m_mode;
    QString m_accent;
    QColor m_customAccent;
    int m_portalScheme = 0;
    QColor m_portalAccent;
    QVariantMap m_colors;
    QColor m_themePrimary;
    bool m_dark = true;
    bool m_modeFixed = false;
    int m_radius = 10;
};

class DesktopIconProvider final : public QQuickImageProvider {
public:
    DesktopIconProvider();
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
};
