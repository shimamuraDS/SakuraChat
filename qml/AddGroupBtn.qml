// AddGroupBtn.qml
// 对应原教程中的 add_btn（升级为 ClickedBtn 并设置三态图片的部分）
import QtQuick

Item {
    id: root
    width: 36; height: 36
    signal clicked()

    property string btnState: "normal"  // normal | hover | press

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: {
            if (root.btnState === "press") return "#1a94e0"
            if (root.btnState === "hover") return "#2b9af3"
            return "transparent"
        }
        border.width: 1.5
        border.color: {
            if (root.btnState === "normal") return "#b0b8c1"
            return "transparent"
        }

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Text {
            anchors.centerIn: parent
            text: "+"
            font.pixelSize: 20
            font.weight: Font.Light
            color: root.btnState === "normal" ? "#707070" : "#ffffff"

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered:  root.btnState = "hover"
        onExited:   root.btnState = "normal"
        onPressed:  root.btnState = "press"
        onReleased: root.btnState = hovered ? "hover" : "normal"
        onClicked:  root.clicked()
    }
}
