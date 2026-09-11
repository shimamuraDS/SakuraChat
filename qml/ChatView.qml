import QtQuick
import QtQuick.Controls

Item {
    id: root
    property var messageRows: []

    function stateText(status) {
        switch (status) {
        case "pending": return "等待服务器响应"
        case "forward_attempted": return "服务器已尝试转发"
        case "failed": return "处理失败"
        case "unknown": return "结果未知"
        default: return ""
        }
    }

    onMessageRowsChanged: {
        Qt.callLater(function() { listView.positionViewAtEnd() })
    }

    ListView {
        id: listView
        anchors.fill: parent
        clip: true
        spacing: 4
        model: root.messageRows
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: MessageBubble {
            required property var modelData
            width: listView.width
            messageText: modelData.messageText
            imageSource: ""
            isSentByMe: modelData.isSentByMe
            senderName: modelData.senderName
            avatarSource: modelData.avatarSource || ""
            timestamp: modelData.timestamp
                       + (modelData.isSentByMe
                          ? " · " + root.stateText(modelData.status) : "")
        }
    }
}
