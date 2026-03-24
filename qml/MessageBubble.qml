// MessageBubble.qml（区域 6 消息项）
import QtQuick
import QtQuick.Layouts

Item {
    width: ListView.view ? ListView.view.width : 640
    height: bubble.height + 8

    // isSelf 为 true 时气泡靠右（自己发送），否则靠左（对方发送）
    Rectangle {
        id: bubble
        anchors.right: model.isSelf ? parent.right : undefined
        anchors.left:  model.isSelf ? undefined     : parent.left
        anchors.rightMargin:  model.isSelf ? 12 : 0
        anchors.leftMargin:   model.isSelf ? 0  : 12
        anchors.verticalCenter: parent.verticalCenter

        width: Math.min(bubbleText.implicitWidth + 24, parent.width * 0.72)
        height: bubbleText.implicitHeight + 16
        radius: 12

        // 消息气泡颜色：自己发送为浅绿（与 Telegram 一致），对方为白色
        color: model.isSelf ? "#effdde" : "#ffffff"

        // 投影
        layer.enabled: true
        layer.effect: null    // 如需投影可引入 Qt5Compat.GraphicalEffects

        Text {
            id: bubbleText
            anchors {
                left: parent.left; leftMargin: 12
                right: parent.right; rightMargin: 12
                top: parent.top; topMargin: 8
            }
            text: model.msgText
            font.pixelSize: 14
            color: "#000000"
            wrapMode: Text.WordWrap
        }

        // 时间戳
        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 8
            anchors.bottomMargin: 4
            text: model.timeStr
            font.pixelSize: 10
            color: "#9e9e9e"
        }
    }
}
