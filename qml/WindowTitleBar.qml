import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Rectangle {
    id: bar
    required property var window
    property string caption: "SakuraChat"
    property bool navigationVisible: false
    property string activeAction: ""
    property bool refreshAvailable: false
    property bool refreshing: false
    property bool modeSwitchVisible: false
    property string conversationMode: "default"
    signal modeRequested(string mode)
    signal utilityRequested(string action)
    implicitHeight: navigationVisible ? 64 : 44
    color: UiTheme.rail

    function toggleMaximized() {
        if (window.visibility === Window.Maximized) window.showNormal()
        else window.showMaximized()
    }
    MouseArea {
        anchors.fill: parent
        onPressed: bar.window.startSystemMove()
        onDoubleClicked: bar.toggleMaximized()
    }
    Row {
        anchors.left: parent.left; anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Rectangle {
            width: 26; height: 26; radius: 8
            color: UiTheme.selection; border.color: UiTheme.accent
            Image { anchors.fill: parent; source: "qrc:/res/sakura-mark.png"; mipmap: true; fillMode: Image.PreserveAspectFit }
        }
        Text {
            visible: !bar.modeSwitchVisible
            text: bar.caption; color: UiTheme.secondary
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, bar.width / 2 - 205)
            elide: Text.ElideRight
            font.family: "Consolas"; font.pixelSize: 12
        }
        SakuraButton {
            id: modeButton
            visible: bar.modeSwitchVisible
            text: bar.conversationMode === "lan" ? qsTr("局域网对话") : qsTr("默认对话")
            width: 154; height: 34
            anchors.verticalCenter: parent.verticalCenter
            Accessible.name: qsTr("切换对话模式：") + text
            background: Rectangle {
                radius: 9
                color: modeMenu.visible || modeButton.hovered ? UiTheme.selection : UiTheme.field
                border.color: modeMenu.visible || modeButton.activeFocus ? UiTheme.accent : UiTheme.border
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            contentItem: RowLayout {
                spacing: 8
                SakuraIcon { name: bar.conversationMode === "lan" ? "network" : "cloud"; Layout.preferredWidth: 18; Layout.preferredHeight: 18 }
                Text { text: modeButton.text; color: UiTheme.text; font.pixelSize: 12; Layout.fillWidth: true }
                Text { text: "⌄"; color: UiTheme.secondary; font.pixelSize: 16
                    rotation: modeMenu.visible ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: 140 } }
                }
            }
            onClicked: modeMenu.visible ? modeMenu.close() : modeMenu.open()
            Menu {
                id: modeMenu
                y: parent.height + 8; width: 288; padding: 8
                popupType: Popup.Item
                background: Rectangle {
                    radius: 14; color: UiTheme.surface; border.color: UiTheme.border
                    Rectangle { z: -1; x: -3; y: 4; width: parent.width + 6; height: parent.height + 3
                        radius: 17; color: "#40000000" }
                }
                enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 130 } }
                exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90 } }
                ModeOption { text: qsTr("默认对话"); detail: qsTr("云端账号 · 同步聊天"); iconName: "cloud"; modeKey: "default" }
                ModeOption { text: qsTr("局域网对话"); detail: qsTr("同一网络 · 直接加入房间"); iconName: "network"; modeKey: "lan" }
                ModeOption { text: qsTr("隐私对话"); detail: qsTr("暂未开放"); iconName: "lock"; modeKey: "private"; enabled: false }
            }
        }
    }

    component ModeOption: MenuItem {
        id: option
        property string detail
        property string iconName
        property string modeKey
        readonly property bool selectedMode: bar.conversationMode === modeKey
        implicitHeight: 66
        leftPadding: 12; rightPadding: 12
        hoverEnabled: true
        Accessible.description: detail
        background: Rectangle {
            radius: 9
            color: option.enabled && (option.highlighted || option.hovered) ? UiTheme.hover
                   : option.selectedMode ? UiTheme.selection : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        contentItem: RowLayout {
            spacing: 12
            opacity: option.enabled ? 1 : 0.45
            Rectangle {
                Layout.preferredWidth: 34; Layout.preferredHeight: 34
                radius: 9; color: option.selectedMode ? UiTheme.field : UiTheme.elevated
                SakuraIcon { anchors.centerIn: parent; width: 20; height: 20; name: option.iconName
                    color: option.selectedMode ? UiTheme.cyan : UiTheme.secondary }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 5
                Text { text: option.text; color: UiTheme.text; font.pixelSize: 13; font.weight: Font.Medium }
                Text { text: option.detail; color: UiTheme.secondary; font.pixelSize: 11 }
            }
            Text { text: option.selectedMode ? "✓" : ""; color: UiTheme.cyan; font.pixelSize: 16; Layout.preferredWidth: 16 }
        }
        onTriggered: bar.modeRequested(modeKey)
    }

    // Center against the whole window, not the space left over after the brand.
    Row {
        anchors.centerIn: parent
        visible: bar.navigationVisible
        spacing: 4
        Repeater {
            model: [{key:"privacy", icon:"settings", label:qsTr("隐私与安全")},
                    {key:"lock", icon:"lock", label:qsTr("应用锁")},
                    {key:"refresh", icon:"refresh", label:qsTr("刷新联系人")}]
            delegate: AbstractButton {
                id: actionButton
                required property var modelData
                width: 100; height: 62
                hoverEnabled: true
                enabled: modelData.key !== "refresh" || bar.refreshAvailable
                readonly property bool highlightedAction: bar.activeAction === modelData.key
                                                       || (modelData.key === "refresh" && bar.refreshing)
                opacity: enabled || highlightedAction ? 1 : 0.45
                Accessible.name: modelData.label
                background: Rectangle {
                    radius: 8
                    color: UiTheme.selection
                    opacity: actionButton.down ? 0.8 : actionButton.highlightedAction ? 0.5
                           : actionButton.hovered || actionButton.activeFocus ? 0.3 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
                contentItem: Column {
                    spacing: 4
                    topPadding: 8
                    SakuraIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 23; height: 23; name: actionButton.modelData.icon
                        color: actionButton.highlightedAction || actionButton.hovered ? UiTheme.cyan : UiTheme.secondary
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: actionButton.modelData.key === "refresh" && bar.refreshing ? qsTr("同步中…") : actionButton.modelData.label
                        color: actionButton.highlightedAction || actionButton.hovered ? UiTheme.cyan : UiTheme.secondary
                        font.pixelSize: 11
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                    width: 76; height: 2; radius: 1
                    color: UiTheme.cyan
                    opacity: actionButton.highlightedAction || actionButton.hovered || actionButton.activeFocus ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
                onClicked: bar.utilityRequested(modelData.key)
            }
        }
    }
    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: [qsTr("最小化"), qsTr("最大化 / 还原"), qsTr("关闭")]
            delegate: SakuraButton {
                id: control
                required property int index
                required property string modelData
                width: 44; height: bar.height
                Accessible.name: modelData
                ToolTip.visible: hovered; ToolTip.delay: 600; ToolTip.text: modelData
                background: Rectangle {
                    color: control.hovered ? (control.index === 2 ? UiTheme.danger : UiTheme.field) : "transparent"
                }
                contentItem: Text {
                    text: control.index === 0 ? "−" : control.index === 1
                          ? (bar.window.visibility === Window.Maximized ? "❐" : "□") : "×"
                    font.pixelSize: 20
                    color: UiTheme.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (index === 0) bar.window.showMinimized()
                    else if (index === 1) bar.toggleMaximized()
                    else bar.window.close()
                }
            }
        }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: UiTheme.border }
}
