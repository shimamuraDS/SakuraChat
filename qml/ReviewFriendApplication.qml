import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    modal: true
    anchors.centerIn: Overlay.overlay
    title: "好友申请"

    property var applyId: 0
    property string userName: ""
    signal resolved(var applyId, bool agree)

    ColumnLayout {
        anchors.fill: parent
        Label { text: "是否同意 " + root.userName + " 的好友申请？" }
        DialogButtonBox {
            standardButtons: DialogButtonBox.Yes | DialogButtonBox.No
            onAccepted: {
                root.resolved(root.applyId, true)
                root.close()
            }
            onRejected: {
                root.resolved(root.applyId, false)
                root.close()
            }
        }
    }
}
