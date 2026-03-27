#include "configmanager.h"
#include <QCoreApplication>
#include <QSettings>
#include <QDebug>

void ConfigManager::loadConfig()
{
    QString config_path = QCoreApplication::applicationDirPath() + "/config.ini";
    QSettings settings(config_path, QSettings::IniFormat);

    QString gate_host = settings.value("GateServer/host").toString();
    QString gate_port = settings.value("GateServer/port").toString();

    if (gate_host.isEmpty() || gate_port.isEmpty()) {
        qWarning() << "GateServer host/port not found in config.ini!";
        m_gateUrlPrefix = "";
    } else {
        m_gateUrlPrefix = QString("http://%1:%2").arg(gate_host, gate_port);
        qDebug() << "Gate URL Loaded:" << m_gateUrlPrefix;
    }
}
