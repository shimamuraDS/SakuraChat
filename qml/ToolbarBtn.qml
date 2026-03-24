// ToolbarBtn.qml
import QtQuick

Item {
    id: root
    width: 32; height: 32
    property string icon: ""
    signal clicked()

    property bool hovered: false

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: root.hovered ? "#f0f0f0" : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
            anchors.centerIn: parent
            text: root.icon
            font.pixelSize: 18
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered = true
        onExited:  root.hovered = false
        onClicked: root.clicked()
    }
}
