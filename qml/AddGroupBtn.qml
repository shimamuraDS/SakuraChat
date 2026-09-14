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
            if (root.pressed) return UiTheme.accent
            if (root.hovered) return UiTheme.accent
            return "transparent"
        }
        border.width: 1.5
        border.color: (root.pressed || root.hovered) ? "transparent" : UiTheme.muted

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Text {
            anchors.centerIn: parent
            text: "+"
            font.pixelSize: 20
            font.weight: Font.Light
            color: (root.pressed || root.hovered) ? UiTheme.text : UiTheme.secondary

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }
    }
}
