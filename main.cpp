#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QIcon>
#include "configmanager.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/SakuraChat.icon"));

    ConfigManager::instance().loadConfig();

    QQmlApplicationEngine engine;

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("SakuraChat", "Main");

    return app.exec();
}
