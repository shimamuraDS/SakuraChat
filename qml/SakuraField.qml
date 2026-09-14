import QtQuick
import QtQuick.Controls.Basic as Basic

Basic.TextField {
    id: control
    implicitHeight: 46
    leftPadding: 14; rightPadding: 14
    color: UiTheme.text
    placeholderTextColor: UiTheme.muted
    selectionColor: UiTheme.selection
    selectedTextColor: UiTheme.text
    font.pixelSize: 14
    background: Rectangle {
        radius: 12
        color: control.activeFocus ? UiTheme.elevated : UiTheme.field
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? UiTheme.accentHover : UiTheme.border
        Behavior on border.color { ColorAnimation { duration: 140 } }
    }
}
