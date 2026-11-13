#include "capturebackend.h"
#include "instance.h"
#include "overlaycontroller.h"
#include "settings.h"
#include "themesource.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

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

int main(int argc, char *argv[]) {
    QCoreApplication::setApplicationName("SnipShot");
    QCoreApplication::setOrganizationName("SnipShot");
    QCoreApplication::setApplicationVersion(SNIPSHOT_VERSION);
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
    // Every control is drawn from Theme; Basic is the only style that never pulls in a platform look.
    QQuickStyle::setStyle("Basic");

    CaptureBackend backend(&settings);
    qmlRegisterSingletonInstance("SnipShot.Core", 1, 0, "Capture", &backend);
    qmlRegisterSingletonInstance("SnipShot.Core", 1, 0, "Config", &settings);
    qmlRegisterSingletonInstance("SnipShot.Core", 1, 0, "Appearance", &themes);

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
