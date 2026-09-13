import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import SakuraChat

ApplicationWindow {
    id: root
    width: 400
    height: 550
    visible: true
    title: qsTr("SakuraChat")
    color: "#f5f7fb"

    // 让应用启动时就在屏幕正中间
    Component.onCompleted: {
        root.x = (Screen.width - root.width) / 2
        root.y = (Screen.height - root.height) / 2
    }

    // 界面状态：login | register | reset | chat
    property string currentView: "login"
    Shortcut {
        sequence: "Ctrl+L"
        enabled: root.currentView === "chat" && appLock.enabled && !appLock.locked
        onActivated: appLock.lock()
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
        target: TcpMgr
        ignoreUnknownSignals: true

        function onSig_switch_chatlg() {
            root.currentView = "chat"
        }
        function onLoggedOut() {
            lockSettings.close()
            disableLockDialog.close()
            root.currentView = "login"
        }
    }

    StackLayout {
        id: stackLayout
        anchors.fill: parent
        visible: !appLock.locked
        enabled: !appLock.locked

        // 根据 currentView 属性动态返回对应的子页面索引
        currentIndex: {
            if (root.currentView === "register") return 1
            if (root.currentView === "reset") return 2
            if (root.currentView === "chat") return 3
            return 0 // 默认为 0 (login)
        }

        // Index 0: 登录页
        LoginDialog {
            onSwitchRegister: root.currentView = "register"
            onSwitchReset: root.currentView = "reset"
        }

        // Index 1: 注册页
        RegisterDialog {
            onSwitchLogin: root.currentView = "login"
        }

        // Index 2: 重置密码页
        ResetDialog {
            onSwitchLogin: root.currentView = "login"
        }

        // Index 3: 聊天主界面
        ChatDialog {
            onLogoutRequested: TcpMgr.logout()
            onLockSettingsRequested: lockSettings.open()
        }
    }

    Dialog {
        id: lockSettings
        title: qsTr("此账号的应用锁")
        anchors.centerIn: parent
        width: Math.min(440, root.width - 24)
        modal: true
        standardButtons: Dialog.Close
        onClosed: { newLockPassword.clear(); confirmLockPassword.clear() }
        contentItem: ColumnLayout {
            Label { Layout.fillWidth: true; wrapMode: Text.Wrap
                text: qsTr("启用后，切到其他应用立即锁定；5 分钟无输入自动锁定。设置保存在本机，下次登录仍需解锁。请妥善保存独立密码，退出登录不会重置它。") }
            TextField { id: newLockPassword; Layout.fillWidth: true; visible: !appLock.enabled
                placeholderText: qsTr("独立解锁密码：8～128 个 UTF-8 字节")
                echoMode: TextInput.Password; maximumLength: 128
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData }
            TextField { id: confirmLockPassword; Layout.fillWidth: true; visible: !appLock.enabled
                placeholderText: qsTr("再次输入解锁密码"); echoMode: TextInput.Password; maximumLength: 128
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData }
            Button { text: qsTr("启用应用锁"); visible: !appLock.enabled; enabled: !appLock.busy
                onClicked: {
                    appLock.configure(newLockPassword.text, confirmLockPassword.text)
                    newLockPassword.clear(); confirmLockPassword.clear()
                }
            }
            Button { text: qsTr("立即锁定"); visible: appLock.enabled; enabled: !appLock.busy
                onClicked: appLock.lock() }
            Button { text: qsTr("关闭此账号的应用锁…"); visible: appLock.enabled; enabled: !appLock.busy
                onClicked: disableLockDialog.open() }
            Label { Layout.fillWidth: true; wrapMode: Text.Wrap; text: appLock.message; textFormat: Text.PlainText }
        }
    }

    Popup {
        id: lockScreen
        parent: Overlay.overlay
        x: 0; y: 0; width: root.width; height: root.height
        padding: 24
        z: 100000
        modal: true; focus: true
        closePolicy: Popup.NoAutoClose
        background: Rectangle { color: "#f5f7fb" }
        onOpened: unlockPassword.forceActiveFocus()
        onClosed: unlockPassword.clear()
        contentItem: ColumnLayout {
            Item { Layout.fillHeight: true }
            Label { text: qsTr("SakuraChat 已锁定"); font.pixelSize: 24; Layout.alignment: Qt.AlignHCenter }
            TextField { id: unlockPassword; Layout.fillWidth: true; Layout.maximumWidth: 360
                Layout.alignment: Qt.AlignHCenter; placeholderText: qsTr("输入此账号的应用锁密码")
                echoMode: TextInput.Password; maximumLength: 128; enabled: !appLock.busy
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                onAccepted: { appLock.unlock(text); clear() }
            }
            Button { text: appLock.busy ? qsTr("正在校验…") : qsTr("解锁")
                Layout.alignment: Qt.AlignHCenter; enabled: !appLock.busy
                onClicked: { appLock.unlock(unlockPassword.text); unlockPassword.clear() }
            }
            Label { text: appLock.message; textFormat: Text.PlainText; wrapMode: Text.Wrap
                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
            Button { text: qsTr("退出登录（不会清除应用锁）")
                Layout.alignment: Qt.AlignHCenter; onClicked: TcpMgr.logout() }
            Item { Layout.fillHeight: true }
        }
    }
    Connections {
        target: appLock
        function onChanged() {
            if (appLock.locked) { disableLockDialog.close(); lockSettings.close(); lockScreen.open() }
            else lockScreen.close()
        }
    }
    Dialog {
        id: disableLockDialog
        title: qsTr("关闭应用锁？")
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: appLock.disable()
        Label { text: qsTr("关闭后，此账号在本机不再自动锁定。") }
    }
}
