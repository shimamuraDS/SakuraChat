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
        radius: 14
        topLeftRadius: model.isSelf ? 14 : 4
        topRightRadius: model.isSelf ? 4 : 14
        bottomLeftRadius: 14
        bottomRightRadius: 14

        // 消息气泡颜色
        color: model.isSelf ? "#effdde" : "#ffffff"
        border.color: model.isSelf ? "transparent" : "#e4e4e4"
        border.width: model.isSelf ? 0 : 1

        // 投影
        layer.enabled: true
        layer.effect: null

        Rectangle {
            z: -1
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.bottomMargin: -1
            radius: parent.radius
            color: "#0D000000" // 极浅的黑色半透明
            visible: !model.isSelf
        }

        ColumnLayout {
            id: bubbleLayout
            anchors.centerIn: parent
            width: parent.width - 24
            spacing: 4

            // 消息文本
            Text {
                id: bubbleText
                Layout.fillWidth: true
                text: model.msgText
                font.pixelSize: 15
                color: "#222222"
                wrapMode: Text.WrapAnywhere
                lineHeight: 1.3
            }

            // 时间戳
            Text {
                id: timeText
                Layout.alignment: Qt.AlignRight
                text: model.timeStr
                font.pixelSize: 11
                // 时间戳颜色区分：浅绿背景配深绿字，白背景配灰字
                color: model.isSelf ? "#6ba770" : "#9e9e9e"
            }
        }
    }
}
