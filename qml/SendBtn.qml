// SendBtn.qml
import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    width: 40
    height: 40

    signal clicked()

    property bool  _hovered: false
    property bool  _pressed: false

    readonly property color _bgColor: {
        if (_pressed) return "#1a8bbf"   // press 态：深蓝
        if (_hovered) return "#36b3f0"   // hover 态：浅蓝
        return "#2ca5e0"                 // normal 态：Telegram 蓝
    }

    Rectangle {
        id: bg
        anchors.centerIn: parent
        width:  parent.width
        height: parent.height
        radius: width / 2
        color: _bgColor

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        // 发送图标（使用 Unicode 箭头，无需外部图片）
        Text {
            anchors.centerIn: parent
            text: "➤"
            color: "#ffffff"
            font.pixelSize: 18
        }

        // 按下缩放动画
        transform: Scale {
            id: btnScale
            origin.x: bg.width  / 2
            origin.y: bg.height / 2
            xScale: _pressed ? 0.88 : 1.0
            yScale: _pressed ? 0.88 : 1.0
            Behavior on xScale { NumberAnimation { duration: 80 } }
            Behavior on yScale { NumberAnimation { duration: 80 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered:  root._hovered = true
        onExited:   { root._hovered = false; root._pressed = false }
        onPressed:  root._pressed = true
        onReleased: root._pressed = false
        onClicked:  root.clicked()
    }
}
