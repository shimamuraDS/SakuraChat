import QtQuick
import QtQuick.Controls.Basic as Basic

Basic.CheckBox {
    id: control
    implicitHeight: Math.max(38, implicitContentHeight + 12)
    spacing: 12
    leftPadding: 0
    indicator: Rectangle {
        x: 0; y: (control.height-height)/2
        width: 20; height: 20; radius: 6
        color: control.checked ? UiTheme.accent : UiTheme.surface
        border.color: control.activeFocus ? UiTheme.accentPressed : control.checked ? UiTheme.accent : UiTheme.border
        Behavior on color { ColorAnimation { duration: 120 } }
        Text { anchors.centerIn: parent; text: "✓"; color: UiTheme.text; font.pixelSize: 14; visible: control.checked }
    }
    contentItem: Text {
        text: control.text; font.pixelSize: 13; color: UiTheme.secondary
        leftPadding: control.indicator.width + control.spacing
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
    }
}
