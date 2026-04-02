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
                // 原代码用 Repeater + 静态 modelData.active，点击后无法更新，
                // 互斥切换完全失效。现改为四个独立的 SidebarIconBtn，
                // isActive 绑定到顶层 activeTab 属性，点击时赋值 activeTab
                // 即可自动清除其他按钮的激活态（替代原 _lb_list 遍历逻辑）。
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

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 6

                                Image {
                                    source: "qrc:/res/chat_search.png"
                                    Layout.preferredWidth: 18; Layout.preferredHeight: 18
                                }

                                TextField {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    placeholderText: "搜索"
                                    font.pixelSize: 14
                                    color: chatDialog.textPrimary
                                    background: null
                                    onTextChanged: {
                                        if (text.length === 0) {
                                            // 清空搜索结果，恢复联系人列表
                                            searchResultModel.clear()
                                        } else {
                                            // 防抖触发搜索请求
                                            searchDebounceTimer.restart()
                                        }
                                        // 同步过滤联系人列表（联系人列表仍保留本地过滤）
                                        searchModel.filterText = text
                                    }
                                }

                                Image {
                                    source: "qrc:/res/clear_search.png"
                                    Layout.preferredWidth: 16; Layout.preferredHeight: 16
                                    visible: searchInput.text.length > 0
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            searchInput.clear()
                                            searchResultModel.clear()
                                            searchModel.filterText = ""
                                        }
                                    }
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

            // ── 修改点 2：搜索结果覆盖层 ────────────────────────────
            // 原代码完全缺失此部分，输入文字后只过滤联系人列表，
            // 没有搜索结果面板、"添加好友"提示条、用户搜索结果展示。
            // 现在叠加在联系人面板上方（z:3），visible 绑定输入长度，
            // 替代原 ShowSearch(true/false) + slot_text_changed 命令式调用。
            Rectangle {
                id: searchPanel
                anchors.fill: parent
                anchors.topMargin: 48      // 搜索栏高度，不遮挡搜索框
                color: "#f7f7f8"           // 对应原 QSS: background-color: rgb(247,247,248)
                visible: searchInput.text.length > 0
                z: 3

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
                                // 替代原 AddUserItem 点击触发添加好友流程
                                console.log("触发添加好友，搜索词：", searchInput.text)
                                // searchController.addFriend(searchInput.text)
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            // 替代原 #add_tip 图标 (border-image: url(:/res/addtip.png))
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
                                // 替代原 #message_tip 文字提示
                                Text {
                                    text: searchInput.text.length > 0
                                          ? "搜索 \"" + searchInput.text + "\""
                                          : ""
                                    font.pixelSize: 12
                                    color: "#888888"
                                    font.family: "Microsoft YaHei"
                                }
                            }

                            // 替代原 #right_tip 图标 (border-image: url(:/res/right_tip.png))
                            Text {
                                text: "›"
                                font.pixelSize: 20
                                color: "#aaaaaa"
                            }
                        }

                        // 底部分隔线（对应原 #invalid_item background-color: #eaeaea）
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.leftMargin: 58
                            anchors.right: parent.right
                            height: 1
                            color: "#eaeaea"
                        }
                    }

                    // 搜索结果 delegate（对应原 SearchList 动态追加的用户条目）
                    delegate: Rectangle {
                        width: searchListView.width
                        height: 60
                        // 对应原 QSS: item:hover → rgb(206,207,208)
                        color: resultMouse.containsMouse ? "#cecfd0" : "#f7f7f8"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        MouseArea {
                            id: resultMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                console.log("选中搜索用户：", model.name, "uid:", model.uid)
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
}
