import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic

Basic.Dialog {
    id: control
    popupType: Popup.Item
    padding: 24
    topPadding: 12
    background: Rectangle { radius: 16; color: UiTheme.surface; border.color: UiTheme.border }
    header: Label {
        text: control.title
        visible: text.length > 0
        leftPadding: 24; rightPadding: 24; topPadding: 22; bottomPadding: 14
        font.pixelSize: 18; font.weight: Font.DemiBold; color: UiTheme.text
        wrapMode: Text.Wrap
    }
    footer: DialogButtonBox {
        visible: control.standardButtons !== Dialog.NoButton
        standardButtons: control.standardButtons
        padding: 16
        background: Item {}
        delegate: SakuraButton { }
        onAccepted: control.accept()
        onRejected: control.reject()
    }
    Overlay.modal: Rectangle { color: UiTheme.scrim; Behavior on opacity { NumberAnimation { duration: 160 } } }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
            NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: 190; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 } }
}
