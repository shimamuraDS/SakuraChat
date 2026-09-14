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
        Text { text: "SAKURA / DESKTOP"; color: UiTheme.cyan; font.family: "Consolas"; font.pixelSize: 12; font.letterSpacing: 1.5 }
        Item { Layout.fillHeight: true }
        Text {
            text: "连接，\n由你掌控。"
            color: UiTheme.text; font.pixelSize: 30; font.weight: Font.DemiBold; lineHeight: 1.3
        }
        Text {
            text: "让界面退后，让对话向前。"
            color: UiTheme.secondary; font.pixelSize: 13
        }
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 90
            radius: 10; color: UiTheme.field; border.color: UiTheme.border
            Column {
                anchors.fill: parent; anchors.margins: 16; spacing: 10
                Text { text: ">_ CLOUD CHAT"; color: UiTheme.cyan; font.family: "Consolas"; font.pixelSize: 12 }
                Text { text: "账户 · 联系人 · 消息"; color: UiTheme.secondary; font.pixelSize: 12 }
            }
        }
        Item { Layout.preferredHeight: 18 }
        Text {
            text: "云端聊天，不是端到端加密。"
            color: UiTheme.muted; font.pixelSize: 11
        }
    }
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: UiTheme.border }
}
