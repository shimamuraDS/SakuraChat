// ChatDialog.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: chatDialog
    width: 1000
    height: 680
    color: "#ffffff"

    // ───────────────────────────────────────────────────
    // 颜色常量（参考 Telegram 配色）
    // ───────────────────────────────────────────────────
    readonly property color sidebarBg:      "#2b5278"  // 深蓝侧边栏
    readonly property color panelBg:        "#ffffff"  // 联系人面板白底
    readonly property color panelBorder:    "#e4e4e4"  // 面板分隔线
    readonly property color searchBg:       "#f1f3f4"  // 搜索框背景
    readonly property color accentBlue:     "#2b9af3"  // Telegram 蓝
    readonly property color msgBubbleSelf:  "#effdde"  // 自己发送气泡（浅绿）
    readonly property color msgBubbleOther: "#ffffff"  // 对方消息气泡
    readonly property color textPrimary:    "#000000"
    readonly property color textSecondary:  "#707070"
    readonly property color hoverOverlay:   "#1a000000" // 悬浮遮罩

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ═══════════════════════════════════════════════
        // 区域 1：左侧图标栏（宽 60px）
        // ═══════════════════════════════════════════════
        Rectangle {
            width: 60
            Layout.fillHeight: true
            color: chatDialog.sidebarBg

            Column {
                anchors.top: parent.top
                anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                // 头像
                Rectangle {
                    width: 40; height: 40
                    radius: 20
                    color: chatDialog.accentBlue
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text {
                        anchors.centerIn: parent
                        text: "我"
                        color: "#ffffff"
                        font.pixelSize: 14
                        font.bold: true
                    }
                }

                Item { width: 1; height: 8 }

                // 侧边功能按钮列表
                Repeater {
                    model: [
                        { icon: "💬", tip: "聊天",   active: true  },
                        { icon: "👥", tip: "联系人", active: false },
                        { icon: "📞", tip: "通话",   active: false },
                        { icon: "⚙️", tip: "设置",  active: false },
                    ]
                    delegate: SidebarIconBtn {
                        icon:     modelData.icon
                        tooltip:  modelData.tip
                        isActive: modelData.active
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════
        // 区域 2-4：联系人 + 搜索面板（宽 300px）
        // ═══════════════════════════════════════════════
        Rectangle {
            width: 300
            Layout.fillHeight: true
            color: chatDialog.panelBg

            // 右侧细分隔线
            Rectangle {
                anchors.right: parent.right
                width: 1; height: parent.height
                color: chatDialog.panelBorder
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ── 区域 2：搜索栏 ──────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 56
                    color: chatDialog.panelBg

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        // 搜索输入框
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 18
                            color: chatDialog.searchBg

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 6

                                Text {
                                    text: "🔍"
                                    font.pixelSize: 14
                                    color: chatDialog.textSecondary
                                }
                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    // placeholderText: "搜索"
                                    font.pixelSize: 14
                                    color: chatDialog.textPrimary
                                    verticalAlignment: TextInput.AlignVCenter

                                    // 输入时切换到搜索结果面板
                                    onTextChanged: {
                                        contactStack.currentIndex = (text.length > 0) ? 1 : 0
                                    }
                                }
                            }
                        }

                        // 区域 2：+ 快速创建群聊按钮
                        AddGroupBtn {
                            id: addGroupBtn
                            width: 36; height: 36
                        }
                    }
                }

                // ── 区域 3 / 4：联系人列表 & 搜索结果（StackLayout 切换）──
                StackLayout {
                    id: contactStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: 0

                    // 区域 3：近期聊天列表
                    ListView {
                        id: recentList
                        clip: true
                        model: chatModel
                        delegate: ContactItem {}
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    }

                    // 区域 4：搜索结果列表
                    ListView {
                        id: searchResultList
                        clip: true
                        model: searchResultModel
                        // delegate: SearchResultItem {}
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        header: Item {
                            width: parent.width; height: 8
                        }
                        footer: Item {
                            width: parent.width; height: 8
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════
        // 区域 5-9：聊天主区域
        // ═══════════════════════════════════════════════
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ── 区域 5：顶部栏（联系人名称 + 头像）──────
            Rectangle {
                Layout.fillWidth: true
                height: 56
                color: "#ffffff"

                // 底部分隔线
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 1
                    color: chatDialog.panelBorder
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16

                    // 头像
                    Rectangle {
                        width: 36; height: 36
                        radius: 18
                        color: "#7bc67e"
                        Text {
                            anchors.centerIn: parent
                            text: "A"
                            color: "#ffffff"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }

                    // 名称 + 在线状态
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Alice"
                            font.pixelSize: 15
                            font.bold: true
                            color: chatDialog.textPrimary
                        }
                        Text {
                            text: "在线"
                            font.pixelSize: 12
                            color: chatDialog.accentBlue
                        }
                    }

                    // 右侧工具图标（搜索、更多）
                    Row {
                        spacing: 12
                        Repeater {
                            model: ["🔍", "⋮"]
                            delegate: Text {
                                text: modelData
                                font.pixelSize: 18
                                color: chatDialog.textSecondary
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }
                    }
                }
            }

            // ── 区域 6：聊天记录区域 ─────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#f0f4f8"   // Telegram 聊天背景浅蓝灰

                ListView {
                    id: messageList
                    anchors.fill: parent
                    anchors.margins: 0
                    clip: true
                    model: messageModel
                    delegate: MessageBubble {}
                    verticalLayoutDirection: ListView.BottomToTop
                    spacing: 4

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                }
            }

            // ── 区域 7：工具栏 ───────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 40
                color: "#ffffff"

                // 顶部分隔线
                Rectangle {
                    width: parent.width; height: 1
                    color: chatDialog.panelBorder
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Repeater {
                        model: ["📎", "🖼️", "😊", "📍"]
                        delegate: ToolbarBtn {
                            icon: modelData
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
            }

            // ── 区域 8 + 9：输入区域 + 发送按钮 ─────────
            Rectangle {
                Layout.fillWidth: true
                height: 52
                color: "#ffffff"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    spacing: 10

                    // 区域 8：文本输入框
                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        radius: 18
                        color: chatDialog.searchBg

                        TextInput {
                            id: messageInput
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            // placeholderText: "输入消息…"
                            font.pixelSize: 14
                            color: chatDialog.textPrimary
                            verticalAlignment: TextInput.AlignVCenter

                            Keys.onReturnPressed: sendMessage()
                        }
                    }

                    // 区域 9：发送按钮
                    // SendBtn {
                    //     id: sendBtn
                    //     width: 36; height: 36
                    //     onClicked: sendMessage()
                    // }
                }
            }
        }
    }

    // ───────────────────────────────────────────────────
    // 数据模型（示例数据，后续对接 C++ 数据源）
    // ───────────────────────────────────────────────────
    ListModel {
        id: chatModel
        ListElement { name: "Alice";   lastMsg: "好的，明天见！";  time: "14:32"; unread: 0; avatarColor: "#7bc67e" }
        ListElement { name: "Bob";     lastMsg: "文件已发送";      time: "12:10"; unread: 3; avatarColor: "#e88c8c" }
        ListElement { name: "项目群"; lastMsg: "@All 请查收周报"; time: "昨天";  unread: 12; avatarColor: "#a78bfa" }
    }

    ListModel {
        id: searchResultModel
    }

    ListModel {
        id: messageModel
        ListElement { msgText: "你好！";             isSelf: false; timeStr: "14:28" }
        ListElement { msgText: "在吗，方便说话吗？"; isSelf: false; timeStr: "14:29" }
        ListElement { msgText: "在的，什么事？";     isSelf: true;  timeStr: "14:30" }
        ListElement { msgText: "明天的会议改到下午3点了。"; isSelf: false; timeStr: "14:31" }
        ListElement { msgText: "好的，明天见！";     isSelf: true;  timeStr: "14:32" }
    }

    // ───────────────────────────────────────────────────
    // 发送消息逻辑
    // ───────────────────────────────────────────────────
    function sendMessage() {
        const text = messageInput.text.trim()
        if (text.length === 0) return
        messageModel.insert(0, {
            msgText: text,
            isSelf:  true,
            timeStr: Qt.formatTime(new Date(), "hh:mm")
        })
        messageInput.text = ""
        // TODO: 调用 C++ TcpMgr 发送至服务器
    }
}
