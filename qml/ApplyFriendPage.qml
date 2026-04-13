import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    // C++ 模型实例
    ApplyFriendList { id: applyModel }

    // 整体背景
    Rectangle {
        anchors.fill: parent
        color: "#f1f2f3"
        border { width: 1; color: "#ede9e7" }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── 标题栏 ──────────────────────────────────────────
        Rectangle {
            id: headerWid
            Layout.fillWidth: true
            height: 52
            color: "#f1f2f3"

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                color: "#ede9e7"
            }

            Text {
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                text: "新的朋友"
                color: "#000000"
                font { pixelSize: 18; family: "Microsoft YaHei"; weight: Font.Normal }
            }
        }

        // ── 申请列表 ─────────────────────────────────────────
        ListView {
            id: applyListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: applyModel
            clip: true
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: ApplyFriendItem {
                applyUid:     model.uid
                applyName:    model.name
                applyHead:    model.head
                applyMessage: model.message
                added:        model.isAdded
                onAddClicked: (uid) => {
                    applyModel.setAdded(uid);
                    // TODO: 对接网络层，发送添加好友请求
                }
            }
        }
    }

    // 填充测试数据
    Component.onCompleted: {
        applyModel.addItem(1001, "Alice",  "A", "你好，我是 Alice！");
        applyModel.addItem(1002, "Bob",    "B", "我们一起学习吧");
        applyModel.addItem(1003, "Charlie","C", "来自共同好友的介绍");
        applyModel.addItem(1004, "张三",   "张","很高兴认识你");
    }
}
