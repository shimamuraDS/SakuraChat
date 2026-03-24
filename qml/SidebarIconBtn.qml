// SidebarIconBtn.qml
import QtQuick
import QtQuick.Controls

Item {
    id: root
    width: 48; height: 48

    property string icon: ""
    property string tooltip: ""
    property bool isActive: false

    // 三态：normal / hover / press
    // （对应原 ClickedBtn 的 normal / hover / press 三态）
    property string btnState: "normal"

    Rectangle {
        id: bg
        anchors.centerIn: parent
        width: 40; height: 40
        radius: 12
        color: {
            if (root.btnState === "press")  return Qt.rgba(1,1,1,0.25)
            if (root.btnState === "hover")  return Qt.rgba(1,1,1,0.15)
            if (root.isActive)              return Qt.rgba(1,1,1,0.12)
            return "transparent"
        }

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Text {
            anchors.centerIn: parent
            text: root.icon
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

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered:  root.btnState = "hover"
        onExited:   root.btnState = "normal"
        onPressed:  root.btnState = "press"
        onReleased: root.btnState = hovered ? "hover" : "normal"
        onClicked:  root.isActive = true

        ToolTip.visible: containsMouse
        ToolTip.text:    root.tooltip
        ToolTip.delay:   600
    }
}
