import QtQuick
import QtQuick.Controls

AbstractButton {
    id: root
    width: 36; height: 36

    hoverEnabled: true

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: {
            if (root.pressed) return "#1a94e0"
            if (root.hovered) return "#2b9af3"
            return "transparent"
        }
        border.width: 1.5
        border.color: (root.pressed || root.hovered) ? "transparent" : "#b0b8c1"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Text {
            anchors.centerIn: parent
            text: "+"
            font.pixelSize: 20
            font.weight: Font.Light
            color: (root.pressed || root.hovered) ? "#ffffff" : "#707070"

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }
    }
}
