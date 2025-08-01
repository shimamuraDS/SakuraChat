#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QIcon>
#include "registercontroller.h"
#include <QQmlContext>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    app.setWindowIcon(QIcon(":/SakuraChat.icon"));

    QQmlApplicationEngine engine;

    // 注册RegisterController到QML
    RegisterController *registerController = new RegisterController();
    engine.rootContext()->setContextProperty("registerController", registerController);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("SakuraChat", "Main");

    return app.exec();
}
