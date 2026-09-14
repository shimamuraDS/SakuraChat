import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: chip
    property string label: ""
    property bool selected:  false
    property bool closeable: false
    signal close()
    signal clicked()

    height: 26
    width: lbl.width + (closeable ? 42 : 18)
    radius: 13
    color: selected ? UiTheme.accent : UiTheme.field
    border.color: selected ? UiTheme.accent : UiTheme.selection

    Text {
        id: lbl
        anchors { left: parent.left; leftMargin: 9; verticalCenter: parent.verticalCenter }
        text: chip.label
        color: chip.selected ? UiTheme.text : UiTheme.accent
        font.pixelSize: 12
    }

    // 关闭按钮（仅 closeable=true 时显示）
    Text {
        visible: chip.closeable
        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
        text: "×"
        color: "#888"
        font.pixelSize: 14
        MouseArea { anchors.fill: parent; onClicked: chip.close() }
    }

    MouseArea {
        anchors.fill: parent
        visible: !chip.closeable
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
