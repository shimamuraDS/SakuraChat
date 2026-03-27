// SidebarIconBtn.qml
import QtQuick
import QtQuick.Controls

AbstractButton {
    id: root
    width: 48; height: 48

    property string iconText: ""
    property string tooltip: ""
    property bool isActive: false

    hoverEnabled: true

    Rectangle {
        id: bg
        anchors.centerIn: parent
        width: 40; height: 40
        radius: 12
        color: {
            if (root.pressed)  return Qt.rgba(1,1,1,0.25)
            if (root.hovered)  return Qt.rgba(1,1,1,0.15)
            if (root.isActive)              return Qt.rgba(1,1,1,0.12)
            return "transparent"
        }

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Text {
            anchors.centerIn: parent
            text: root.iconText
            font.pixelSize: 22
        }
    }

    // 左侧激活指示条
    Rectangle {
        visible: root.isActive
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 3; height: 20
        radius: 2
        color: "#ffffff"
    }

    ToolTip.visible: hovered
    ToolTip.text: root.tooltip
    ToolTip.delay: 600

    onClicked: root.isActive = true
}
