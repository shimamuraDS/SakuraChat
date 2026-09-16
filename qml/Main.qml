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
    title: insecureTestBuild ? qsTr("SakuraChat · 不安全测试版") : qsTr("SakuraChat")
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
    footer: Rectangle {
        visible: insecureTestBuild
        height: visible ? 42 : 0
        color: "#4a3015"
        Text {
            anchors.fill: parent; anchors.margins: 7
            text: qsTr("不安全测试版 · HTTPS 网关 / TCP 明文聊天 · 仅使用测试账号，勿发送真实隐私信息")
            color: "#ffdb99"; font.pixelSize: 12; wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
    }
    SakuraDialog {
        id: insecureNotice
        anchors.centerIn: parent; width: Math.min(500, root.width - 40)
        title: qsTr("仅供不安全网络测试")
        modal: true; closePolicy: Popup.NoAutoClose; standardButtons: Dialog.Ok
        contentItem: Label {
            text: qsTr("此版本未签名。登录网关使用 HTTPS，但聊天连接未启用 TLS，登录令牌和普通消息可能被截获或篡改。请仅使用专用测试账号，不要复用真实密码。Signal 消息加密不能消除账号令牌泄露的风险。\n\n测试数据与正常版本使用不同的本机数据目录。关闭程序后，本地测试记录仍会保留。")
            color: UiTheme.text; wrapMode: Text.Wrap
        }
    }
    header: WindowTitleBar {
        updatesVisible: true
        window: root
        onUpdateRequested: updateDialog.open()
        updateAvailable: updater.updateAvailable
        modeSwitchVisible: !appLock.locked
        privateModeAvailable: root.currentView === "chat"
        conversationMode: root.conversationMode
        onModeRequested: function(mode) {
            if (mode === root.conversationMode) return
            if (mode !== "lan") lanChat.leave()
            root.conversationMode = mode
            if (mode === "lan") { root.width = Math.max(root.width, 1000); root.height = Math.max(root.height, 700) }
        }
        caption: root.currentView === "chat" ? "sakura / workspace" : "sakura / sign in"
        navigationVisible: root.conversationMode !== "lan" && root.currentView === "chat" && !appLock.locked
        activeAction: chatPage.privacyOpen ? "privacy" : lockSettings.visible ? "lock" : ""
        refreshAvailable: tcpMgr.chatReady && !tcpMgr.friendSyncBusy
        refreshing: tcpMgr.friendSyncBusy
        onUtilityRequested: function(action) { chatPage.triggerUtility(action) }
    }

    SakuraDialog {
        id: updateDialog
        title: qsTr("版本与更新")
        anchors.centerIn: parent; width: Math.min(520, root.width - 40)
        modal: true; standardButtons: Dialog.Close
        contentItem: ColumnLayout {
            Label { text: "SakuraChat " + updater.version; font.pixelSize: 20; color: UiTheme.text }
            Label { Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.PlainText; text: updater.status; color: updater.updateAvailable ? UiTheme.cyan : UiTheme.secondary }
            ScrollView {
                Layout.fillWidth: true; Layout.preferredHeight: Math.min(200, releaseNotes.implicitHeight + 12)
                visible: updater.updateAvailable && updater.notes.length > 0
                contentWidth: availableWidth; clip: true
                TextArea { id: releaseNotes; readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap; textFormat: TextEdit.PlainText; text: updater.notes; color: UiTheme.secondary }
            }
            SakuraCheckBox { text: qsTr("每天检查新版本"); checked: updater.automaticChecks; onToggled: updater.automaticChecks = checked }
            Label { Layout.fillWidth: true; wrapMode: Text.Wrap; text: qsTr("只检查版本，不自动下载或安装。检查失败不会影响聊天。"); color: UiTheme.muted; font.pixelSize: 12 }
            RowLayout {
                SakuraButton { text: updater.busy ? qsTr("正在检查…") : qsTr("检查更新"); enabled: !updater.busy; onClicked: updater.check() }
                SakuraButton { text: updater.updateAvailable ? qsTr("前往 GitHub 下载") : qsTr("查看发布页面"); primary: updater.updateAvailable; onClicked: updater.openReleasePage() }
            }
        }
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
        if (insecureTestBuild) insecureNotice.open()
        root.x = (Screen.width - root.width) / 2
        root.y = (Screen.height - root.height) / 2
    }

    // 界面状态：login | register | reset | chat
    property string currentView: "login"
    property string conversationMode: "default"
    onConversationModeChanged: {
        UiTheme.privateMode = conversationMode === "private"
        privateChat.setActive(conversationMode === "private" && !appLock.locked)
    }
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
            root.conversationMode = "default"
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
        visible: root.conversationMode !== "lan" && !appLock.locked
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
            privateMode: root.conversationMode === "private"
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
            privateChat.setActive(root.conversationMode === "private" && !appLock.locked)
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
