// ContactItem.qml（区域 3 列表项）
import QtQuick
import QtQuick.Layouts

Rectangle {
    width: ListView.view ? ListView.view.width : 300
    height: 64
    color: hovered ? "#f5f5f5" : "transparent"
    property bool hovered: false

    Behavior on color { ColorAnimation { duration: 100 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        // 头像
        Rectangle {
            width: 44; height: 44
            radius: 22
            color: model.avatarColor

            Text {
                anchors.centerIn: parent
                text: model.name.charAt(0)
                color: "#ffffff"
                font.pixelSize: 16
                font.bold: true
            }

            // 未读角标
            Rectangle {
                visible: model.unread > 0
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -2
                anchors.rightMargin: -2
                width: 18; height: 18
                radius: 9
                color: "#2b9af3"
                Text {
                    anchors.centerIn: parent
                    text: model.unread > 99 ? "99+" : model.unread
                    color: "#ffffff"
                    font.pixelSize: 10
                    font.bold: true
                }
            }
        }

        // 名称 + 最后消息
        Column {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                width: parent.width
                Text {
                    Layout.fillWidth: true
                    text: model.name
                    font.pixelSize: 14
                    font.bold: true
                    color: "#000000"
                    elide: Text.ElideRight
                }
                Text {
                    text: model.time
                    font.pixelSize: 11
                    color: "#9e9e9e"
                }
            }

            Text {
                width: parent.width
                text: model.lastMsg
                font.pixelSize: 13
                color: "#707070"
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: parent.hovered = true
        onExited:  parent.hovered = false
    }
}
