// ToolbarBtn.qml
import QtQuick
import QtQuick.Controls

AbstractButton {
    id: root
    width: 32; height: 32
    property string iconText: ""

    hoverEnabled: true

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: root.hovered ? UiTheme.canvas : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
            anchors.centerIn: parent
            text: root.iconText
            font.pixelSize: 18
        }
    }
}
