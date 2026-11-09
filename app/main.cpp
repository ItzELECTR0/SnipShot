#include "capturebackend.h"
#include "instance.h"
#include "overlaycontroller.h"
#include "settings.h"
#include "themesource.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusVariant>
#include <QFile>
#include <QFileInfo>
#include <QLibraryInfo>
#include <QSettings>
#include <QGuiApplication>
#include <QPalette>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QStyleHints>

#include <cstdio>

InstanceService::InstanceService(CaptureBackend *backend, QObject *parent) : QObject(parent), m_backend(backend) {}

void InstanceService::Activate(const QStringList &arguments) { m_backend->handleCommand(arguments); }

static const char usage[] =
    "Usage: snipshot [command] [--delay SECONDS] [--mode rectangle|window|fullscreen|freeform]\n"
    "\n"
    "Commands:\n"
    "  open        Show the SnipShot window (default)\n"
    "  snip        Take a snip\n"
    "  text        Extract text from an area of the screen\n"
    "  record      Record an area of the screen, or stop the running recording\n"
    "  pause       Pause or resume the running recording\n"
    "  stop        Stop the running recording\n"
    "  settings    Open settings\n"
    "  quit        Quit the running instance\n"
    "\n"
    "  --daemon    Start without opening a window\n"
    "  --version   Print the version\n";

static QPalette platformPalette;
static bool paletteOverridden = false;

static QPalette fluentPalette(bool dark) {
    QPalette palette;
    const auto set = [&palette](QPalette::ColorRole role, const char *active, const char *disabled = nullptr) {
        palette.setColor(QPalette::All, role, QColor(active));
        if (disabled) palette.setColor(QPalette::Disabled, role, QColor(disabled));
    };
    if (dark) {
        set(QPalette::Window, "#202020");
        set(QPalette::WindowText, "#ffffff", "#717171");
        set(QPalette::Base, "#2d2d2d");
        set(QPalette::AlternateBase, "#2c2c2c");
        set(QPalette::Text, "#ffffff", "#717171");
        set(QPalette::Button, "#2d2d2d");
        set(QPalette::ButtonText, "#ffffff", "#717171");
        set(QPalette::PlaceholderText, "#c5c5c5");
        set(QPalette::Highlight, "#60cdff");
        set(QPalette::HighlightedText, "#000000");
        set(QPalette::Accent, "#60cdff");
        set(QPalette::Link, "#60cdff");
        set(QPalette::ToolTipBase, "#2c2c2c");
        set(QPalette::ToolTipText, "#ffffff");
        set(QPalette::Light, "#3c3c3c");
        set(QPalette::Midlight, "#333333");
        set(QPalette::Mid, "#1d1d1d");
        set(QPalette::Dark, "#141414");
    } else {
        set(QPalette::Window, "#f3f3f3");
        set(QPalette::WindowText, "#1b1b1b", "#a3a3a3");
        set(QPalette::Base, "#ffffff");
        set(QPalette::AlternateBase, "#f9f9f9");
        set(QPalette::Text, "#1b1b1b", "#a3a3a3");
        set(QPalette::Button, "#fbfbfb");
        set(QPalette::ButtonText, "#1b1b1b", "#a3a3a3");
        set(QPalette::PlaceholderText, "#616161");
        set(QPalette::Highlight, "#005fb8");
        set(QPalette::HighlightedText, "#ffffff");
        set(QPalette::Accent, "#005fb8");
        set(QPalette::Link, "#005fb8");
        set(QPalette::ToolTipBase, "#f9f9f9");
        set(QPalette::ToolTipText, "#1b1b1b");
        set(QPalette::Light, "#ffffff");
        set(QPalette::Midlight, "#e5e5e5");
        set(QPalette::Mid, "#c4c4c4");
        set(QPalette::Dark, "#a0a0a0");
    }
    set(QPalette::Shadow, "#000000");
    return palette;
}

static bool systemPrefersDark() {
    QDBusMessage read = QDBusMessage::createMethodCall("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
                                                       "org.freedesktop.portal.Settings", "ReadOne");
    read << QStringLiteral("org.freedesktop.appearance") << QStringLiteral("color-scheme");
    const QDBusMessage reply = QDBusConnection::sessionBus().call(read, QDBus::Block, 500);
    if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
        const uint preference = qvariant_cast<QDBusVariant>(reply.arguments().constFirst()).variant().toUInt();
        if (preference != 0) return preference == 1;
    }
    auto *hints = QGuiApplication::styleHints();
    hints->unsetColorScheme();
    const Qt::ColorScheme scheme = hints->colorScheme();
    if (scheme != Qt::ColorScheme::Unknown) return scheme == Qt::ColorScheme::Dark;
    return platformPalette.color(QPalette::Window).lightness() < 128;
}

static bool usesDesktopStyle(const Settings &settings, const ThemeSource &themes) {
    const QString source = settings.text("themeSource");
    return source == "desktop" ||
           (source == "custom" && themes.loadTheme(settings.text("customTheme")).value("base") == "desktop");
}

// Fluent mode replaces the platform palette (qt6ct, KDE...) so FluentWinUI3 controls keep Fluent colours.
static void applyAppearance(const Settings &settings, const ThemeSource &themes) {
    if (usesDesktopStyle(settings, themes)) {
        if (!paletteOverridden) return;
        QGuiApplication::styleHints()->unsetColorScheme();
        QGuiApplication::setPalette(platformPalette);
        paletteOverridden = false;
        return;
    }
    const QString scheme = settings.text("colorScheme");
    const bool dark = scheme == "dark" || (scheme != "light" && systemPrefersDark());
    QGuiApplication::styleHints()->setColorScheme(dark ? Qt::ColorScheme::Dark : Qt::ColorScheme::Light);
    QGuiApplication::setPalette(fluentPalette(dark));
    paletteOverridden = true;
}

AppearanceWatcher::AppearanceWatcher(std::function<void()> changed) : m_changed(std::move(changed)) {
    QDBusConnection::sessionBus().connect("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
                                          "org.freedesktop.portal.Settings", "SettingChanged", this,
                                          SLOT(settingChanged(QString,QString,QDBusVariant)));
}

void AppearanceWatcher::settingChanged(const QString &group, const QString &key, const QDBusVariant &) {
    if (group == "org.freedesktop.appearance" && key == "color-scheme") m_changed();
}

static bool storedThemeIsDesktop() {
    QSettings store;
    const QString source = store.value("themeSource", "fluent").toString();
    if (source != "custom") return source == "desktop";
    const ThemeSource themes(QFileInfo(store.fileName()).absolutePath());
    return themes.loadTheme(store.value("customTheme").toString()).value("base") == "desktop";
}

// FluentWinUI3 reads light or dark from the colour scheme, which qt6ct leaves unknown and cannot override.
static void chooseFluentPlatformTheme() {
    const QString themes = QLibraryInfo::path(QLibraryInfo::PluginsPath) + "/platformthemes/";
    qputenv("QT_QPA_PLATFORMTHEME", QFile::exists(themes + "libqgtk3.so") ? "gtk3" : "xdgdesktopportal");
}

int main(int argc, char *argv[]) {
    QCoreApplication::setApplicationName("SnipShot");
    QCoreApplication::setOrganizationName("SnipShot");
    QCoreApplication::setApplicationVersion(SNIPSHOT_VERSION);
    if (qEnvironmentVariableIsSet("SNIPSHOT_USER_PLATFORMTHEME"))
        qputenv("QT_QPA_PLATFORMTHEME", qgetenv("SNIPSHOT_USER_PLATFORMTHEME"));
    else
        qputenv("SNIPSHOT_USER_PLATFORMTHEME", qgetenv("QT_QPA_PLATFORMTHEME"));
    const bool desktopStyle = storedThemeIsDesktop();
    if (!desktopStyle) chooseFluentPlatformTheme();
    QGuiApplication::setDesktopFileName(SnipShotService);
    QGuiApplication app(argc, argv);
    QGuiApplication::setQuitOnLastWindowClosed(false);

    const QStringList arguments = app.arguments().mid(1);
    if (arguments.contains("--help") || arguments.contains("-h")) {
        std::fputs(usage, stdout);
        return 0;
    }
    if (arguments.contains("--version")) {
        std::puts("snipshot " SNIPSHOT_VERSION);
        return 0;
    }

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (bus.isConnected() && !bus.registerService(SnipShotService)) {
        QDBusMessage call = QDBusMessage::createMethodCall(SnipShotService, SnipShotObjectPath, SnipShotService, "Activate");
        call << arguments;
        const QDBusMessage reply = bus.call(call, QDBus::Block, 5000);
        if (reply.type() == QDBusMessage::ErrorMessage) {
            std::fprintf(stderr, "SnipShot is running but did not answer: %s\n", qPrintable(reply.errorMessage()));
            return 1;
        }
        return 0;
    }

    Settings settings;
    ThemeSource themes(settings.configFolder());
    platformPalette = QGuiApplication::palette();
    QQuickStyle::setStyle(desktopStyle ? "Fusion" : "FluentWinUI3");
    applyAppearance(settings, themes);
    QObject::connect(&settings, &QQmlPropertyMap::valueChanged, &app, [&settings, &themes](const QString &key) {
        if (key == "colorScheme" || key == "themeSource" || key == "customTheme") applyAppearance(settings, themes);
    });
    AppearanceWatcher appearance([&settings, &themes] { applyAppearance(settings, themes); });

    CaptureBackend backend(&settings);
    qmlRegisterSingletonInstance("SnipShot.Core", 1, 0, "Capture", &backend);
    qmlRegisterSingletonInstance("SnipShot.Core", 1, 0, "Config", &settings);
    qmlRegisterSingletonInstance("SnipShot.Core", 1, 0, "ThemeFiles", &themes);

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, &app, [](const QList<QQmlError> &warnings) {
        for (const auto &warning : warnings) std::fprintf(stderr, "%s\n", qPrintable(warning.toString()));
    });
    auto *frozen = new FrozenImageProvider;
    engine.addImageProvider("frozen", frozen);
    engine.addImageProvider("icon", new DesktopIconProvider);
    engine.loadFromModule("SnipShot", "App");
    if (engine.rootObjects().isEmpty()) {
        std::fprintf(stderr, "SnipShot could not load its interface\n");
        return 1;
    }

    OverlayController overlays(&engine, frozen);
    overlays.attach(engine.rootObjects().constFirst());
    backend.setOverlays(&overlays);

    InstanceService service(&backend);
    if (bus.isConnected()) bus.registerObject(SnipShotObjectPath, &service, QDBusConnection::ExportScriptableSlots);

    backend.handleCommand(arguments);
    const int code = app.exec();
    backend.setOverlays(nullptr);
    return code;
}
