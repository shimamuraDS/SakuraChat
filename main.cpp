#include <QGuiApplication>
#include <QApplication>
#include <QQmlApplicationEngine>
#include <QIcon>
#include <QQmlContext>
#include "configmanager.h"
#include <QQuickStyle>

#include "tcpmgr.h"
#include "applock.h"
#include "privatenotifications.h"

int main(int argc, char *argv[])
{
    QQuickStyle::setStyle("Basic");
    QApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/SakuraChat.icon"));

    ConfigManager::instance().loadConfig();

    PrivateNotifications notifications;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("privateNotifications", &notifications);

    engine.rootContext()->setContextProperty("tcpMgr", TcpMgr::GetInstance().get());
    auto &appLock = AppLock::instance();
    engine.rootContext()->setContextProperty("appLock", &appLock);
    QObject::connect(TcpMgr::GetInstance().get(), &TcpMgr::sig_switch_chatlg, &appLock, [&appLock] {
        appLock.beginSession(TcpMgr::GetInstance()->chatStore()->selfUid(), ConfigManager::instance().gateUrlPrefix());
    });
    QObject::connect(TcpMgr::GetInstance().get(), &TcpMgr::loggedOut, &appLock, &AppLock::endSession);
    QObject::connect(TcpMgr::GetInstance().get(), &TcpMgr::sig_switch_chatlg, &notifications, [&notifications] {
        notifications.beginSession(TcpMgr::GetInstance()->chatStore()->selfUid(), ConfigManager::instance().gateUrlPrefix());
    });
    QObject::connect(TcpMgr::GetInstance().get(), &TcpMgr::loggedOut, &notifications, &PrivateNotifications::endSession);
    QObject::connect(TcpMgr::GetInstance().get(), &TcpMgr::newPrivateMessage, &notifications, &PrivateNotifications::notifyNewMessage);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("SakuraChat", "Main");

    return app.exec();
}
