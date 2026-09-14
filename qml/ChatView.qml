import QtQuick
import QtQuick.Controls

Item {
    id: root
    property var messageRows: []
    property int conversationUid: 0
    property bool conversationVisible: false
    property bool hasOlder: false
    signal messageViewed(string messageId)
    signal retryMessage(string msgid)
    signal deleteMessageRequested(string messageId, bool sentByMe)
    property bool deletionPending: false
    signal loadOlderRequested()

    property int previousPeer: 0
    property string previousTail: ""
    property bool followTail: true
    property real savedY: 0
    property bool loadingOlder: false
    property real previousHeight: 0

    function stateText(status) {
        switch (status) {
        case "pending": return qsTr("发送中…")
        case "accepted": return qsTr("已发送 · 未读")
        case "delivered": return qsTr("已送达 · 未读")
        case "read": return qsTr("已读")
        case "failed": return qsTr("发送失败")
        case "unknown": return qsTr("正在确认发送结果…")
        case "forward_attempted": return qsTr("已提交，待确认")
        default: return ""
        }
    }
    function reconcileScroll() {
        const tail = messageRows.length ? messageRows[messageRows.length - 1] : null
        const key = tail ? String(tail.senderUid) + ":" + tail.msgid : ""
        if (previousPeer !== conversationUid) {
            followTail = true
            loadingOlder = false
            listView.positionViewAtEnd()
        } else if (loadingOlder) {
            listView.contentY = savedY + listView.contentHeight - previousHeight
            loadingOlder = false
        } else if (key !== previousTail && (followTail || (tail && tail.isSentByMe))) {
            listView.positionViewAtEnd()
        } else {
            listView.contentY = savedY
        }
        previousPeer = conversationUid
        previousTail = key
        savedY = listView.contentY
    }
    onMessageRowsChanged: Qt.callLater(reconcileScroll)
    onConversationUidChanged: Qt.callLater(reconcileScroll)

    ListView {
        id: listView
        anchors.fill: parent
        clip: true
        spacing: 2
        model: root.messageRows
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        onMovementEnded: {
            root.savedY = contentY
            root.followTail = atYEnd
        }
        onContentYChanged: {
            if (moving) {
                root.savedY = contentY
                root.followTail = atYEnd
            }
        }
        header: SakuraButton {
            width: listView.width
            visible: root.hasOlder
            height: visible ? implicitHeight : 0
            text: qsTr("加载更早的消息")
            onClicked: {
                root.loadingOlder = true
                root.previousHeight = listView.contentHeight
                root.savedY = listView.contentY
                root.loadOlderRequested()
            }
        }
        delegate: MessageBubble {
            id: bubble
            required property var modelData
            width: listView.width
            messageText: modelData.messageText || ""
            imageSource: ""
            isSentByMe: modelData.isSentByMe
            senderName: modelData.senderName || ""
            avatarSource: modelData.avatarSource || ""
            timestamp: modelData.timestamp || ""
            statusText: root.stateText(modelData.status)
            expiryText: modelData.expiryText || ""
            statusColor: modelData.status === "failed" ? UiTheme.danger
                         : modelData.status === "read" ? UiTheme.accent : UiTheme.muted
            retryAvailable: modelData.isSentByMe &&
                            (modelData.status === "failed" || modelData.status === "unknown")
            onRetryRequested: root.retryMessage(modelData.msgid)
            deleteAvailable: String(modelData.messageId || "").length > 0
            deleteBusy: root.deletionPending
            onDeleteRequested: root.deleteMessageRequested(String(modelData.messageId), modelData.isSentByMe)

            readonly property real viewportOverlap: Math.max(0,
                Math.min(y + height, listView.contentY + listView.height)
                - Math.max(y, listView.contentY))
            readonly property bool readable: root.conversationVisible && root.visible
                && !listView.moving && !modelData.isSentByMe && !modelData.localRead
                && String(modelData.messageId || "").length > 0
                && viewportOverlap >= Math.min(height, listView.height) * 0.8
                && listView.height > 0
            // A visible, stationary message must dwell before an account-scoped read is queued.
            Timer {
                interval: 800
                repeat: false
                running: bubble.readable
                onTriggered: {
                    if (bubble.readable)
                        root.messageViewed(String(bubble.modelData.messageId))
                }
            }
        }
    }
}
