#include "settings.h"

#include <QFileInfo>
#include <QMetaType>

namespace {
struct Default {
    const char *key;
    QVariant value;
};

const Default defaults[] = {
    {"autoCopy", true},
    {"autoSave", true},
    {"screenshotFolder", QString()},
    {"recordingFolder", QString()},
    {"border", false},
    {"borderColor", QStringLiteral("#7a7a7a")},
    {"borderWidth", 1},
    {"delay", 0},
    {"snipMode", QStringLiteral("rectangle")},
    {"ocrLanguages", QStringLiteral("eng")},
    {"recorderBackend", 0},
    {"framerate", 60},
    {"microphone", false},
    {"systemAudio", true},
    {"notifications", true},
    {"themeSource", QStringLiteral("fluent")},
    {"colorScheme", QStringLiteral("system")},
    {"customTheme", QString()},
    {"desktopIcons", false},
};
}

Settings::Settings(QObject *parent) : QQmlPropertyMap(this, parent) {
    for (const auto &entry : defaults) {
        const QString key = QString::fromLatin1(entry.key);
        QVariant stored = m_store.value(key, entry.value);
        if (stored.metaType() != entry.value.metaType()) stored.convert(entry.value.metaType());
        insert(key, stored);
    }
    connect(this, &QQmlPropertyMap::valueChanged, this, [this](const QString &key, const QVariant &value) {
        m_store.setValue(key, value);
        m_store.sync();
    });
}

void Settings::set(const QString &key, const QVariant &value) {
    if (this->value(key) == value) return;
    insert(key, value);
    m_store.setValue(key, value);
    m_store.sync();
}

QString Settings::configFolder() const { return QFileInfo(m_store.fileName()).absolutePath(); }
