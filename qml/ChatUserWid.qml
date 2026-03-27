// ChatUserWid.qml
import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    width: parent ? parent.width : 320
    height: 64
    color: mouseArea.containsMouse ? "#e8f4fd" : "#ffffff"

    property string userName: ""
    property string headImg: ""
    property string lastMsg: ""
    property string msgTime: ""

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
            color: "#c8e6c9"
            clip: true
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                source: headImg !== "" ? headImg : ""
                fillMode: Image.PreserveAspectCrop
                visible: headImg !== ""
            }

            // 头像占位文字（无图时显示首字母）
            Text {
                anchors.centerIn: parent
                text: userName.length > 0 ? userName[0].toUpperCase() : "?"
                font.pixelSize: 20
                font.bold: true
                color: "#ffffff"
                visible: headImg === ""
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
                    color: "#000000"
                    elide: Text.ElideRight
                    width: parent.width - timeLb.width - 8
                }

                Text {
                    id: timeLb
                    text: msgTime
                    font.pixelSize: 12
                    color: "#8c8c8c"
                    anchors.right: parent.right
                }
            }

            Text {
                id: userChatLb
                text: lastMsg
                font.pixelSize: 12
                color: "#999999"
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }

    // 分隔线
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: 72
        anchors.right: parent.right
        height: 1
        color: "#f0f0f0"
    }
}
