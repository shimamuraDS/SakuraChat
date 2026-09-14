// ChatDialog.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import SakuraChat

Rectangle {
    id: chatDialog
    width: 1000
    height: 680
    color: UiTheme.surface
    // ───────────────────────────────────────────────────
    // 颜色常量
    // ───────────────────────────────────────────────────
    readonly property color sidebarBg:      UiTheme.rail
    readonly property color panelBg:        UiTheme.surface
    readonly property color panelBorder:    UiTheme.border
    readonly property color searchBg:       UiTheme.field
    readonly property color accentBlue:     UiTheme.accent
    readonly property color msgBubbleSelf:  UiTheme.selection
    readonly property color msgBubbleOther: UiTheme.surface
    readonly property color textPrimary:    UiTheme.text
    readonly property color textSecondary:  UiTheme.secondary
    readonly property color hoverOverlay:   UiTheme.scrim
    readonly property color contactBg:        UiTheme.canvas
    readonly property color contactDivider:   UiTheme.border
    readonly property color applyItemDivider: UiTheme.border
    readonly property color addBtnNormal:     UiTheme.border
    readonly property color addBtnHover:      UiTheme.border
    readonly property color addBtnPress:      UiTheme.border
    readonly property color addBtnText:       UiTheme.success

    property string activeTab: "chat"
    property bool detailsOpen: true
    readonly property int pendingApplications: applyFriendPage.pendingCount
    readonly property bool privacyOpen: privacyDialog.visible
    function triggerUtility(action) {
        if (appLock.locked) return
        if (action === "privacy") privacyDialog.open()
        else if (action === "lock") chatDialog.lockSettingsRequested()
        else if (action === "refresh" && tcpMgr.chatReady && !tcpMgr.friendSyncBusy) tcpMgr.refreshFriends()
    }
    property string chatErrorMessage: ""
    signal logoutRequested()
    signal lockSettingsRequested()

    SakuraDialog {
        id: retentionDialog
        title: qsTr("今后发出消息的自动删除")
        anchors.centerIn: parent
        width: 440
        modal: true
        property bool submitted: false
        onOpened: {
            submitted = false
            retentionChoice.currentIndex = Math.max(0, [0,86400,604800,2592000].indexOf(tcpMgr.privacy.retention_seconds))
            retentionConsent.checked = false
            chatDialog.chatErrorMessage = ""
        }
        contentItem: ColumnLayout {
            Label { Layout.fillWidth: true; wrapMode: Text.Wrap
                text: qsTr("只影响设置成功后发出的新消息。到期会为双方删除；旧消息不补设期限，关闭也不取消已排定的期限。截图、导出和备份无法远程擦除。") }
            SakuraComboBox { id: retentionChoice; Layout.fillWidth: true; enabled: !tcpMgr.privacyPending
                model: [qsTr("关闭"), qsTr("24 小时"), qsTr("7 天"), qsTr("30 天")] }
            SakuraCheckBox { id: retentionConsent; text: qsTr("我已了解上述删除范围和不可撤销性"); enabled: !tcpMgr.privacyPending }
            SakuraButton { text: qsTr("确认保存"); enabled: retentionConsent.checked && !tcpMgr.privacyPending && tcpMgr.privacy.error === 0
                onClicked: {
                    retentionDialog.submitted = true
                    chatDialog.chatErrorMessage = ""
                    tcpMgr.privacyCommand({action: "set_retention", seconds: [0,86400,604800,2592000][retentionChoice.currentIndex]})
                }
            }
            Label { Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.PlainText
                text: tcpMgr.privacyPending ? qsTr("正在保存…") : chatDialog.chatErrorMessage }
            SakuraButton { text: qsTr("关闭"); onClicked: retentionDialog.close() }
        }
        Connections {
            target: tcpMgr
            function onPrivacyChanged() {
                if (retentionDialog.visible && retentionDialog.submitted && !tcpMgr.privacyPending) {
                    retentionDialog.submitted = false
                    if (chatDialog.chatErrorMessage.length === 0 && tcpMgr.privacy.retention_seconds === [0,86400,604800,2592000][retentionChoice.currentIndex])
                        chatDialog.chatErrorMessage = qsTr("服务器已确认保存自动删除设置")
                }
            }
            function onLoggedOut() { retentionDialog.close() }
        }
        Connections { target: appLock; function onChanged() { if (appLock.locked) retentionDialog.close() } }
    }

    SakuraDialog {
        id: deleteMessageDialog
        property string messageId: ""
        property bool sentByMe: false
        property string resultText: ""
        title: qsTr("删除这条消息？")
        anchors.centerIn: parent
        width: 430
        modal: true
        closePolicy: tcpMgr.deletionPending ? Popup.NoAutoClose : Popup.CloseOnEscape
        contentItem: ColumnLayout {
            Label { Layout.fillWidth: true; wrapMode: Text.Wrap
                text: qsTr("默认仅从你的账号删除，对方仍可保留消息。删除不可撤销，不能清除对方已有截图、导出或备份。") }
            SakuraCheckBox { id: deleteForEveryone; visible: deleteMessageDialog.sentByMe
                text: qsTr("同时为对方删除（仅发送者可选）"); enabled: !tcpMgr.deletionPending }
            Label { Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.PlainText
                text: tcpMgr.deletionPending ? qsTr("正在等待服务器确认…") : deleteMessageDialog.resultText }
            RowLayout {
                SakuraButton { text: qsTr("取消"); enabled: !tcpMgr.deletionPending; onClicked: deleteMessageDialog.close() }
                SakuraButton { text: qsTr("确认删除"); enabled: !tcpMgr.deletionPending
                    onClicked: {
                        deleteMessageDialog.resultText = ""
                        tcpMgr.deleteMessage(deleteMessageDialog.messageId, deleteMessageDialog.sentByMe && deleteForEveryone.checked)
                    }
                }
            }
        }
        Connections {
            target: tcpMgr
            function onDeletionFinished(success, message) {
                if (!deleteMessageDialog.visible) return
                if (success) deleteMessageDialog.close()
                else deleteMessageDialog.resultText = message
            }
            function onLoggedOut() { deleteMessageDialog.close() }
        }
        Connections {
            target: appLock
            function onChanged() { if (appLock.locked) deleteMessageDialog.close() }
        }
    }

    SakuraDialog {
        id: privacyDialog
        title: qsTr("隐私与安全 · 云端聊天")
        anchors.centerIn: parent
        width: Math.min(540, chatDialog.width - 48)
        modal: true
        standardButtons: Dialog.Close
        onOpened: {
            chatDialog.chatErrorMessage = ""
            tcpMgr.privacyCommand({action: "get"})
        }
        contentItem: ScrollView {
            id: privacyScroll
            implicitHeight: Math.min(chatDialog.height - 160, 540, privacyColumn.implicitHeight)
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
            id: privacyColumn
            width: privacyScroll.availableWidth
            spacing: 10
            Label { text: qsTr("设置由服务器执行；本模式不是端到端加密。") }
            RowLayout {
                SakuraButton { text: qsTr("应用锁设置")
                    onClicked: { privacyDialog.close(); chatDialog.lockSettingsRequested() } }
                SakuraButton { text: qsTr("自动删除设置"); enabled: !tcpMgr.privacyPending && tcpMgr.privacy.error === 0
                    onClicked: { privacyDialog.close(); retentionDialog.open() } }
            }
            Label { text: qsTr("谁可以搜索到我") }
            SakuraComboBox { id: searchPrivacy; Layout.fillWidth: true; model: ["所有人", "好友", "仅自己"] }
            Label { text: qsTr("谁可以向我发送好友申请") }
            SakuraComboBox { id: requestPrivacy; Layout.fillWidth: true; model: ["所有人", "好友", "不接受"] }
            Label { text: qsTr("谁可以查看头像、昵称与简介") }
            SakuraComboBox { id: profilePrivacy; Layout.fillWidth: true; model: ["所有人", "好友", "仅自己"] }
            SakuraCheckBox { Layout.fillWidth: true; id: readPrivacy; text: qsTr("发送已读回执（关闭不撤回已发送的回执）") }
            SakuraCheckBox {
                text: qsTr("桌面通用提醒（不显示联系人或正文）")
                checked: privateNotifications.enabled
                onClicked: privateNotifications.enabled = checked
            }
            Label { Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.PlainText
                text: privateNotifications.available ? privateNotifications.message : qsTr("当前系统暂不支持桌面提醒") }
            SakuraButton {
                primary: true
                text: qsTr("保存隐私设置")
                enabled: !tcpMgr.privacyPending && tcpMgr.privacy.error === 0
                onClicked: tcpMgr.privacyCommand({action: "set", search_policy: searchPrivacy.currentIndex,
                    request_policy: requestPrivacy.currentIndex, profile_policy: profilePrivacy.currentIndex,
                    read_receipts: readPrivacy.checked})
            }
            RowLayout {
                SakuraField { Layout.fillWidth: true; Layout.minimumWidth: 90; id: blockUid; placeholderText: qsTr("用户 UID"); validator: IntValidator { bottom: 1 } }
                SakuraButton { text: qsTr("拉黑"); enabled: blockUid.acceptableInput && !tcpMgr.privacyPending
                    onClicked: tcpMgr.privacyCommand({action: "block", uid: Number(blockUid.text)}) }
                SakuraButton { text: qsTr("解除"); enabled: blockUid.acceptableInput && !tcpMgr.privacyPending
                    onClicked: tcpMgr.privacyCommand({action: "unblock", uid: Number(blockUid.text)}) }
            }
            Label { Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.PlainText
                text: qsTr("本页黑名单 UID：") + (tcpMgr.privacy.blocked || []).join(", ") }
            SakuraButton { text: qsTr("下一页黑名单"); visible: tcpMgr.privacy.has_more === true; enabled: !tcpMgr.privacyPending
                onClicked: tcpMgr.privacyCommand({action: "get", after_uid: tcpMgr.privacy.next_uid}) }
            Label { Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.PlainText
                text: tcpMgr.privacyPending ? qsTr("正在与服务器同步…") : chatDialog.chatErrorMessage }
            }
        }
        Connections {
            target: tcpMgr
            function onPrivacyChanged() {
                if (tcpMgr.privacyPending || tcpMgr.privacy.error !== 0) return
                searchPrivacy.currentIndex = tcpMgr.privacy.search_policy
                requestPrivacy.currentIndex = tcpMgr.privacy.request_policy
                profilePrivacy.currentIndex = tcpMgr.privacy.profile_policy
                readPrivacy.checked = tcpMgr.privacy.read_receipts
            }
            function onLoggedOut() { privacyDialog.close() }
        }
    }

    function openPeer(uid) {
        if (tcpMgr.chatStore.openConversation(uid)) {
            chatDialog.activeTab = "chat"
            chatDialog.chatErrorMessage = ""
        }
    }

    // 搜索结果数据模型（替代原 SearchList + addSearchItem）
    // 由 C++ 侧 TcpMgr/SearchController 的 sig_user_search 信号填充
    ListModel {
        id: searchResultModel
    }

    // 搜索防抖定时器（300ms，避免每次按键触发网络请求）
    Timer {
        id: searchDebounceTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (searchInput.text.trim().length > 0) {
                // 用户搜索
                tcpMgr.searchUser(searchInput.text)
            }
        }
    }

    // 搜索错误信息，供搜索面板读取
    property string searchError: ""

    Connections {
        target: tcpMgr

        function onSig_user_search(results) {
            chatDialog.searchError = ""
            searchResultModel.clear()

            for (let i = 0; i < results.length; ++i)
                searchResultModel.append(results[i])
        }

        function onSig_search_failed(error, message) {
            searchResultModel.clear()
            console.warn("Search failed", error)
            chatDialog.searchError = qsTr("暂时无法搜索用户，请稍后重试")
        }

        function onSig_friend_apply_result(error, result, applyId) {
            if (error !== 0) {
                chatDialog.chatErrorMessage = qsTr("好友申请发送失败，请稍后重试")
            } else if (result === 0) {
                chatDialog.chatErrorMessage = qsTr("好友申请已发送，等待对方处理")
            } else if (result === 1) {
                chatDialog.chatErrorMessage = qsTr("你们已经是好友了")
            } else {
                chatDialog.chatErrorMessage = qsTr("暂时无法添加该用户，请确认后重试")
            }
        }

        function onChatError(message) {
            chatDialog.chatErrorMessage = message
        }
        function onChatReadyChanged() {
            if (tcpMgr.chatReady) chatDialog.chatErrorMessage = ""
        }
        function onLoggedOut() {
            messageInput.clear()
            searchInput.clear()
            searchResultModel.clear()
            chatDialog.searchError = ""
            chatDialog.chatErrorMessage = ""
            chatDialog.activeTab = "chat"
            findSuccessDialog.close()
            applyFriendPopup.close()
        }
        function onSig_friend_apply_resolved(error, result, applyId, agree) {
            if (error !== 0 || result !== 0)
                chatDialog.chatErrorMessage = qsTr("暂时无法处理好友申请，请稍后重试")
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ═══════════════════════════════════════════════
        // 区域 1：左侧侧边栏
        // ═══════════════════════════════════════════════
        Rectangle {
            Layout.preferredWidth: 72
            Layout.fillHeight: true
            color: chatDialog.sidebarBg

            Column {
                anchors.top: parent.top; anchors.topMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 40; height: 40; radius: 12
                    color: UiTheme.selection; border.color: UiTheme.border
                    Image { anchors.fill: parent; source: "qrc:/res/sakura-mark.png"; mipmap: true; fillMode: Image.PreserveAspectFit }
                }
                SidebarIconBtn {
                    iconText: "chat"; tooltipText: qsTr("聊天")
                    isActive: chatDialog.activeTab === "chat"
                    onClicked: chatDialog.activeTab = "chat"
                }
                SidebarIconBtn {
                    iconText: "contacts"; tooltipText: qsTr("联系人")
                    isActive: chatDialog.activeTab === "contact"
                    onClicked: chatDialog.activeTab = "contact"
                }
                SidebarIconBtn {
                    iconText: "request"; tooltipText: qsTr("好友申请")
                    isActive: chatDialog.activeTab === "apply"
                    badgeCount: chatDialog.pendingApplications
                    onClicked: chatDialog.activeTab = "apply"
                }
            }
            SidebarIconBtn {
                anchors.bottom: parent.bottom; anchors.bottomMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                iconText: "logout"; tooltipText: qsTr("退出登录")
                onClicked: chatDialog.logoutRequested()
            }
        }

        // ═══════════════════════════════════════════════
        // 区域 2-4：联系人面板（含搜索结果覆盖层）
        // ═══════════════════════════════════════════════
        Rectangle {
            id: contactListPanel
            Layout.preferredWidth: 292
            Layout.fillHeight: true
            color: chatDialog.panelBg

            // 右侧分隔线
            Rectangle {
                anchors.right: parent.right
                width: 1; height: parent.height
                color: chatDialog.panelBorder
                z: 2
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // 区域 2：搜索栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    color: UiTheme.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 4
                            color: chatDialog.searchBg

                            SakuraField {
                                id: searchInput
                                anchors.fill: parent
                                placeholderText: "搜索"
                                font.pixelSize: 14
                                color: chatDialog.textPrimary
                                background: null

                                // 增加左侧内边距，为搜索图标留出空间
                                leftPadding: 36
                                // 增加右侧内边距，为清除按钮留出空间
                                rightPadding: 30

                                // 左侧搜索图标置于 TextField 内部
                                Image {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 10
                                    source: "qrc:/res/chat_search.png" // 保持原资源路径 [cite: 24]
                                    width: 16; height: 16
                                    opacity: 0.5
                                }

                                // 右侧：清除按钮
                                Image {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.rightMargin: 10
                                    source: "qrc:/res/clear_search.png"
                                    width: 16; height: 16
                                    visible: searchInput.text.length > 0
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            searchInput.clear()
                                            searchResultModel.clear()
                                            searchPanel.visible = false // 点击清除时隐藏面板
                                        }
                                    }
                                }

                                // 按照要求修改输入逻辑
                                onTextChanged: {
                                    chatDialog.searchError = ""
                                    if (text.length > 0) {
                                        searchPanel.visible = true // 显式显示搜索结果面板
                                        // 防抖触发搜索请求
                                        searchDebounceTimer.restart()
                                    } else {
                                        searchPanel.visible = false // 显式隐藏搜索结果面板
                                        // 清空搜索结果，恢复联系人列表
                                        searchResultModel.clear()
                                    }
                                }
                            }
                        }

                        AddGroupBtn {
                            Layout.preferredWidth: 32; Layout.preferredHeight: 32
                        }
                    }
                }

                // 区域 3：左侧内容区多页签切换 (聊天记录 / 联系人列表)
                StackLayout {
                    id: leftContentStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: chatDialog.activeTab === "contact" ? 1
                                  : chatDialog.activeTab === "apply" ? 2 : 0

                    ListView {
                        id: chatListView
                        spacing: 6
                        topMargin: 8
                        bottomMargin: 8
                        clip: true
                        model: tcpMgr.chatStore.conversations
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: ChatUserWid {
                            required property var modelData
                            selected: tcpMgr.chatStore.activeUid === modelData.uid
                            x: 10
                            width: chatListView.width - 20
                            userName: modelData.name
                            headImg: modelData.head || ""
                            unreadCount: modelData.unread
                            lastMsg: modelData.lastMsg
                            msgTime: modelData.time
                            onClicked: chatDialog.openPeer(modelData.uid)
                        }
                    }

                    ListView {
                        id: contactListView
                        clip: true
                        model: tcpMgr.chatStore.friends
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        header: Row {
                            width: contactListView.width
                            spacing: 8
                            Label {
                                text: tcpMgr.friendSyncBusy ? qsTr("正在同步联系人…") : qsTr("联系人")
                                padding: 12
                                color: UiTheme.secondary
                            }
                            BusyIndicator {
                                width: 32
                                height: 32
                                running: tcpMgr.friendSyncBusy
                                visible: running
                            }
                        }

                        delegate: ContactItem {
                            required property var modelData
                            width: contactListView.width
                            contactName: modelData.displayName
                            // 当前 ContactItem 显示首字母，不把 URL 当作首字母传入。
                            contactHead: modelData.displayName.slice(0, 1)
                            groupLabel: ""
                            onItemClicked: function(name) {
                                chatDialog.openPeer(modelData.uid)
                            }
                        }
                    }

                    ApplyFriendPage {
                        id: applyFriendPage
                    }
                }
            }

            // ── 搜索结果覆盖层 ────────────────────────────
            // 叠加在联系人面板上方（z:3），visible 绑定输入长度
            Rectangle {
                id: searchPanel
                anchors.fill: parent
                anchors.topMargin: 48      // 搜索栏高度，不遮挡搜索框
                color: UiTheme.surface
                z: 3
                visible: false

                ListView {
                    id: searchListView
                    anchors.fill: parent
                    clip: true
                    model: searchResultModel

                    // 固定首条："添加好友"提示
                    header: Rectangle {
                        width: searchListView.width
                        height: 56
                        color: addTipMouse.containsMouse ? UiTheme.hover : UiTheme.surface
                        Behavior on color { ColorAnimation { duration: 100 } }

                        MouseArea {
                            id: addTipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // 点击顶部提示时执行查询
                                const keyword = searchInput.text.trim()
                                if (keyword.length === 0)
                                    return

                                searchDebounceTimer.stop()
                                tcpMgr.searchUser(keyword)
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Rectangle {
                                width: 36; height: 36
                                radius: 18
                                color: chatDialog.accentBlue
                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    color: UiTheme.text
                                    font.pixelSize: 22; font.bold: true
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "添加好友"
                                    font.pixelSize: 14
                                    color: UiTheme.text
                                }
                                Text {
                                    text: searchInput.text.length > 0
                                          ? "搜索 \"" + searchInput.text + "\""
                                          : ""
                                    font.pixelSize: 12
                                    color: UiTheme.muted
                                    font.family: "Microsoft YaHei"
                                }
                            }

                            Text {
                                text: "›"
                                font.pixelSize: 20
                                color: UiTheme.muted
                            }
                        }

                        // 底部分隔线
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.leftMargin: 58
                            anchors.right: parent.right
                            height: 1
                            color: UiTheme.border
                        }
                    }

                    // 搜索结果 delegate
                    delegate: Rectangle {
                        width: searchListView.width
                        height: 60
                        color: resultMouse.containsMouse ? UiTheme.hover : UiTheme.surface
                        Behavior on color { ColorAnimation { duration: 100 } }

                        MouseArea {
                            id: resultMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // 把服务器返回的用户资料传给弹窗
                                findSuccessDialog.userId = String(model.uid)
                                findSuccessDialog.userName = model.name
                                findSuccessDialog.avatarSource = model.icon || "qrc:/res/sakura-mark.png"
                                findSuccessDialog.isFriend = model.isFriend

                                findSuccessDialog.open()

                                // 所需数据已经复制到弹窗，最后再清空搜索框
                                searchInput.clear()
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            // 头像
                            Rectangle {
                                width: 40; height: 40
                                radius: 20
                                color: (model.icon !== undefined && model.icon !== "")
                                       ? "transparent" : UiTheme.cyan
                                Image {
                                    anchors.fill: parent
                                    source: (model.icon !== undefined) ? model.icon : ""
                                    visible: model.icon !== undefined && model.icon !== ""
                                    fillMode: Image.PreserveAspectCrop
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: (model.name !== undefined && model.name.length > 0)
                                          ? model.name[0].toUpperCase() : "?"
                                    color: UiTheme.text
                                    font.pixelSize: 16; font.bold: true
                                    visible: model.icon === undefined || model.icon === ""
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 3
                                Text {
                                    text: model.name !== undefined ? model.name : ""
                                    font.pixelSize: 14
                                    color: UiTheme.text
                                }
                                Text {
                                    text: model.desc !== undefined ? model.desc : ""
                                    font.pixelSize: 12
                                    color: UiTheme.muted
                                    elide: Text.ElideRight
                                    width: searchListView.width - 80
                                }
                            }
                        }

                        // 底部分隔线
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.leftMargin: 62
                            anchors.right: parent.right
                            height: 1
                            color: UiTheme.border
                        }
                    }

                    // 无结果时的空状态提示
                    footer: Item {
                        width: searchListView.width

                        visible: searchResultModel.count === 0
                                 && !tcpMgr.searchPending
                        height: visible ? 80 : 0

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 24
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap

                            text: chatDialog.searchError.length > 0
                                  ? chatDialog.searchError
                                  : "未找到相关用户"

                            color: chatDialog.searchError.length > 0
                                   ? UiTheme.danger
                                   : UiTheme.muted

                            font.pixelSize: 13
                            font.family: "Microsoft YaHei"
                        }
                    }

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                }
            }

            // 加载遮罩
            Rectangle {
                anchors.fill: searchPanel
                z: 10
                visible: searchPanel.visible && tcpMgr.searchPending
                color: UiTheme.scrim

                BusyIndicator {
                    anchors.centerIn: parent
                    running: parent.visible
                }
            }
        }

        // ═══════════════════════════════════════════════
        // 区域 5-9：主聊天区域
        // ═══════════════════════════════════════════════
        StackLayout {
            id: mainStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tcpMgr.chatStore.activeUid > 0 ? 1 : 0

            // 页面 0: 未选择聊天时的占位页
            Rectangle {
                color: UiTheme.canvas
                Text {
                    anchors.centerIn: parent
                    text: "请选择一个联系人开始聊天"
                    color: chatDialog.textSecondary
                    font.pixelSize: 16
                }
            }

            // 页面 1: 真实聊天页
            ColumnLayout {
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 8
                    visible: chatDialog.chatErrorMessage.length > 0
                    Label {
                        Layout.fillWidth: true
                        text: chatDialog.chatErrorMessage
                        textFormat: Text.PlainText
                        color: UiTheme.warning
                        wrapMode: Text.Wrap
                    }
                    ToolButton {
                        text: "×"
                        onClicked: chatDialog.chatErrorMessage = ""
                        ToolTip.text: qsTr("关闭提示")
                        ToolTip.visible: hovered
                    }
                }

                // 区域 5：顶部栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    color: UiTheme.surface

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        color: chatDialog.panelBorder
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 36; Layout.preferredHeight: 36
                            radius: 18
                            color: UiTheme.success
                            Text {
                                anchors.centerIn: parent
                                text: tcpMgr.chatStore.activeName.slice(0, 1).toUpperCase()
                                color: UiTheme.text
                                font.pixelSize: 14; font.bold: true
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Text { text: tcpMgr.chatStore.activeName; textFormat: Text.PlainText; font.pixelSize: 15; font.bold: true; color: chatDialog.textPrimary }
                            Text { text: tcpMgr.chatReady ? qsTr("已连接") : qsTr("连接已断开"); font.pixelSize: 12; color: chatDialog.accentBlue }
                        }

                        SakuraButton {
                            text: chatDialog.detailsOpen ? qsTr("收起详情") : qsTr("会话详情")
                            enabled: chatDialog.width >= 1180
                            implicitWidth: 88; implicitHeight: 32
                            onClicked: chatDialog.detailsOpen = !chatDialog.detailsOpen
                            ToolTip.visible: hovered && !enabled
                            ToolTip.text: qsTr("加宽窗口以显示详情栏")
                        }
                    }
                }

                // 区域 6：聊天记录区域
                ChatView {
                    id: chatView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    messageRows: tcpMgr.chatStore.messages
                    conversationUid: tcpMgr.chatStore.activeUid
                    conversationVisible: chatDialog.visible && chatDialog.activeTab === "chat"
                                         && Qt.application.state === Qt.ApplicationActive
                                         && !findSuccessDialog.visible && !applyFriendPopup.visible
                                         && !privacyDialog.visible && !deleteMessageDialog.visible && !retentionDialog.visible
                    hasOlder: tcpMgr.chatStore.hasOlder
                    onConversationVisibleChanged: tcpMgr.setConversationVisible(conversationVisible)
                    Component.onCompleted: tcpMgr.setConversationVisible(conversationVisible)
                    onMessageViewed: function(messageId) { tcpMgr.markMessageRead(messageId) }
                    onRetryMessage: function(msgid) { tcpMgr.retryTextMessage(conversationUid, msgid) }
                    deletionPending: tcpMgr.deletionPending
                    onDeleteMessageRequested: function(messageId, sentByMe) {
                        deleteMessageDialog.messageId = messageId
                        deleteMessageDialog.sentByMe = sentByMe
                        deleteMessageDialog.resultText = ""
                        deleteForEveryone.checked = false
                        deleteMessageDialog.open()
                    }
                    onLoadOlderRequested: tcpMgr.chatStore.loadOlder()
                }

                // 区域 7：工具栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    color: UiTheme.surface

                    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: chatDialog.panelBorder }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        spacing: 16

                        Text { text: qsTr("Enter 发送 · Shift + Enter 换行"); color: UiTheme.muted; font.pixelSize: 10 }
                        Item { Layout.fillWidth: true }
                    }
                }

                // 区域 8 + 9：输入区域 + 发送按钮
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    color: UiTheme.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Rectangle {
                            id: composerFrame
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 9
                            color: chatDialog.searchBg
                            border.width: 1
                            border.color: messageInput.activeFocus ? UiTheme.cyan : UiTheme.accent
                            Behavior on border.color { ColorAnimation { duration: 140 } }
                            Rectangle {
                                anchors.fill: parent
                                z: -1
                                radius: parent.radius; color: UiTheme.accent
                                layer.enabled: true
                                layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 16 }
                                opacity: messageInput.activeFocus ? 0.45 : 0.16
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }
                            Text {
                                anchors.left: parent.left; anchors.leftMargin: 13
                                anchors.verticalCenter: parent.verticalCenter
                                text: "›"; color: UiTheme.cyan; font.pixelSize: 28
                            }

                            ScrollView {
                                id: composerScroll
                                anchors.fill: parent
                                anchors.margins: 1
                                anchors.leftMargin: 34
                                anchors.rightMargin: 8
                                contentWidth: availableWidth
                                clip: true
                                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                TextArea {
                                    id: messageInput
                                    placeholderText: "输入消息…"
                                    placeholderTextColor: UiTheme.muted
                                    selectionColor: UiTheme.selection
                                    selectedTextColor: UiTheme.text
                                    // Only depend on the externally sized frame and font metrics.
                                    // contentHeight participates in Basic.TextArea.implicitHeight;
                                    // feeding it back into padding creates a sizing cycle.
                                    topPadding: Math.max(4, (composerFrame.height - 2 - composerMetrics.height) / 2)
                                    bottomPadding: topPadding
                                    leftPadding: 0
                                    rightPadding: 0
                                    verticalAlignment: TextEdit.AlignTop
                                    FontMetrics { id: composerMetrics; font: messageInput.font }
                                    font.pixelSize: 14
                                    color: chatDialog.textPrimary
                                    wrapMode: TextEdit.Wrap
                                    background: null

                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            if (event.modifiers & Qt.ShiftModifier) {
                                                return
                                            } else {
                                                event.accepted = true
                                                sendMessage()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        SakuraButton {
                            id: sendBtn
                            primary: true
                            text: qsTr("发送")
                            Accessible.name: text
                            Layout.preferredWidth: 106
                            Layout.fillHeight: true
                            enabled: tcpMgr.chatReady && tcpMgr.chatStore.activeCanSend && messageInput.text.trim().length > 0
                            contentItem: RowLayout {
                                spacing: 8
                                SakuraIcon { Layout.preferredWidth: 22; Layout.preferredHeight: 22; name: "send"; color: UiTheme.accentText }
                                Text { text: sendBtn.text; color: UiTheme.accentText; font.pixelSize: 14 }
                            }
                            onClicked: sendMessage()
                        }
                    }
                }
            }
        }
        ConversationInfo {
            Layout.preferredWidth: 236
            Layout.fillHeight: true
            visible: chatDialog.detailsOpen && chatDialog.width >= 1180
                     && chatDialog.activeTab === "chat"
            peerUid: tcpMgr.chatStore.activeUid
            peerName: tcpMgr.chatStore.activeName
            connected: tcpMgr.chatReady
            loadedCount: tcpMgr.chatStore.messages.length
            canSend: tcpMgr.chatStore.activeCanSend
        }
    }

    // ── 发送消息 ─────────────────────────────────────────────
    function sendMessage() {
        var id = tcpMgr.sendTextMessage(tcpMgr.chatStore.activeUid, messageInput.text)
        if (id.length > 0)
            messageInput.clear()
    }

    // ── 图片消息发送 ─────────────────────────────────────────
    function sendImageMessage(imagePath) {
        chatDialog.chatErrorMessage = qsTr("暂不支持发送图片和文件")
    }

    // ── 全局透明遮罩：点击搜索列表以外区域时隐藏搜索框 ──
    MouseArea {
        id: globalOverlay
        anchors.fill: parent
        // 当搜索输入框有内容（即搜索面板可见）时激活该遮罩
        enabled: searchInput.text.length > 0
        z: 99 // 设置高 z 值以覆盖窗口其他所有组件
        propagateComposedEvents: true // 允许鼠标事件向下穿透

        onPressed: function(mouse) {
            // 将全局点击坐标映射到搜索输入框和搜索结果面板
            var pInput = mapToItem(searchInput, mouse.x, mouse.y)
            var pPanel = mapToItem(searchPanel, mouse.x, mouse.y)

            // 判断点击是否落在输入框或面板内部
            var inInput = (pInput.x >= 0 && pInput.x <= searchInput.width &&
                           pInput.y >= 0 && pInput.y <= searchInput.height)
            var inPanel = (pPanel.x >= 0 && pPanel.x <= searchPanel.width &&
                           pPanel.y >= 0 && pPanel.y <= searchPanel.height &&
                           searchPanel.visible)

            if (!inInput && !inPanel) {
                // 如果点击在区域外，清空输入框
                // 这会自动触发 searchInput 的 onTextChanged 事件，从而隐藏列表并清空相关 Model [cite: 28, 29, 36]
                searchInput.clear()
                mouse.accepted = true // 拦截事件，避免错误触发底层聊天对象的点击
            } else {
                mouse.accepted = false // 放行事件，让输入框或搜索列表正常响应点击
            }
        }

        // 确保后续的释放和点击事件也能正常穿透给下层组件
        onReleased: function(mouse) { mouse.accepted = false }
        onClicked: function(mouse) { mouse.accepted = false }
    }

    // 好友申请填写弹窗
    ApplyFriend {
        id: applyFriendPopup

        onSubmitted: function(toUid, descs, backName) {
            tcpMgr.applyFriend(toUid, descs, backName)
        }
    }

    // 搜索结果资料弹窗
    FindSuccessDialog {
        id: findSuccessDialog
        anchors.centerIn: parent

        onApplyRequested: function(uid, name, avatar) {
            applyFriendPopup.targetUid = uid
            applyFriendPopup.targetName = name
            applyFriendPopup.targetAvatar = avatar
            applyFriendPopup.open()
        }
    }
}
