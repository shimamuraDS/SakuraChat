#ifndef CONFIGMANAGER_H
#define CONFIGMANAGER_H

#include <QObject>
#include <QString>

class ConfigManager : public QObject
{
    Q_OBJECT

public:
    // C++ 经典的 Meyer's Singleton (线程安全)
    static ConfigManager& instance() {
        static ConfigManager instance;
        return instance;
    }

    // 初始化/加载配置
    void loadConfig();

    // 获取拼接好的 URL
    QString gateUrlPrefix() const { return m_gateUrlPrefix; }

private:
    explicit ConfigManager(QObject *parent = nullptr) : QObject(parent) {}
    // 禁用拷贝构造和赋值操作
    ConfigManager(const ConfigManager&) = delete;
    ConfigManager& operator=(const ConfigManager&) = delete;

    QString m_gateUrlPrefix;
};

#endif // CONFIGMANAGER_H
