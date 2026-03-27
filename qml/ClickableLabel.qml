// ClickableLabel.qml (优化后)
import QtQuick
import QtQuick.Controls

AbstractButton {
    id: root
    width: 24; height: 24

    property string normalIcon: ""
    property string checkedIcon: ""

    checkable: true
    hoverEnabled: true

    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        // 根据选中状态和悬浮状态改变透明度或直接替换源文件
        source: root.checked ? root.checkedIcon : root.normalIcon
        opacity: root.hovered ? 0.7 : 1.0 // 替代使用 _hover 图片，极大减少资源文件数量
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }
}
