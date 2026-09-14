import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    property var tags: []
    signal tagAdded(string tag)
    signal tagRemoved(string tag)

    height: flow.height + 16
    radius: 8; color: UiTheme.canvas
    border.color: tagInput.activeFocus ? UiTheme.accent : UiTheme.border

    Flow {
        id: flow
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.margins: 8
        spacing: 6

        Repeater {
            model: root.tags
            delegate: TagChip {
                label: modelData
                closeable: true
                onClose: root.tagRemoved(modelData)
            }
        }

        SakuraField {
            id: tagInput
            width: 100; height: 28
            placeholderText: "输入标签…"
            font.pixelSize: 12
            background: Item {}
            Keys.onReturnPressed: {
                if (text.trim() !== "") {
                    root.tagAdded(text.trim())
                    text = ""
                }
            }
        }
    }
}
