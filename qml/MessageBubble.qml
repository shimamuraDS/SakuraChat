import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property string messageText: ""
    property url imageSource
    property bool isSentByMe: false
    property string senderName: ""
    property url avatarSource
    property string timestamp: ""
    property string statusText: ""
    property string expiryText: ""
    property color statusColor: UiTheme.muted
    property bool retryAvailable: false
    property bool deleteAvailable: false
    property bool deleteBusy: false
    signal retryRequested()
    signal deleteRequested()

    readonly property bool hasPicture: imageSource.toString().length > 0
    readonly property real availableBubbleWidth: Math.max(80, Math.min(460, width * 0.74))
    implicitHeight: bubble.height + 10

    Rectangle {
        id: avatar
        visible: !root.isSentByMe
        x: 16; y: 4; width: 30; height: 30; radius: 15
        color: UiTheme.selection
        Text { anchors.centerIn: parent; text: root.senderName.charAt(0).toUpperCase(); color: UiTheme.secondary; font.bold: true }
        Image {
            anchors.fill: parent; source: root.avatarSource
            fillMode: Image.PreserveAspectFit
            visible: source.toString().length > 0
        }
    }
    Rectangle {
        id: bubble
        x: root.isSentByMe ? root.width - width - 22 : 56
        y: 4
        width: Math.min(root.availableBubbleWidth,
                        Math.max(100, body.implicitWidth + 30, metadata.implicitWidth + 30))
        height: contents.implicitHeight + 22
        radius: 12
        color: root.isSentByMe ? UiTheme.selection : UiTheme.surface
        border.color: UiTheme.border
        ColumnLayout {
            id: contents
            x: 15; y: 11; width: parent.width - 30
            spacing: 5
            Text {
                visible: !root.isSentByMe
                text: root.senderName; textFormat: Text.PlainText
                font.pixelSize: 11; font.weight: Font.DemiBold; color: UiTheme.cyan
                Layout.fillWidth: true; elide: Text.ElideRight
            }
            Text {
                id: body
                visible: !root.hasPicture
                text: root.messageText; textFormat: Text.PlainText
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: 14; lineHeight: 1.2
                color: UiTheme.text
            }
            Image {
                visible: root.hasPicture
                source: root.imageSource
                Layout.preferredWidth: Math.min(260, contents.width)
                Layout.preferredHeight: sourceSize.width > 0 ? width * sourceSize.height / sourceSize.width : 120
                fillMode: Image.PreserveAspectFit
            }
            Text {
                visible: root.expiryText.length > 0
                text: root.expiryText; textFormat: Text.PlainText
                font.pixelSize: 10; color: UiTheme.muted
                Layout.fillWidth: true; wrapMode: Text.Wrap
            }
            RowLayout {
                id: metadata
                Layout.alignment: Qt.AlignRight
                spacing: 7
                Text { text: root.timestamp; color: UiTheme.muted; font.pixelSize: 10 }
                Text {
                    visible: root.isSentByMe
                    text: root.statusText; textFormat: Text.PlainText
                    color: root.statusColor; font.pixelSize: 10
                }
            }
            SakuraButton {
                visible: root.retryAvailable
                text: qsTr("重试发送")
                implicitHeight: 30
                Layout.alignment: Qt.AlignRight
                onClicked: root.retryRequested()
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: actions.popup()
        }
        Menu {
            id: actions
            MenuItem {
                text: qsTr("删除消息…")
                enabled: root.deleteAvailable && !root.deleteBusy
                onTriggered: root.deleteRequested()
            }
            MenuItem {
                text: qsTr("重试发送")
                visible: root.retryAvailable
                height: visible ? implicitHeight : 0
                onTriggered: root.retryRequested()
            }
        }
    }
}
