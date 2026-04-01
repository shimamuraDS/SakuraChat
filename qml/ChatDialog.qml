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

                // 头像 [cite: 5, 6, 7]
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

                // 侧边功能按钮列表 [cite: 9, 10, 11]
                Repeater {
                    model: [
                        { icon: "💬", tip: "聊天", active: true },
                        { icon: "👥", tip: "联系人", active: false },
                        { icon: "📞", tip: "通话", active: false },
                        { icon: "⚙️", tip: "设置", active: false }
                    ]
                    delegate: SidebarIconBtn {
                        iconText: modelData.icon
                        tooltip: modelData.tip
                        isActive: modelData.active
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════
        // 区域 2-4：联系人 + 搜索面板 [cite: 13, 14, 15]
        // ═══════════════════════════════════════════════
        Rectangle {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            color: chatDialog.panelBg

            // 右侧分隔线 [cite: 13, 14]
            Rectangle {
                anchors.right: parent.right
                width: 1; height: parent.height
                color: chatDialog.panelBorder
                z: 2
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // 搜索栏 [cite: 15, 16]
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
                                    background: null // 去除默认背景
                                    onTextChanged: searchModel.filterText = text // 建议后续移步 C++ 过滤
                                }

                                Image {
                                    source: "qrc:/res/clear_search.png"
                                    Layout.preferredWidth: 16; Layout.preferredHeight: 16
                                    visible: searchInput.text.length > 0
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            searchInput.clear()
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

                // 联系人列表 [cite: 31, 32]
                ChatUserList { id: chatModel }

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
                        // 警告: 下方的 visible 过滤极耗性能，建议后续由 QSortFilterProxyModel 替代 [cite: 34, 35]
                        visible: searchInput.text === "" ||
                                 model.name.toLowerCase().includes(searchInput.text.toLowerCase())
                        onClicked: {
                            console.log("点击了用户：" + model.name)
                            mainStack.currentIndex = 1 // 切换到聊天页面
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

            // 悬浮的加载遮罩 [cite: 41, 42, 43]
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
        // 区域 5-9：主聊天区域 [cite: 48, 49]
        // ═══════════════════════════════════════════════
        StackLayout {
            id: mainStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: 0 // 0: 默认空白页, 1: 真实聊天页

            // 页面 0: 尚未选择聊天时的占位页
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

                // 区域 5：顶部栏 [cite: 51, 52]
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

                // 区域 6：聊天记录区域 [cite: 77, 78]
                ChatView {
                    id: chatView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                // 区域 7：工具栏 [cite: 84, 85]
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
                        Item { Layout.fillWidth: true } // 占位把图标推到左边
                    }
                }

                // 区域 8 + 9：输入区域 + 发送按钮 [cite: 92, 93, 94]
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: "#ffffff"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        // 文本输入框 (优化为 TextArea 支持多行)
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

                                    // 捕获回车键发送，Shift+回车换行
                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            if (event.modifiers & Qt.ShiftModifier) {
                                                return; // 允许换行
                                            } else {
                                                event.accepted = true;
                                                sendMessage();
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 发送按钮 [cite: 104, 105, 106]
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

    // ── 当前会话用户信息（可由联系人点击事件更新）────────────────
    property string currentUserName: ""
    property string currentUserIcon: ""

    // ── 发送消息函数（替代原 on_send_btn_clicked 槽函数）────────
    function sendMessage() {
        var inputText = messageInput.text.trim()
        if (inputText.length === 0) return

        // 遍历输入框中的消息列表（文本 + 图片混合，与原 getMsgList() 对应）
        // 此处以纯文本发送为示例，图片发送逻辑类似
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

        // 预留 TcpMgr 发送接口（后续网络层对接）
        // tcpMgr.sendTextMessage(inputText)
    }

    // ── 图片消息发送（对应原 type == "image" 分支）───────────────
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

    // ── 接收对方消息（模拟，后续由 TcpMgr 信号触发）────────────
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
