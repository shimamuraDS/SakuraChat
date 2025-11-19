#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QIcon>
#include "registercontroller.h"
#include "resetcontroller.h"
#include "logincontroller.h"
#include <QQmlContext>
#include <QDir>
#include <QSettings>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    app.setWindowIcon(QIcon(":/SakuraChat.icon"));

    qDebug() << "Current working dir:" << QDir::currentPath();


    // 解析配置文件
    QString config_path = "config.ini";
    QSettings settings(config_path, QSettings::IniFormat);
    QString gate_host = settings.value("GateServer/host").toString();
    QString gate_port = settings.value("GateServer/port").toString();
    if (gate_host.isEmpty() || gate_port.isEmpty()) {
        qWarning() << "GateServer host/port not found in config.ini!";
    } else {
        gate_url_prefix = "http://" + gate_host + ":" + gate_port;
    }

    QQmlApplicationEngine engine;

    // 注册到QML
    RegisterController *registerController = new RegisterController();
    ResetController *resetController = new ResetController();
    LoginController *loginController = new LoginController();
    engine.rootContext()->setContextProperty("registerController", registerController);
    engine.rootContext()->setContextProperty("resetController", resetController);
    engine.rootContext()->setContextProperty("loginController", loginController);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("SakuraChat", "Main");

    return app.exec();
}
