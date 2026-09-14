// ChatUserWid.qml
import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    width: parent ? parent.width : 320
    height: 72
    radius: 10
    property bool selected: false
    color: selected ? UiTheme.selection : mouseArea.containsMouse ? UiTheme.hover : UiTheme.surface
    border.width: selected ? 1 : 0
    border.color: UiTheme.accent

    property string userName: ""
    property string headImg: ""
    property string lastMsg: ""
    property string msgTime: ""
    property int unreadCount: 0

    readonly property bool isRealImage: headImg.startsWith("qrc:/") ||
                                        headImg.startsWith("http") ||
                                        headImg.startsWith("file://")

    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }

    signal clicked()

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 12

        // 头像
        Rectangle {
            width: 48
            height: 48
            radius: 24
            color: UiTheme.selection
            clip: true
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                source: isRealImage ? headImg : ""
                fillMode: Image.PreserveAspectCrop
                visible: isRealImage
            }

            // 头像占位文字（无图时显示首字母）
            Text {
                anchors.centerIn: parent
                text: userName.length > 0 ? userName[0].toUpperCase() : "?"
                font.pixelSize: 20
                font.bold: true
                color: UiTheme.text
                visible: !isRealImage
            }
        }

        // 右侧内容区域
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            width: parent.width - 60

            Row {
                width: parent.width
                spacing: 4

                Text {
                    id: userNameLb
                    text: userName
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: UiTheme.text
                    elide: Text.ElideRight
                    width: parent.width - timeLb.width - 8
                }

                Text {
                    id: timeLb
                    text: msgTime
                    font.pixelSize: 12
                    color: UiTheme.muted
                }
            }

            Text {
                id: userChatLb
                text: lastMsg
                font.pixelSize: 12
                color: UiTheme.muted
                elide: Text.ElideRight
                width: parent.width - (root.unreadCount > 0 ? 34 : 0)
            }
        }
    }

    // 分隔线
    Rectangle {
        visible: root.unreadCount > 0
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.bottom: parent.bottom; anchors.bottomMargin: 12
        width: root.unreadCount > 99 ? 30 : 22; height: 20; radius: 10
        color: UiTheme.accent
        Text { anchors.centerIn: parent; text: root.unreadCount > 99 ? "99+" : root.unreadCount; color: UiTheme.accentText; font.pixelSize: 10 }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: 72
        anchors.right: parent.right
        height: 1
        color: UiTheme.canvas
    }
}
