import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: panel
    property int peerUid: 0
    property string peerName: ""
    property bool connected: false
    property bool canSend: false
    property int loadedCount: 0
    color: UiTheme.surface
    Rectangle { width: 1; height: parent.height; color: UiTheme.border }
    ScrollView {
        id: scroller
        anchors.fill: parent; anchors.margins: 18
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            width: scroller.availableWidth
            spacing: 18
            Text { text: "INFO / SESSION"; font.family: "Consolas"; font.pixelSize: 13; color: UiTheme.secondary }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: profile.implicitHeight + 32
                radius: 12; color: UiTheme.elevated; border.color: UiTheme.border
                ColumnLayout {
                    id: profile
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 16; spacing: 12
                    Rectangle {
                        implicitWidth: 48; implicitHeight: 48; radius: 15; color: UiTheme.selection
                        Text { anchors.centerIn: parent; text: panel.peerUid > 0 ? panel.peerName.slice(0,1).toUpperCase() : "?"; color: UiTheme.cyan; font.pixelSize: 21 }
                    }
                    Label { text: panel.peerUid > 0 ? panel.peerName : qsTr("尚未选择会话"); textFormat: Text.PlainText
                        Layout.fillWidth: true; wrapMode: Text.Wrap; color: UiTheme.text; font.pixelSize: 16; font.bold: true }
                    Label { text: panel.peerUid > 0 ? "UID / " + panel.peerUid : "—"; color: UiTheme.muted; font.family: "Consolas" }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: UiTheme.border }
                    Label { text: panel.peerUid > 0 ? qsTr("一对一云端会话") : qsTr("从列表中选择联系人")
                        Layout.fillWidth: true; wrapMode: Text.Wrap; color: UiTheme.secondary }
                }
            }
            Text { text: "CONNECTION"; font.family: "Consolas"; font.pixelSize: 12; color: UiTheme.muted }
            RowLayout {
                Rectangle { implicitWidth: 7; implicitHeight: 7; radius: 4; color: panel.connected ? UiTheme.success : UiTheme.warning }
                Label { text: panel.connected ? qsTr("客户端已连接服务器") : qsTr("客户端连接已断开")
                    Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; color: UiTheme.secondary }
            }
            Label { text: qsTr("此状态不代表对方在线。")
                Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 11; color: UiTheme.muted }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: UiTheme.border }
            Text { text: "CONVERSATION"; font.family: "Consolas"; font.pixelSize: 12; color: UiTheme.muted }
            Label { text: qsTr("当前已加载 %1 条消息").arg(panel.loadedCount)
                Layout.fillWidth: true; wrapMode: Text.Wrap; color: UiTheme.text; font.pixelSize: 13 }
            Label { text: panel.canSend ? qsTr("可以向此联系人发送消息") : qsTr("请选择可发送消息的联系人")
                Layout.fillWidth: true; wrapMode: Text.Wrap; color: UiTheme.secondary; font.pixelSize: 12 }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: help.implicitHeight + 28
                radius: 10; color: UiTheme.field
                Label {
                    id: help; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 14
                    text: qsTr("Enter 发送\nShift + Enter 换行\n右键消息打开操作菜单\n\n云端聊天不是端到端加密。")
                    wrapMode: Text.Wrap; color: UiTheme.muted; font.pixelSize: 11; lineHeight: 1.4
                }
            }
        }
    }
}
