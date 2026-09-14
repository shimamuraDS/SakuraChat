import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import SakuraChat 1.0

Popup {
    id: root
    width: 420; height: 520
    modal: true
    anchors.centerIn: parent
    padding: 0

    property int targetUid: 0
    property string targetName: ""
    property string targetAvatar: ""

    signal submitted(int toUid, string descs, string backName)

    ApplyFriendModel { id: model; Component.onCompleted: initDemoTags() }

    SakuraField {
        id: backNameField
        Layout.fillWidth: true
        placeholderText: root.targetName
        maximumLength: 64
    }

    background: Rectangle {
        radius: 12
        color: UiTheme.surface
        layer.enabled: true
        layer.effect: /* DropShadow */ null  // 可接入 Qt Graphical Effects
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // ── 标题栏 ──────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 52
            color: UiTheme.surface
            radius: 12

            Label {
                anchors.centerIn: parent
                text: "申请添加好友"
                font { pixelSize: 16; bold: true; family: "Microsoft YaHei" }
                color: UiTheme.text
            }
            // 关闭按钮
            RoundButton {
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                width: 28; height: 28
                flat: true
                text: "✕"
                font.pixelSize: 14
                contentItem: Text { text: parent.text; color: "#888"; font: parent.font
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment:   Text.AlignVCenter }
                background: Rectangle { radius: 14; color: parent.hovered ? UiTheme.canvas : "transparent" }
                onClicked: root.close()
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: UiTheme.border }

        // ── 内容区 ──────────────────────────────────────
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: root.width
                spacing: 16
                anchors.margins: 20

                // 验证消息输入框
                Label { text: "验证消息"; color: "#555"; font.pixelSize: 13 }
                Rectangle {
                    Layout.fillWidth: true; height: 72
                    radius: 8; color: UiTheme.canvas
                    border.color: msgField.activeFocus ? UiTheme.accent : UiTheme.border
                    TextArea {
                        id: msgField
                        anchors.fill: parent; anchors.margins: 8
                        placeholderText: "请输入验证消息…"
                        font.pixelSize: 13
                        wrapMode: TextArea.Wrap
                        background: Item {}
                        onTextChanged: model.setApplyMessage(text)
                    }
                }

                // 标签编辑栏
                Label { text: "设置备注标签"; color: "#555"; font.pixelSize: 13 }
                TagInputBar {
                    Layout.fillWidth: true
                    tags: model.selectedTags
                    onTagAdded:   model.addTag(tag)
                    onTagRemoved: model.removeTag(tag)
                }

                // 标签展示栏
                Label { text: "标签"; color: "#555"; font.pixelSize: 13 }
                TagGrid {
                    Layout.fillWidth: true
                    allTags: model.allTags
                    selectedTags: model.selectedTags
                    onTagToggled: model.toggleTag(tag)
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: UiTheme.border }

        // ── 底部按钮 ─────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 16
            spacing: 12

            CommonButton {
                text: "取消"
                style: "secondary"
                Layout.fillWidth: true
                onClicked: root.close()
            }

            CommonButton {
                text: "确认"
                style: "primary"
                Layout.fillWidth: true
                enabled: root.targetUid > 0 && !tcpMgr.applyPending

                onClicked: {
                    const backName = backNameField.text.trim().length > 0
                                   ? backNameField.text.trim()
                                   : root.targetName
                    root.submitted(root.targetUid, model.applyMessage, backName)
                    // 请求发出后可以关闭弹窗；最终成功与否以服务器回包为准。
                    root.close()
                }
            }
        }
    }
}
