#include <QGuiApplication>
#include <QApplication>
#include <QQmlApplicationEngine>
#include <QIcon>
#include <QQmlContext>
#include "configmanager.h"
#include <QQuickStyle>
#ifdef Q_OS_WIN
#include <windows.h>
#include <dwmapi.h>
#include <QWindow>
#endif

#include "tcpmgr.h"
#include "lanchat.h"
#include "applock.h"
#include "privatenotifications.h"

int main(int argc, char *argv[])
{
    QQuickStyle::setStyle("Basic");
    QApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/res/sakura-mark.ico"));

    ConfigManager::instance().loadConfig();

    PrivateNotifications notifications;
    LanChat lanChat;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("lanChat", &lanChat);
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

#ifdef Q_OS_WIN
    // Windows 11 rounded desktop corners; unsupported systems keep their native shape.
    if (!engine.rootObjects().isEmpty()) {
        if (auto *window = qobject_cast<QWindow *>(engine.rootObjects().first())) {
            const DWORD roundedCorners = 2; // DWMWCP_ROUND
            DwmSetWindowAttribute(reinterpret_cast<HWND>(window->winId()),
                                  33, &roundedCorners, sizeof(roundedCorners));
        }
    }
#endif

    return app.exec();
}
