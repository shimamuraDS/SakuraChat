// ChatDialog.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SakuraChat

Rectangle {
    id: chatDialog
    width: 1000
    height: 680
    color: "#ffffff"

    property string activeTab: "chat"

    // ───────────────────────────────────────────────────
    // 颜色常量
    // ───────────────────────────────────────────────────
    readonly property color sidebarBg:      "#2b5278"
    readonly property color panelBg:        "#ffffff"
    readonly property color panelBorder:    "#e4e4e4"
    readonly property color searchBg:       "#f1f3f4"
    readonly property color accentBlue:     "#2b9af3"
    readonly property color msgBubbleSelf:  "#effdde"
    readonly property color msgBubbleOther: "#ffffff"
    readonly property color textPrimary:    "#000000"
    readonly property color textSecondary:  "#707070"
    readonly property color hoverOverlay:   "#1a000000"

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
            if (searchInput.text.length > 0) {
                // 此处调用 C++ 搜索接口，例如：
                // searchController.searchUser(searchInput.text)
                console.log("发起用户搜索：", searchInput.text)
            }
        }
    }

    // 初始化：连接 C++ 搜索结果信号
    Component.onCompleted: {
        // 连接搜索结果信号，将 C++ 数据填充到 searchResultModel
        tcpMgr.sig_user_search.connect(function(results) {
            searchResultModel.clear()
            for (var i = 0; i < results.length; i++) {
                searchResultModel.append(results[i])
            }
        })
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ═══════════════════════════════════════════════
        // 区域 1：左侧侧边栏
        // ═══════════════════════════════════════════════
        Rectangle {
            Layout.preferredWidth: 60
            Layout.fillHeight: true
            color: chatDialog.sidebarBg

            Column {
                anchors.top: parent.top
                anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                // 头像
                Rectangle {
                    width: 40; height: 40
                    radius: 20
                    color: chatDialog.accentBlue
                    Text {
                        anchors.centerIn: parent
                        text: "我"
                        color: "#ffffff"
                        font.pixelSize: 14; font.bold: true
                    }
                }

                // ── 修改点 1：侧边栏按钮互斥选中 ──────────────────────
                // 四个独立的 SidebarIconBtn，
                // isActive 绑定到顶层 activeTab 属性，点击时赋值 activeTab
                // 即可自动清除其他按钮的激活态。
                SidebarIconBtn {
                    iconText: "💬"
                    tooltipText: "聊天"
                    isActive: chatDialog.activeTab === "chat"
                    onClicked: chatDialog.activeTab = "chat"
                }

                SidebarIconBtn {
                    iconText: "👥"
                    tooltipText: "联系人"
                    isActive: chatDialog.activeTab === "contact"
                    onClicked: chatDialog.activeTab = "contact"
                }

                SidebarIconBtn {
                    iconText: "📞"
                    tooltipText: "通话"
                    isActive: chatDialog.activeTab === "call"
                    onClicked: chatDialog.activeTab = "call"
                }

                SidebarIconBtn {
                    iconText: "⚙️"
                    tooltipText: "设置"
                    isActive: chatDialog.activeTab === "setting"
                    onClicked: chatDialog.activeTab = "setting"
                }
            }
        }

        // ═══════════════════════════════════════════════
        // 区域 2-4：联系人面板（含搜索结果覆盖层）
        // ═══════════════════════════════════════════════
        Rectangle {
            id: contactListPanel
            Layout.preferredWidth: 300
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
                    Layout.preferredHeight: 48
                    color: "#ffffff"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 4
                            color: chatDialog.searchBg

                            TextField {
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

                                // Telegram 风格：左侧搜索图标置于 TextField 内部
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
                                            searchModel.filterText = ""
                                            searchPanel.visible = false // 点击清除时隐藏面板
                                        }
                                    }
                                }

                                // 按照要求修改输入逻辑
                                onTextChanged: {
                                    if (text.length > 0) {
                                        searchPanel.visible = true // 显式显示搜索结果面板
                                        // 防抖触发搜索请求
                                        searchDebounceTimer.restart()
                                    } else {
                                        searchPanel.visible = false // 显式隐藏搜索结果面板
                                        // 清空搜索结果，恢复联系人列表
                                        searchResultModel.clear()
                                    }
                                    // 同步过滤联系人列表（联系人列表仍保留本地过滤）
                                    searchModel.filterText = text
                                }
                            }
                        }

                        AddGroupBtn {
                            Layout.preferredWidth: 32; Layout.preferredHeight: 32
                        }
                    }
                }

                // 区域 3：联系人列表
                ListView {
                    id: chatListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: chatModel
                    clip: true
                    spacing: 2

                    delegate: ChatUserWid {
                        width: chatListView.width
                        userName: model.name
                        headImg: model.head
                        lastMsg: model.lastMsg
                        msgTime: model.time
                        // 保留本地过滤，后续建议迁移至 QSortFilterProxyModel
                        visible: searchInput.text === "" ||
                                 model.name.toLowerCase().includes(searchInput.text.toLowerCase())
                        onClicked: {
                            console.log("点击了用户：" + model.name)
                            mainStack.currentIndex = 1
                        }
                    }

                    onAtYEndChanged: {
                        if (atYEnd && !chatModel.isLoading()) {
                            chatModel.loadMoreItems(10)
                        }
                    }

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                }
            }

            // ── 搜索结果覆盖层 ────────────────────────────
            // 叠加在联系人面板上方（z:3），visible 绑定输入长度，
            Rectangle {
                id: searchPanel
                anchors.fill: parent
                anchors.topMargin: 48      // 搜索栏高度，不遮挡搜索框
                color: "#f7f7f8"
                z: 3
                visible: false

                ListView {
                    id: searchListView
                    anchors.fill: parent
                    clip: true
                    model: searchResultModel

                    // 固定首条："添加好友"提示（替代原 addTipItem() 初始化的固定条目）
                    header: Rectangle {
                        width: searchListView.width
                        height: 56
                        color: addTipMouse.containsMouse ? "#cecfd0" : "#f7f7f8"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        MouseArea {
                            id: addTipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                console.log("触发添加好友，搜索词：", searchInput.text)
                                // searchController.addFriend(searchInput.text)
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
                                    color: "white"
                                    font.pixelSize: 22; font.bold: true
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "添加好友"
                                    font.pixelSize: 14
                                    color: "#000000"
                                }
                                Text {
                                    text: searchInput.text.length > 0
                                          ? "搜索 \"" + searchInput.text + "\""
                                          : ""
                                    font.pixelSize: 12
                                    color: "#888888"
                                    font.family: "Microsoft YaHei"
                                }
                            }

                            Text {
                                text: "›"
                                font.pixelSize: 20
                                color: "#aaaaaa"
                            }
                        }

                        // 底部分隔线
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.leftMargin: 58
                            anchors.right: parent.right
                            height: 1
                            color: "#eaeaea"
                        }
                    }

                    // 搜索结果 delegate
                    delegate: Rectangle {
                        width: searchListView.width
                        height: 60
                        color: resultMouse.containsMouse ? "#cecfd0" : "#f7f7f8"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        MouseArea {
                            id: resultMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                console.log("选中搜索用户：", model.name, "uid:", model.uid)

                                // 触发打开 FindSuccessDialog
                                // 假设您的弹窗有一个类似 targetUid 的属性用于接收数据
                                findSuccessDialog.targetUid = model.uid
                                findSuccessDialog.targetName = model.name // 如果需要传递用户名
                                findSuccessDialog.open() // 打开弹窗 (或者 findSuccessDialog.visible = true)

                                // 可选：点击后隐藏搜索面板
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
                                       ? "transparent" : "#54a0d5"
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
                                    color: "white"
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
                                    color: "#000000"
                                }
                                Text {
                                    text: model.desc !== undefined ? model.desc : ""
                                    font.pixelSize: 12
                                    color: "#999999"
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
                            color: "#eeeeee"
                        }
                    }

                    // 无结果时的空状态提示
                    footer: Item {
                        width: searchListView.width
                        height: searchResultModel.count === 0 ? 80 : 0
                        visible: searchResultModel.count === 0

                        Text {
                            anchors.centerIn: parent
                            text: "未找到相关用户"
                            font.pixelSize: 13
                            color: "#888888"
                            font.family: "Microsoft YaHei"
                        }
                    }

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                }
            }

            // 加载遮罩（z 值高于搜索结果面板）
            Rectangle {
                anchors.fill: parent
                color: "#80ffffff"
                visible: chatModel.isLoading()
                z: 5

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    BusyIndicator { width: 32; height: 32 }
                    Text { text: "加载中..."; color: "#8c8c8c"; font.pixelSize: 12 }
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
            currentIndex: 0

            // 页面 0: 未选择聊天时的占位页
            Rectangle {
                color: "#f0f4f8"
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

                // 区域 5：顶部栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    color: "#ffffff"

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
                            color: "#7bc67e"
                            Text {
                                anchors.centerIn: parent
                                text: "A"
                                color: "#ffffff"
                                font.pixelSize: 14; font.bold: true
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Text { text: "Alice"; font.pixelSize: 15; font.bold: true; color: chatDialog.textPrimary }
                            Text { text: "在线"; font.pixelSize: 12; color: chatDialog.accentBlue }
                        }

                        Row {
                            spacing: 16
                            Repeater {
                                model: ["🔍", "⋮"]
                                delegate: Text {
                                    text: modelData
                                    font.pixelSize: 18
                                    color: chatDialog.textSecondary
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                                }
                            }
                        }
                    }
                }

                // 区域 6：聊天记录区域
                ChatView {
                    id: chatView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                // 区域 7：工具栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: "#ffffff"

                    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: chatDialog.panelBorder }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        spacing: 16

                        Repeater {
                            model: ["📎", "🖼️", "😊", "📍"]
                            delegate: ToolbarBtn { iconText: modelData }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }

                // 区域 8 + 9：输入区域 + 发送按钮
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: "#ffffff"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8
                            color: chatDialog.searchBg

                            ScrollView {
                                anchors.fill: parent
                                anchors.margins: 4
                                TextArea {
                                    id: messageInput
                                    placeholderText: "输入消息…"
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

                        SendBtn {
                            id: sendBtn
                            Layout.preferredWidth: 36; Layout.preferredHeight: 36
                            onClicked: sendMessage()
                        }
                    }
                }
            }
        }
    }

    // ── 当前会话用户信息 ─────────────────────────────────────
    property string currentUserName: ""
    property string currentUserIcon: ""

    // ── 发送消息 ─────────────────────────────────────────────
    function sendMessage() {
        var inputText = messageInput.text.trim()
        if (inputText.length === 0) return

        var msgData = {
            "messageText":  inputText,
            "imageSource":  "",
            "isSentByMe":   true,
            "senderName":   currentUserName,
            "avatarSource": currentUserIcon,
            "timestamp":    Qt.formatTime(new Date(), "hh:mm")
        }
        chatView.appendMessage(msgData)
        messageInput.clear()
        // tcpMgr.sendTextMessage(inputText)
    }

    // ── 图片消息发送 ─────────────────────────────────────────
    function sendImageMessage(imagePath) {
        var msgData = {
            "messageText":  "",
            "imageSource":  imagePath,
            "isSentByMe":   true,
            "senderName":   currentUserName,
            "avatarSource": currentUserIcon,
            "timestamp":    Qt.formatTime(new Date(), "hh:mm")
        }
        chatView.appendMessage(msgData)
    }

    // ── 接收对方消息（后续由 TcpMgr 信号触发）──────────────
    function receiveMessage(senderName, avatarPath, text) {
        var msgData = {
            "messageText":  text,
            "imageSource":  "",
            "isSentByMe":   false,
            "senderName":   senderName,
            "avatarSource": avatarPath,
            "timestamp":    Qt.formatTime(new Date(), "hh:mm")
        }
        chatView.appendMessage(msgData)
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

    // ── 搜索成功 / 添加好友弹窗 ──────────────────────────────
    FindSuccessDialog {
        id: findSuccessDialog
        anchors.centerIn: parent

        // 预留属性供点击时赋值
        property string targetUid: ""
        property string targetName: ""

        // 您可以在这里处理弹窗内部的确认添加等逻辑
        // onAddFriendTriggered: { ... }
    }
}
