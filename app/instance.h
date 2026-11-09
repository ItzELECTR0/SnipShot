#pragma once

#include <QObject>
#include <QDBusVariant>
#include <QStringList>

#include <functional>

inline constexpr auto SnipShotService = "io.github.ItzELECTR0.SnipShot";
inline constexpr auto SnipShotObjectPath = "/io/github/ItzELECTR0/SnipShot";

class CaptureBackend;

class InstanceService final : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "io.github.ItzELECTR0.SnipShot")

public:
    explicit InstanceService(CaptureBackend *backend, QObject *parent = nullptr);

public slots:
    Q_SCRIPTABLE void Activate(const QStringList &arguments);

private:
    CaptureBackend *m_backend;
};

class AppearanceWatcher final : public QObject {
    Q_OBJECT

public:
    explicit AppearanceWatcher(std::function<void()> changed);

private slots:
    void settingChanged(const QString &group, const QString &key, const QDBusVariant &value);

private:
    std::function<void()> m_changed;
};
