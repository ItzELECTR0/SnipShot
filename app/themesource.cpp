#include "themesource.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QIcon>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>

namespace {
const char *PortalService = "org.freedesktop.portal.Desktop";
const char *PortalPath = "/org/freedesktop/portal/desktop";
const char *PortalSettings = "org.freedesktop.portal.Settings";
const QString Material = QStringLiteral("material");

struct Accent {
    const char *id;
    const char *label;
    const char *dark;
    const char *light;
};

// "default" and "system" resolve at runtime; "custom" uses the stored colour.
const Accent Accents[] = {
    {"default", QT_TRANSLATE_NOOP("ThemeSource", "Default"), nullptr, nullptr},
    {"system", QT_TRANSLATE_NOOP("ThemeSource", "System"), nullptr, nullptr},
    {"orange", QT_TRANSLATE_NOOP("ThemeSource", "Orange"), "#ff9433", "#c8650a"},
    {"red", QT_TRANSLATE_NOOP("ThemeSource", "Red"), "#ff6b6b", "#c62828"},
    {"pink", QT_TRANSLATE_NOOP("ThemeSource", "Pink"), "#f48fb1", "#c2185b"},
    {"purple", QT_TRANSLATE_NOOP("ThemeSource", "Purple"), "#b39ddb", "#6a3fb5"},
    {"blue", QT_TRANSLATE_NOOP("ThemeSource", "Blue"), "#64b5f6", "#1565c0"},
    {"teal", QT_TRANSLATE_NOOP("ThemeSource", "Teal"), "#4dd0c4", "#00796b"},
    {"green", QT_TRANSLATE_NOOP("ThemeSource", "Green"), "#81c784", "#2e7d32"},
    {"yellow", QT_TRANSLATE_NOOP("ThemeSource", "Yellow"), "#ffd54f", "#a37800"},
    {"custom", QT_TRANSLATE_NOOP("ThemeSource", "Custom"), nullptr, nullptr},
};

QColor mix(const QColor &a, const QColor &b, double t) {
    return QColor::fromRgbF(a.redF() + (b.redF() - a.redF()) * t, a.greenF() + (b.greenF() - a.greenF()) * t,
                            a.blueF() + (b.blueF() - a.blueF()) * t);
}

QColor contrastOn(const QColor &c) {
    const double luminance = 0.2126 * c.redF() + 0.7152 * c.greenF() + 0.0722 * c.blueF();
    return luminance > 0.55 ? QColor("#121212") : QColor("#ffffff");
}

// Prismora's Material: every ground and line is a mix of the surface and the text colour.
QVariantMap material(const QColor &surface, const QColor &text, const QColor &primary, const QColor &error) {
    return {{"surface", surface.name()},
            {"surface_container_low", mix(surface, text, 0.04).name()},
            {"surface_container", mix(surface, text, 0.07).name()},
            {"surface_container_high", mix(surface, text, 0.10).name()},
            {"surface_container_highest", mix(surface, text, 0.15).name()},
            {"on_surface", text.name()},
            {"on_surface_variant", mix(text, surface, 0.38).name()},
            {"outline", mix(surface, text, 0.32).name()},
            {"outline_variant", mix(surface, text, 0.17).name()},
            {"primary", primary.name()},
            {"on_primary", contrastOn(primary).name()},
            {"error", error.name()},
            {"shadow", "#000000"}};
}

QVariantMap materialFor(bool dark) {
    return dark ? material(QColor("#121212"), QColor("#e6e6e6"), Qt::white, QColor("#ff6b6b"))
                : material(QColor("#f4f4f4"), QColor("#161616"), Qt::black, QColor("#c62828"));
}

QVariant unwrap(QVariant v) {
    while (v.metaType() == QMetaType::fromType<QDBusVariant>()) v = v.value<QDBusVariant>().variant();
    return v;
}

QColor portalAccentFrom(const QVariant &value) {
    const QVariant v = unwrap(value);
    if (v.metaType() != QMetaType::fromType<QDBusArgument>()) return {};
    const QDBusArgument arg = v.value<QDBusArgument>();
    double r = -1, g = -1, b = -1;
    arg.beginStructure();
    arg >> r >> g >> b;
    arg.endStructure();
    const auto unit = [](double c) { return c >= 0.0 && c <= 1.0; };
    return unit(r) && unit(g) && unit(b) ? QColor::fromRgbF(r, g, b) : QColor();
}

void applyColors(QVariantMap &colors, const QJsonObject &overrides) {
    for (auto it = overrides.begin(); it != overrides.end(); ++it)
        if (colors.contains(it.key()) && QColor::isValidColorName(it.value().toString()))
            colors[it.key()] = it.value().toString();
}
}

ThemeSource::ThemeSource(QString configFolder, QObject *parent)
    : QObject(parent), m_folder(QDir(configFolder).filePath("themes")) {
    m_theme = m_settings.value("theme", Material).toString();
    m_mode = m_settings.value("mode", "system").toString();
    m_accent = m_settings.value("accent", "default").toString();
    m_customAccent = QColor(m_settings.value("customAccent", "#8ecfd4").toString());

    QDBusConnection::sessionBus().connect(PortalService, PortalPath, PortalSettings, "SettingChanged", this,
                                          SLOT(portalSettingChanged(QString,QString,QDBusVariant)));
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &ThemeSource::rebuild);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
        rescan();
        rebuild();
    });
    readPortal();
    rescan();
    rebuild();
}

QString ThemeSource::themeFile(const QString &name) const { return QDir(m_folder).filePath(name + ".json"); }

void ThemeSource::rescan() {
    if (QFileInfo::exists(m_folder) && !m_watcher.directories().contains(m_folder)) m_watcher.addPath(m_folder);
    QStringList themes{Material};
    for (const QFileInfo &file : QDir(m_folder).entryInfoList({"*.json"}, QDir::Files, QDir::Name))
        themes.append(file.completeBaseName());
    if (themes == m_themes) return;
    m_themes = themes;
    emit themesChanged();
}

void ThemeSource::openThemesFolder() const {
    QDir().mkpath(m_folder);
    QDesktopServices::openUrl(QUrl::fromLocalFile(m_folder));
}

bool ThemeSource::hasDesktopIcon(const QString &name) const { return QIcon::hasThemeIcon(name); }

void ThemeSource::setTheme(const QString &theme) {
    if (theme == m_theme) return;
    m_theme = theme;
    m_settings.setValue("theme", theme);
    rebuild();
}

void ThemeSource::setMode(const QString &mode) {
    if (mode == m_mode) return;
    m_mode = mode;
    m_settings.setValue("mode", mode);
    rebuild();
}

void ThemeSource::setAccent(const QString &accent) {
    if (accent == m_accent) return;
    m_accent = accent;
    m_settings.setValue("accent", accent);
    rebuild();
}

void ThemeSource::setCustomAccent(const QColor &color) {
    if (!color.isValid() || color == m_customAccent) return;
    m_customAccent = color;
    m_settings.setValue("customAccent", color.name());
    rebuild();
}

QColor ThemeSource::accentColor(const QString &id, bool dark, const QColor &themePrimary) const {
    if (id == "system" && m_portalAccent.isValid()) return m_portalAccent;
    if (id == "custom" && m_customAccent.isValid()) return m_customAccent;
    for (const Accent &accent : Accents)
        if (id == accent.id && accent.dark) return QColor(dark ? accent.dark : accent.light);
    return themePrimary;
}

QVariantList ThemeSource::accents() const {
    QVariantList out;
    for (const Accent &accent : Accents) {
        const QString id = QString::fromLatin1(accent.id);
        if (id == "system" && !m_portalAccent.isValid()) continue;
        const QColor color = accentColor(id, m_dark, m_themePrimary);
        out.append(QVariantMap{{"id", id}, {"label", tr(accent.label)}, {"color", color.name()}});
    }
    return out;
}

void ThemeSource::readPortal() {
    auto read = [](const char *key) {
        QDBusMessage call = QDBusMessage::createMethodCall(PortalService, PortalPath, PortalSettings, "ReadOne");
        call << QStringLiteral("org.freedesktop.appearance") << QString::fromLatin1(key);
        const QDBusMessage reply = QDBusConnection::sessionBus().call(call, QDBus::Block, 500);
        return reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty() ? reply.arguments().first()
                                                                                         : QVariant();
    };
    m_portalScheme = unwrap(read("color-scheme")).toInt();
    m_portalAccent = portalAccentFrom(read("accent-color"));
}

void ThemeSource::portalSettingChanged(const QString &ns, const QString &key, const QDBusVariant &value) {
    if (ns != "org.freedesktop.appearance") return;
    if (key == "color-scheme") m_portalScheme = unwrap(value.variant()).toInt();
    else if (key == "accent-color") m_portalAccent = portalAccentFrom(value.variant());
    else return;
    rebuild();
}

void ThemeSource::rebuild() {
    // Portal color-scheme: 1 prefers dark, 2 prefers light, 0 has no preference (we default to dark).
    bool dark = m_mode == "dark" || (m_mode != "light" && m_portalScheme != 2);
    bool fixed = false;
    int radius = 10;
    QVariantMap colors;

    if (m_theme != Material) {
        QFile file(themeFile(m_theme));
        QJsonObject json;
        if (!m_watcher.files().contains(file.fileName()) && file.exists()) m_watcher.addPath(file.fileName());
        if (file.open(QIODevice::ReadOnly)) json = QJsonDocument::fromJson(file.readAll()).object();
        else qWarning("snipshot: theme %s not found, using Material", qPrintable(file.fileName()));
        if (json.contains("base")) {
            dark = json.value("base").toString() != "light";
            fixed = true;
        }
        QJsonObject overrides = json.value("colors").toObject();
        const QJsonObject perMode = json.value(dark ? "dark" : "light").toObject();
        for (auto it = perMode.begin(); it != perMode.end(); ++it) overrides.insert(it.key(), it.value());
        // A file that only sets surface and text still gets matching containers and lines.
        const QVariantMap base = materialFor(dark);
        const auto pick = [&](const char *key) {
            const QString v = overrides.value(key).toString();
            return QColor::isValidColorName(v) ? QColor(v) : QColor(base.value(key).toString());
        };
        colors = material(pick("surface"), pick("on_surface"), pick("primary"), pick("error"));
        applyColors(colors, overrides);
        radius = json.value("radius").toInt(radius);
    } else {
        colors = materialFor(dark);
    }

    m_themePrimary = QColor(colors.value("primary").toString());
    if (m_accent != "default") {
        const QColor accent = accentColor(m_accent, dark, m_themePrimary);
        colors["primary"] = accent.name();
        colors["on_primary"] = contrastOn(accent).name();
    }

    m_colors = colors;
    m_dark = dark;
    m_modeFixed = fixed;
    m_radius = radius;
    emit changed();
}

DesktopIconProvider::DesktopIconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

QPixmap DesktopIconProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) {
    const QSize target = requestedSize.isValid() ? requestedSize : QSize(24, 24);
    const QPixmap pixmap = QIcon::fromTheme(id).pixmap(target);
    if (size) *size = pixmap.size();
    return pixmap;
}
