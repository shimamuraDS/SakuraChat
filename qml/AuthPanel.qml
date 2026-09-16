import QtQuick
import QtQuick.Layouts

Rectangle {
    id: panel
    color: UiTheme.rail
    clip: true
    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.strokeStyle = "#183047"; c.lineWidth = 0.5
            for (let x=24;x<width;x+=32) { c.beginPath(); c.moveTo(x,0); c.lineTo(x,height); c.stroke() }
            for (let y=16;y<height;y+=32) { c.beginPath(); c.moveTo(0,y); c.lineTo(width,y); c.stroke() }
            c.strokeStyle = "#286ba0"; c.lineWidth = 1.5
            c.beginPath(); c.moveTo(width*.14,height*.41)
            c.lineTo(width*.43,height*.21); c.lineTo(width*.81,height*.33)
            c.lineTo(width*.54,height*.36); c.lineTo(width*.7,height*.47)
            c.lineTo(width*.31,height*.41); c.stroke()
            c.strokeStyle = "#58bcdb"
            c.beginPath(); c.moveTo(width*.43,height*.21); c.lineTo(width*.51,height*.3)
            c.lineTo(width*.81,height*.33); c.stroke()
        }
    }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 28
        spacing: 16
        Text { text: "SAKURACHAT / DESKTOP"; color: UiTheme.muted; font.family: "Consolas"; font.pixelSize: 10; font.letterSpacing: 2 }
        Item { Layout.fillHeight: true }
        Text {
            text: qsTr("让距离止步。")
            Layout.fillWidth: true
            color: UiTheme.text; font.pixelSize: 32; font.weight: Font.DemiBold; font.letterSpacing: -0.5
        }
        Text {
            text: qsTr("让对话继续。")
            Layout.fillWidth: true; wrapMode: Text.Wrap
            color: UiTheme.secondary; font.pixelSize: 18
        }
        Rectangle {
            Layout.fillWidth: true; implicitHeight: modes.implicitHeight + 32
            radius: 10; color: UiTheme.field; border.color: UiTheme.border
            ColumnLayout {
                id: modes
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 16; spacing: 14
                Repeater {
                    model: [
                        { title: qsTr("默认对话"), detail: qsTr("云端保存，同步消息") },
                        { title: qsTr("局域网对话"), detail: qsTr("同网连接，无需账号") },
                        { title: qsTr("隐私对话"), detail: qsTr("Signal 协议，端到端加密") }
                    ]
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true; spacing: 4
                        Text { text: modelData.title; color: UiTheme.text; font.pixelSize: 12; font.weight: Font.Medium }
                        Text { text: modelData.detail; color: UiTheme.muted; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.Wrap }
                    }
                }
            }
        }
        Item { Layout.preferredHeight: 4 }
        Text {
            text: qsTr("默认对话非端到端加密。\n需要端到端加密时，请选择隐私对话。")
            Layout.fillWidth: true; wrapMode: Text.Wrap
            color: UiTheme.muted; font.pixelSize: 10; lineHeight: 1.4
        }
    }
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: UiTheme.border }
}
