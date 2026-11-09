#include "themesource.h"

#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QIcon>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>

ThemeSource::ThemeSource(QString configFolder, QObject *parent)
    : QObject(parent), m_folder(QDir(configFolder).filePath("themes")) {
    refresh();
}

QString ThemeSource::themesFolder() const { return m_folder; }
QStringList ThemeSource::customThemes() const { return m_themes; }

void ThemeSource::refresh() {
    QStringList themes;
    for (const QFileInfo &file : QDir(m_folder).entryInfoList({"*.json"}, QDir::Files, QDir::Name))
        themes << file.completeBaseName();
    if (themes == m_themes) return;
    m_themes = themes;
    emit customThemesChanged();
}

QVariantMap ThemeSource::loadTheme(const QString &name) const {
    if (name.isEmpty() || name.contains('/')) return {};
    QFile file(QDir(m_folder).filePath(name + ".json"));
    if (!file.open(QIODevice::ReadOnly)) return {};
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
    return document.isObject() ? document.object().toVariantMap() : QVariantMap{};
}

bool ThemeSource::hasDesktopIcon(const QString &name) const { return QIcon::hasThemeIcon(name); }

void ThemeSource::openThemesFolder() const {
    QDir().mkpath(m_folder);
    QDesktopServices::openUrl(QUrl::fromLocalFile(m_folder));
}

DesktopIconProvider::DesktopIconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

QPixmap DesktopIconProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) {
    const QSize target = requestedSize.isValid() ? requestedSize : QSize(24, 24);
    const QPixmap pixmap = QIcon::fromTheme(id).pixmap(target);
    if (size) *size = pixmap.size();
    return pixmap;
}
