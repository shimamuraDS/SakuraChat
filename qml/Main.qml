import QtQuick
import QtQuick.Controls
import QtQuick.Window

ApplicationWindow {
    id: window
    width: 380
    height: 600
    visible: true
    title: qsTr("SakuraChat")

    // 状态管理
    property bool showLogin: true
    property bool showRegister: false
    property bool showReset: false

    // 登录
    Loader {
        id: loginLoader
        anchors.fill: parent
        active: showLogin
        sourceComponent: LoginDialog {
            onSwitchRegister: {
                showLogin = false
                showRegister = true
            }
            onSwitchReset: {
                showLogin = false
                showReset = true
            }
        }
    }

    // 注册
    Loader {
        id: registerLoader
        anchors.fill: parent
        active: showRegister
        sourceComponent: RegisterDialog {
            onSwitchLogin: {
                showRegister = false
                showLogin = true
            }
        }
    }

    // 重置
    Loader {
        id: resetLoader
        anchors.fill: parent
        active: showReset
        sourceComponent: ResetDialog {
            onSwitchLogin: {
                showReset = false
                showLogin = true
            }
        }
    }
}
