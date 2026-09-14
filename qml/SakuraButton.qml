import QtQuick
import QtQuick.Controls.Basic as Basic

Basic.Button {
    id: control
    property bool primary: false
    implicitHeight: 42
    implicitWidth: Math.max(88, implicitContentWidth + 32)
    leftPadding: 16; rightPadding: 16
    hoverEnabled: true
    font.pixelSize: 14
    opacity: enabled ? 1 : 0.45
    scale: down ? 0.98 : 1
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
    background: Rectangle {
        radius: 12
        color: control.primary ? (control.down ? UiTheme.accentPressed : control.hovered ? UiTheme.accentHover : UiTheme.accent)
                               : (control.down ? UiTheme.selection : control.hovered ? UiTheme.hover : UiTheme.field)
        border.color: control.activeFocus ? UiTheme.accent : control.primary ? "transparent" : UiTheme.border
        Behavior on color { ColorAnimation { duration: 130 } }
    }
    contentItem: Text {
        text: control.text; font: control.font
        color: control.primary ? UiTheme.accentText : UiTheme.secondary
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
