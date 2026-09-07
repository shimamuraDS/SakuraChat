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
    readonly property color contactBg:        "#f1f2f3"
    readonly property color contactDivider:   "#ede9e7"
    readonly property color applyItemDivider: "#dbd9d9"
    readonly property color addBtnNormal:     "#d3d7d4"
    readonly property color addBtnHover:      "#D3D3D3"
    readonly property color addBtnPress:      "#BEBEBE"
    readonly property color addBtnText:       "#2cb46e"

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
            chatDialog.searchError = message + "（" + error + "）"
        }

        function onSig_friend_apply_result(error, result, applyId) {
            if (error !== 0) {
                console.warn("好友申请请求失败：", error)
            } else if (result === 0) {
                console.log("好友申请已保存，applyId =", applyId)
            } else if (result === 1) {
                console.log("双方已经是好友")
            } else {
                console.warn("好友申请未成功：", result)
            }
        }
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
                    iconText: "👤"
                    tooltipText: "好友申请"
                    isActive: chatDialog.activeTab === "apply"
                    onClicked: chatDialog.activeTab = "apply"

                    // 新增：按钮右上角的待处理数量
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 2
                        anchors.rightMargin: 2

                        width: applyFriendPage.pendingCount > 99 ? 24 : 18
                        height: 18
                        radius: 9
                        z: 10

                        color: "#ef4444"
                        visible: applyFriendPage.pendingCount > 0

                        Text {
                            anchors.centerIn: parent
                            text: applyFriendPage.pendingCount > 99
                                  ? "99+"
                                  : String(applyFriendPage.pendingCount)
                            color: "white"
                            font.pixelSize: 9
                        }
                    }
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
                    // 根据当前激活的 tab 动态切换页面
                    currentIndex: {
                            if (activeTab === "chat")    return 0;
                            if (activeTab === "contact") return 1;
                            if (activeTab === "apply")   return 2;
                            return 0;
                        }

                    // ── 页面 0: 会话列表  ──
                    ChatUserList {
                        id: chatModel
                    }
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
                            // 本地搜索过滤
                            visible: searchInput.text === "" || model.name.toLowerCase().includes(searchInput.text.toLowerCase())
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

                    // ── 页面 1: 联系人列表  ──
                    Item {
                        id: contactPage

                        // C++ 模型实例
                        ContactUserList { id: contactModel }

                        // 分组提示 + 联系人列表
                        ListView {
                            id: contactListView
                            anchors.fill: parent
                            model: contactModel
                            clip: true

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            // 分组分隔条：当当前 item 的 group 与上一条不同时显示
                            delegate: Column {
                                width: contactListView.width

                                // 分组字母标题（GroupTipItem）
                                Rectangle {
                                    width: parent.width
                                    height: model.index === 0 ||
                                            contactModel.data(contactModel.index(model.index - 1, 0),
                                                              /*GroupRole=*/Qt.UserRole + 3) !== model.group
                                            ? 28 : 0
                                    visible: height > 0
                                    color: "#eaeaea"
                                    Text {
                                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                        text: model.group
                                        color: "#2e2f30"
                                        font { pixelSize: 12; family: "Microsoft YaHei" }
                                    }
                                }

                                // 联系人条目
                                ContactItem {
                                    contactName: model.name
                                    contactHead: model.head
                                    groupLabel:  model.group
                                    onItemClicked: {
                                        // 跳转到与该联系人的聊天页
                                        mainStack.currentIndex = 1;
                                    }
                                }
                            }
                        }
                    }

                    // 页面 2：好友申请列表
                    ApplyFriendPage {
                        id: applyFriendPage
                    }

                    // 填充测试数据
                    // Component.onCompleted: {
                    //     var mockData = [
                    //         { name: "Alice",   head: "A", group: "A" },
                    //         { name: "Aria",    head: "A", group: "A" },
                    //         { name: "Bob",     head: "B", group: "B" },
                    //         { name: "Charlie", head: "C", group: "C" },
                    //         { name: "Diana",   head: "D", group: "D" },
                    //         { name: "张三",    head: "张", group: "#"  },
                    //         { name: "李四",    head: "李", group: "#"  }
                    //     ];
                    //     for (var i = 0; i < mockData.length; i++) {
                    //         contactModel.addItem(mockData[i].name,
                    //                              mockData[i].head,
                    //                              mockData[i].group);
                    //     }
                    // }
                }
            }

            // ── 搜索结果覆盖层 ────────────────────────────
            // 叠加在联系人面板上方（z:3），visible 绑定输入长度
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

                    // 固定首条："添加好友"提示
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
                                // 把服务器返回的用户资料传给弹窗
                                findSuccessDialog.userId = String(model.uid)
                                findSuccessDialog.userName = model.name
                                findSuccessDialog.avatarSource = model.icon || "qrc:/res/SakuraChat.png"
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
                                   ? "#d14343"
                                   : "#888888"

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
                color: "#80ffffff"

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
