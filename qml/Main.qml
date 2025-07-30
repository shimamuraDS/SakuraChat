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

    // 登录
    LoginDialog {
        id: loginDialog
        anchors.fill: parent
        visible: window.showLogin

        onSwitchRegister: {
            window.showLogin = false
        }
    }

    // 注册
    RegisterDialog {
        id: registerDialog
        anchors.fill: parent
        visible: !window.showLogin

        onSwitchLogin: {
            window.showLogin = true
        }
    }
}
