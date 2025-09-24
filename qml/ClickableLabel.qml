import QtQuick

Item {
    id: root
    property string normalImage: ""
    property string hoverImage: ""
    property string selectedImage: ""
    property string selectedHoverImage: ""
    property bool isSelected: false

    signal clicked()

    width: 24
    height: 24

    Image {
        id: image
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit

        // 根据状态设置图片源
        source: {
            if (mouseArea.containsMouse) {
                return isSelected ? selectedHoverImage : hoverImage
            } else {
                return isSelected ? selectedImage : normalImage
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            root.isSelected = !root.isSelected
            root.clicked()
        }
    }

    // 设置状态的函数
    function setState(normal, hover, selected, selectedHover) {
        normalImage = normal || ""
        hoverImage = hover || normal || ""
        selectedImage = selected || ""
        selectedHoverImage = selectedHover || selected || ""
    }
}
