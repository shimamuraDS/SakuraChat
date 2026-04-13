import QtQuick
import QtQuick.Layouts

Item {
    id: root
    width: ListView.view ? ListView.view.width : 340
    height: 72

    // 对外属性
    property int    applyUid:     0
    property string applyName:    ""
    property string applyHead:    ""
    property string applyMessage: ""
    property bool   added:        false

    signal addClicked(int uid)

    // 条目背景
    Rectangle {
        anchors.fill: parent
        color: "#f1f2f3"
    }

    // 底部分隔线
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 2
        color: "#dbd9d9"
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 14
            rightMargin: 14
            topMargin: 10
            bottomMargin: 10
        }
        spacing: 12

        // 圆形头像
        Rectangle {
            width: 48; height: 48
            radius: 24
            color: {
                var colors = ["#e17055","#0984e3","#00b894","#fdcb6e",
                              "#6c5ce7","#fd79a8","#55efc4","#74b9ff"];
                var idx = applyHead.length > 0
                          ? applyHead.toUpperCase().charCodeAt(0) % colors.length
                          : 0;
                return colors[idx];
            }
            Text {
                anchors.centerIn: parent
                text: applyHead.length > 0 ? applyHead[0].toUpperCase() : "?"
                color: "white"
                font { pixelSize: 18; bold: true }
            }
        }

        // 用户名 + 附言
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Text {
                id: userNameLb
                Layout.fillWidth: true
                text: applyName
                color: "#000000"
                font { pixelSize: 16; family: "Microsoft YaHei" }
                elide: Text.ElideRight
            }

            Text {
                id: userChatLb
                Layout.fillWidth: true
                text: applyMessage
                color: "#a2a2a2"
                font { pixelSize: 14; family: "Microsoft YaHei" }
                elide: Text.ElideRight
            }
        }

        // 右侧：添加按钮 或 已添加文字
        Loader {
            active: true
            sourceComponent: added ? alreadyAddedComp : addBtnComp
        }
    }

    // "已添加"文字组件
    Component {
        id: alreadyAddedComp
        Text {
            text: "已添加"
            color: "#999999"
            font { pixelSize: 12; family: "Microsoft YaHei" }
        }
    }

    // "添加"按钮组件（三态）
    Component {
        id: addBtnComp
        Rectangle {
            id: addBtnRect
            width: 72; height: 36
            radius: 18
            color: {
                if (_pressed) return "#BEBEBE";
                if (_hovered) return "#D3D3D3";
                return "#d3d7d4";
            }
            Behavior on color { ColorAnimation { duration: 100 } }

            property bool _hovered: false
            property bool _pressed: false

            Text {
                anchors.centerIn: parent
                text: "添加"
                color: "#2cb46e"
                font { pixelSize: 16; family: "Microsoft YaHei" }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered:  addBtnRect._hovered = true
                onExited:   { addBtnRect._hovered = false; addBtnRect._pressed = false }
                onPressed:  addBtnRect._pressed = true
                onReleased: addBtnRect._pressed = false
                onClicked:  root.addClicked(applyUid)
            }
        }
    }
}
