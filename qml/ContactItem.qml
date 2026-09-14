import QtQuick
import QtQuick.Layouts

Item {
    id: root
    width: ListView.view ? ListView.view.width : 280
    height: 56

    // 对外属性
    property string contactName: ""
    property string contactHead: ""   // 头像首字母
    property string groupLabel: ""

    signal itemClicked(string name)

    // 悬浮背景
    Rectangle {
        anchors.fill: parent
        color: mouseArea.containsMouse ? UiTheme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // 底部分隔线（从头像右侧起始，与 Telegram 风格一致）
    Rectangle {
        anchors {
            left: parent.left
            leftMargin: 64
            right: parent.right
            bottom: parent.bottom
        }
        height: 1
        color: UiTheme.border
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 12
            rightMargin: 12
        }
        spacing: 12

        // 圆形头像
        Rectangle {
            width: 40; height: 40
            radius: 20
            // 根据首字母生成色相，与 ChatUserWid.qml 保持一致
            color: {
                var colors = ["#e17055","#0984e3","#00b894","#fdcb6e",
                              "#6c5ce7","#fd79a8","#55efc4","#74b9ff"];
                var idx = contactHead.length > 0
                          ? contactHead.toUpperCase().charCodeAt(0) % colors.length
                          : 0;
                return colors[idx];
            }
            Text {
                anchors.centerIn: parent
                text: contactHead.length > 0 ? contactHead[0].toUpperCase() : "?"
                color: UiTheme.text
                font { pixelSize: 16; bold: true }
            }
        }

        // 联系人姓名
        Text {
            Layout.fillWidth: true
            text: contactName
            color: UiTheme.text
            font { pixelSize: 14; family: "Microsoft YaHei" }
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.itemClicked(contactName)
    }
}
