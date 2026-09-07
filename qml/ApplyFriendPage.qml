import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import SakuraChat

Item {
    id: root

    // 向其他页面公开待处理申请数量
    readonly property int pendingCount: applyModel.pendingCount

    // C++ 模型实例
    ApplyFriendList {
        id: applyModel
    }

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
                applyId: model.applyId
                applyUid: model.uid
                applyName: model.name
                applyHead: model.head
                applyMessage: model.message
                status: model.status

                onReviewClicked: function(applyId, uid, name) {
                    reviewDialog.applyId = applyId
                    reviewDialog.userName = name
                    reviewDialog.open()
                }
            }
        }
    }

    Connections {
        target: tcpMgr

        function onSig_friend_apply(application) {
            applyModel.upsertItem(application)
        }

        function onFriendApplySnapshotChanged() {
            applyModel.replaceAll(tcpMgr.friendApplySnapshot)
        }

        function onSig_friend_apply_resolved(error, result, applyId, agree) {
            if (error === 0 && result === 0)
                applyModel.setStatus(applyId, agree ? 1 : 2)
        }
    }

    Component.onCompleted: {
        // 页面可能晚于登录回包创建，必须主动读取已保存的快照。
        applyModel.replaceAll(tcpMgr.friendApplySnapshot)
    }

    ReviewFriendApplication {
        id: reviewDialog
        enabled: !tcpMgr.reviewPending
        onResolved: function(applyId, agree) {
            tcpMgr.resolveFriendApply(applyId, agree)
        }
    }
}
