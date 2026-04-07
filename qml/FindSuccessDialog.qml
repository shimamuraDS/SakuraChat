import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Dialog {
    id: root
    title: ""
    modal: true
    anchors.centerIn: Overlay.overlay
    width: 320
    padding: 0

    // 对外属性，由 SearchList 的 itemClicked 信号传入
    property string userId: ""
    property string userName: "未知用户"
    property string avatarSource: "qrc:/static/icons/default_avatar.png"

    // ── 自定义圆角背景 ──
    background: Rectangle {
        radius: 12
        color: "#FFFFFF"
        layer.enabled: true
        layer.effect: null   // 可替换为 DropShadow
        border.color: "#E0E0E0"
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── 头部蓝色渐变区域 ──
        Rectangle {
            Layout.fillWidth: true
            height: 120
            radius: 12
            // 仅上方圆角
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: parent.height / 2
                color: parent.color
            }
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#1A73E8" }
                GradientStop { position: 1.0; color: "#0D47A1" }
            }

            // 头像
            Image {
                id: avatarImg
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -30
                width: 60; height: 60
                source: root.avatarSource
                fillMode: Image.PreserveAspectCrop
                layer.enabled: true
                // 圆形裁剪
                layer.effect: null
            }
        }

        // ── 用户信息区 ──
        Item { Layout.preferredHeight: 40 }  // 头像下方留白

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.userName
            font.pixelSize: 18
            font.bold: true
            color: "#212121"
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "ID: " + root.userId
            font.pixelSize: 13
            color: "#757575"
            topPadding: 4
        }

        // ── 操作按钮 ──
        Item { Layout.preferredHeight: 20 }

        Button {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            text: qsTr("发送消息")
            font.pixelSize: 14

            contentItem: Text {
                text: parent.text
                color: "#FFFFFF"
                font: parent.font
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                radius: 8
                color: parent.hovered ? "#1565C0" : "#1A73E8"
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            onClicked: {
                // 此处暂为界面演示，后续改为向服务器发送请求
                root.close()
            }
        }

        Item { Layout.preferredHeight: 20 }
    }
}
