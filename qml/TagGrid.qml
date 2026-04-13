import QtQuick 2.15
import QtQuick.Layouts 1.15

Flow {
    id: root
    property var allTags: []
    property var selectedTags: []
    signal tagToggled(string tag)
    spacing: 8

    Repeater {
        model: root.allTags
        delegate: TagChip {
            label: modelData
            selected: root.selectedTags.indexOf(modelData) !== -1
            onClicked: root.tagToggled(modelData)
        }
    }
}
