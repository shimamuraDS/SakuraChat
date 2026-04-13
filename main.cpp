#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QIcon>
#include <QQmlContext>
#include "configmanager.h"
#include <QQuickStyle>

#include "tcpmgr.h"

int main(int argc, char *argv[])
{
    QQuickStyle::setStyle("Basic");
    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/SakuraChat.icon"));

    ConfigManager::instance().loadConfig();

    QQmlApplicationEngine engine;

    engine.rootContext()->setContextProperty("tcpMgr", TcpMgr::GetInstance().get());

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("SakuraChat", "Main");

    return app.exec();
}
