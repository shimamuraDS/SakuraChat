import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import SakuraChat

ApplicationWindow {
    id: root
    width: 880
    height: 680
    minimumWidth: conversationMode === "lan" ? 1000 : currentView === "chat" ? 940 : 800
    minimumHeight: currentView === "chat" ? 640 : 650
    flags: Qt.Window | Qt.FramelessWindowHint
    visible: true
    title: qsTr("SakuraChat")
    color: UiTheme.canvas
    font.family: "Microsoft YaHei UI"
    font.pixelSize: 14
    palette.window: UiTheme.canvas
    palette.base: UiTheme.field
    palette.button: UiTheme.field
    palette.buttonText: UiTheme.secondary
    palette.text: UiTheme.text
    palette.windowText: UiTheme.text
    palette.highlight: UiTheme.accent
    palette.highlightedText: UiTheme.text
    header: WindowTitleBar {
        window: root
        modeSwitchVisible: !appLock.locked
        conversationMode: root.conversationMode
        onModeRequested: function(mode) {
            if (mode === root.conversationMode) return
            if (mode === "default") lanChat.leave()
            root.conversationMode = mode
            if (mode === "lan") { root.width = Math.max(root.width, 1000); root.height = Math.max(root.height, 700) }
        }
        caption: root.currentView === "chat" ? "sakura / workspace" : "sakura / sign in"
        navigationVisible: root.conversationMode === "default" && root.currentView === "chat" && !appLock.locked
        activeAction: chatPage.privacyOpen ? "privacy" : lockSettings.visible ? "lock" : ""
        refreshAvailable: tcpMgr.chatReady && !tcpMgr.friendSyncBusy
        refreshing: tcpMgr.friendSyncBusy
        onUtilityRequested: function(action) { chatPage.triggerUtility(action) }
    }

    // Let the OS own resize gestures; do not manually update window geometry.
    Repeater {
        model: [Qt.LeftEdge, Qt.RightEdge, Qt.TopEdge, Qt.BottomEdge,
                Qt.LeftEdge | Qt.TopEdge, Qt.RightEdge | Qt.TopEdge,
                Qt.LeftEdge | Qt.BottomEdge, Qt.RightEdge | Qt.BottomEdge]
        delegate: MouseArea {
            required property int modelData
            parent: root.contentItem
            z: 1000
            visible: root.visibility !== Window.Maximized && !appLock.locked
            readonly property bool isLeftEdge: (modelData & Qt.LeftEdge) !== 0
            readonly property bool isRightEdge: (modelData & Qt.RightEdge) !== 0
            readonly property bool isTopEdge: (modelData & Qt.TopEdge) !== 0
            readonly property bool isBottomEdge: (modelData & Qt.BottomEdge) !== 0
            width: isLeftEdge || isRightEdge ? 6 : root.width - 12
            height: isTopEdge || isBottomEdge ? 6 : root.height - 12
            x: isLeftEdge ? 0 : isRightEdge ? root.width - width : 6
            y: isTopEdge ? -root.header.height : isBottomEdge ? root.contentItem.height - height : 6 - root.header.height
            cursorShape: (isLeftEdge || isRightEdge) && (isTopEdge || isBottomEdge)
                         ? (isLeftEdge === isTopEdge ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor)
                         : isLeftEdge || isRightEdge ? Qt.SizeHorCursor : Qt.SizeVerCursor
            onPressed: root.startSystemResize(modelData)
        }
    }

    // 让应用启动时就在屏幕正中间
    Component.onCompleted: {
        root.x = (Screen.width - root.width) / 2
        root.y = (Screen.height - root.height) / 2
    }

    // 界面状态：login | register | reset | chat
    property string currentView: "login"
    property string conversationMode: "default"
    Shortcut {
        sequence: "Ctrl+L"
        enabled: root.currentView === "chat" && appLock.enabled && !appLock.locked
        onActivated: appLock.lock()
    }


    onCurrentViewChanged: {
        root.showNormal()
        if (currentView === "chat") {
            // 目标大小
            root.width = Math.min(1320, Screen.desktopAvailableWidth)
            root.height = 760
            // 目标位置（保持在屏幕中心）
            root.x = (Screen.width - root.width) / 2
            root.y = (Screen.height - root.height) / 2
        } else {
            // 回到小窗口大小
            root.width = 880
            root.height = 680
            // 目标位置（保持在屏幕中心）
            root.x = (Screen.width - root.width) / 2
            root.y = (Screen.height - root.height) / 2
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

    AuthPanel {
        visible: root.conversationMode === "default" && root.currentView !== "chat" && !appLock.locked
        width: Math.min(340, root.width * 0.39)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

    StackLayout {
        id: stackLayout
        anchors.fill: parent
        anchors.leftMargin: root.currentView === "chat" ? 0 : Math.min(340, root.width * 0.39)
        visible: root.conversationMode === "default" && !appLock.locked
        enabled: visible

        // 根据 currentView 属性动态返回对应的子页面索引
        currentIndex: {
            if (root.currentView === "register") return 1
            if (root.currentView === "reset") return 2
            if (root.currentView === "chat") return 3
            return 0 // 默认为 0 (login)
        }
        onCurrentIndexChanged: pageEntrance.restart()
        NumberAnimation {
            id: pageEntrance
            target: stackLayout
            property: "opacity"
            from: 0.65; to: 1
            duration: 160
            easing.type: Easing.OutCubic
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
            id: chatPage
            onLogoutRequested: TcpMgr.logout()
            onLockSettingsRequested: lockSettings.open()
        }
    }

    LanChatPage {
        anchors.fill: parent
        visible: root.conversationMode === "lan" && !appLock.locked
        enabled: visible
    }

    SakuraDialog {
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
            SakuraField { id: newLockPassword; Layout.fillWidth: true; visible: !appLock.enabled
                placeholderText: qsTr("独立解锁密码：8～128 个 UTF-8 字节")
                echoMode: TextInput.Password; maximumLength: 128
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData }
            SakuraField { id: confirmLockPassword; Layout.fillWidth: true; visible: !appLock.enabled
                placeholderText: qsTr("再次输入解锁密码"); echoMode: TextInput.Password; maximumLength: 128
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData }
            SakuraButton { text: qsTr("启用应用锁"); visible: !appLock.enabled; enabled: !appLock.busy
                onClicked: {
                    appLock.configure(newLockPassword.text, confirmLockPassword.text)
                    newLockPassword.clear(); confirmLockPassword.clear()
                }
            }
            SakuraButton { text: qsTr("立即锁定"); visible: appLock.enabled; enabled: !appLock.busy
                onClicked: appLock.lock() }
            SakuraButton { text: qsTr("关闭此账号的应用锁…"); visible: appLock.enabled; enabled: !appLock.busy
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
        background: Rectangle { color: UiTheme.canvas }
        onOpened: unlockPassword.forceActiveFocus()
        onClosed: unlockPassword.clear()
        contentItem: ColumnLayout {
            WindowTitleBar { window: root; caption: qsTr("SakuraChat · 已锁定"); Layout.fillWidth: true }
            Item { Layout.fillHeight: true }
            Label { text: qsTr("SakuraChat 已锁定"); font.pixelSize: 24; Layout.alignment: Qt.AlignHCenter }
            SakuraField { id: unlockPassword; Layout.fillWidth: true; Layout.maximumWidth: 360
                Layout.alignment: Qt.AlignHCenter; placeholderText: qsTr("输入此账号的应用锁密码")
                echoMode: TextInput.Password; maximumLength: 128; enabled: !appLock.busy
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                onAccepted: { appLock.unlock(text); clear() }
            }
            SakuraButton { text: appLock.busy ? qsTr("正在校验…") : qsTr("解锁")
                Layout.alignment: Qt.AlignHCenter; enabled: !appLock.busy
                onClicked: { appLock.unlock(unlockPassword.text); unlockPassword.clear() }
            }
            Label { text: appLock.message; textFormat: Text.PlainText; wrapMode: Text.Wrap
                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
            SakuraButton { text: qsTr("退出登录（不会清除应用锁）")
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
    SakuraDialog {
        id: disableLockDialog
        title: qsTr("关闭应用锁？")
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: appLock.disable()
        Label { text: qsTr("关闭后，此账号在本机不再自动锁定。") }
    }
}
