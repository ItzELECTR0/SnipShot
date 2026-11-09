#pragma once

#include <QQmlPropertyMap>
#include <QSettings>

class Settings final : public QQmlPropertyMap {
    Q_OBJECT

public:
    explicit Settings(QObject *parent = nullptr);

    bool flag(const QString &key) const { return value(key).toBool(); }
    int number(const QString &key) const { return value(key).toInt(); }
    QString text(const QString &key) const { return value(key).toString(); }
    void set(const QString &key, const QVariant &value);

    Q_INVOKABLE QString configFolder() const;

private:
    QSettings m_store;
};
