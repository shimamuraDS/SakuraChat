import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: UiTheme.canvas
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14
        Label { text: qsTr("局域网 / LOCAL ROOM"); font.pixelSize: 24; color: UiTheme.cyan }
        Label {
            Layout.fillWidth: true; wrapMode: Text.Wrap
            text: qsTr("TLS 加密传输 · 证书指纹核验 · 邀请口令准入。房主可读取消息，并非成员间端到端加密；昵称不代表真实身份。")
            color: UiTheme.secondary
        }
        RowLayout {
            Layout.fillWidth: true
            enabled: lanChat.state === "idle"
            SakuraField { id: nickname; Layout.preferredWidth: 150; placeholderText: qsTr("房间昵称"); maximumLength: 32 }
            SakuraField { id: address; Layout.fillWidth: true; placeholderText: qsTr("房主 IPv4，例如 192.168.1.10") }
            SakuraField { id: port; Layout.preferredWidth: 85; text: "45455"; maximumLength: 5; validator: IntValidator { bottom: 1024; top: 65535 } }
            SakuraButton { text: qsTr("创建房间"); onClicked: lanChat.host(nickname.text, Number(port.text)) }
            SakuraButton { text: qsTr("加入"); onClicked: {
                    lanChat.join(nickname.text, address.text, Number(port.text), fingerprint.text, invitation.text)
                    invitation.clear()
                } }
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: lanChat.state === "hosting"
            Label { text: qsTr("通过当面或可信渠道分享以下两项；每次创建房间都会更新。不要公开发布口令。"); color: UiTheme.secondary }
            TextEdit { Layout.fillWidth: true; text: qsTr("SHA-256 指纹：") + lanChat.fingerprint
                readOnly: true; selectByMouse: true; wrapMode: TextEdit.WrapAnywhere; color: UiTheme.cyan; font.pixelSize: 12 }
            TextEdit { Layout.fillWidth: true; text: qsTr("邀请口令：") + lanChat.invitation
                readOnly: true; selectByMouse: true; color: UiTheme.secondary; font.pixelSize: 12 }
        }
        RowLayout {
            Layout.fillWidth: true; visible: lanChat.state !== "hosting"
            enabled: lanChat.state === "idle"
            SakuraField { id: fingerprint; Layout.fillWidth: true; maximumLength: 64
                placeholderText: qsTr("从房主可信渠道获取的 SHA-256 指纹（64 位）") }
            SakuraField { id: invitation; Layout.preferredWidth: 290; maximumLength: 32; echoMode: TextInput.Password
                placeholderText: qsTr("邀请口令（32 位）") }
        }
        RowLayout {
            Layout.fillWidth: true
            Label { Layout.fillWidth: true; text: lanChat.notice; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: UiTheme.secondary }
            SakuraButton { text: qsTr("离开并清空"); onClicked: lanChat.leave() }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            color: UiTheme.field; radius: 12; border.color: UiTheme.border
            ListView {
                id: history
                anchors.fill: parent; anchors.margins: 16; spacing: 12; clip: true
                model: lanChat.messages
                onCountChanged: Qt.callLater(function() { history.positionViewAtEnd() })
                ScrollBar.vertical: ScrollBar {}
                delegate: Column {
                    required property var modelData
                    width: history.width; spacing: 4
                    Label { text: modelData.name + "  ·  " + modelData.time; textFormat: Text.PlainText; color: UiTheme.cyan }
                    Label { width: parent.width; text: modelData.text; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: UiTheme.text }
                }
                Label { anchors.centerIn: parent; visible: history.count === 0; text: qsTr("房间消息会显示在这里"); color: UiTheme.muted }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            SakuraField {
                id: draft; Layout.fillWidth: true
                enabled: lanChat.state === "hosting" || lanChat.state === "joined"
                placeholderText: qsTr("输入消息，Enter 发送…"); maximumLength: 2000
                onAccepted: if (lanChat.send(text)) clear()
            }
            SakuraButton { text: qsTr("发送"); enabled: draft.enabled && draft.text.trim().length > 0
                onClicked: if (lanChat.send(draft.text)) draft.clear() }
        }
        Label { text: qsTr("仅保留本次房间最近 300 条消息；离开或关闭应用即清除。房主退出将断开所有成员。"); color: UiTheme.muted; font.pixelSize: 12 }
    }
}
