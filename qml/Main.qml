import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: root
    width: 400
    height: 550
    visible: true
    title: qsTr("SakuraChat")

    // 让应用启动时就在屏幕正中间
        Component.onCompleted: {
            root.x = (Screen.width - root.width) / 2
            root.y = (Screen.height - root.height) / 2
        }

    // 界面状态：login | register | reset | chat
    property string currentView: "login"

    Behavior on width {
            NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
        }
        Behavior on height {
            NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
        }
        Behavior on x {
            NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
        }
        Behavior on y {
            NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
        }

    onCurrentViewChanged: {
        if (currentView === "chat") {
            // 目标大小
            root.width = 1000
            root.height = 680
            // 目标位置（保持在屏幕中心）
            root.x = (Screen.width - 1000) / 2
            root.y = (Screen.height - 680) / 2
        } else {
            // 回到小窗口大小
            root.width = 400
            root.height = 550
            // 目标位置（保持在屏幕中心）
            root.x = (Screen.width - 400) / 2
            root.y = (Screen.height - 550) / 2
        }
    }

    // 监听 C++ 后端 TcpMgr 的切换信号
    Connections {
        target: tcpMgr
        ignoreUnknownSignals: true

        function onSig_switch_chatdlg() {
            root.currentView = "chat"
        }
    }

    StackLayout {
        id: stackLayout
        anchors.fill: parent

        // 根据 currentView 属性动态返回对应的子页面索引
        currentIndex: {
            if (root.currentView === "register") return 1
            if (root.currentView === "reset") return 2
            if (root.currentView === "chat") return 3
            return 0 // 默认为 0 (login)
        }

        // Index 0: 登录页
        LoginDialog {
            Layout.fillWidth: true
            Layout.fillHeight: true
            onSwitchRegister: root.currentView = "chat"
            onSwitchReset: root.currentView = "reset"
        }

        // Index 1: 注册页
        RegisterDialog {
            Layout.fillWidth: true
            Layout.fillHeight: true
            onSwitchLogin: root.currentView = "login"
        }

        // Index 2: 重置密码页
        ResetDialog {
            Layout.fillWidth: true
            Layout.fillHeight: true
            onSwitchLogin: root.currentView = "login"
        }

        // Index 3: 聊天主界面
        ChatDialog {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
