import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic

Basic.ComboBox {
    id: control
    implicitHeight: 44
    leftPadding: 14; rightPadding: 34
    background: Rectangle {
        radius: 12; color: control.hovered ? UiTheme.hover : UiTheme.field
        border.color: control.activeFocus ? UiTheme.accentHover : UiTheme.border
    }
    contentItem: Text {
        text: control.displayText; color: UiTheme.secondary; font.pixelSize: 14
        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
    }
    indicator: Text { x: control.width - 26; y: (control.height - height) / 2; text: "⌄"; color: UiTheme.cyan; font.pixelSize: 18 }
    delegate: ItemDelegate {
        width: control.width
        text: modelData
        highlighted: control.highlightedIndex === index
        background: Rectangle { radius: 8; color: parent.highlighted ? UiTheme.selection : UiTheme.surface }
    }
    popup: Popup {
        y: control.height + 5; width: control.width; padding: 6
        implicitHeight: contentItem.implicitHeight + 12
        background: Rectangle { radius: 14; color: UiTheme.surface; border.color: UiTheme.border }
        contentItem: ListView {
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex; clip: true
        }
    }
}
