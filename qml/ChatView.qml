// ChatView.qml
import QtQuick
import QtQuick.Controls

Item {
    id: root

    // ── 对外接口（替代原 appendChatItem / prependChatItem）──
    function appendMessage(msgData) {
        chatModel.append(msgData)
        // 自动滚动到底部（替代原 onVScrollBarMoved 槽函数）
        Qt.callLater(() => listView.positionViewAtEnd())
    }

    function prependMessage(msgData) {
        chatModel.insert(0, msgData)
    }

    // ── 消息数据源（替代原手动管理的子 Widget 指针列表）────
    ListModel { id: chatModel }

    // ── 消息列表（替代原 QScrollArea + QVBoxLayout 四层嵌套）
    ListView {
        id: listView
        anchors.fill: parent
        model: chatModel
        spacing: 4
        clip: true

        // 底部留白（替代原 stretch 比例 100000 的空白 QWidget）
        footer: Item { height: 4 }

        // 滚动条（替代原浮动 QHBoxLayout + 自定义 QScrollBar）
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            // Telegram 风格：细圆角滑块
            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: Qt.rgba(0, 0, 0, 0.25)
            }
        }

        // ── 气泡 delegate ────────────────────────────────────
        delegate: MessageBubble {
            width: listView.width
            messageText:  model.messageText  ?? ""
            imageSource:  model.imageSource  ?? ""
            isSentByMe:   model.isSentByMe   ?? false
            senderName:   model.senderName   ?? ""
            avatarSource: model.avatarSource ?? ""
            timestamp:    model.timestamp    ?? ""
        }
    }
}
