import QtQuick
import QtQuick.Controls

AbstractButton {
    id: root
    width: 48
    height: 48

    // ---- 对外属性 ----
    property string iconText: ""
    property string tooltipText: ""
    property bool isActive: false

    hoverEnabled: true

    // 1. 左侧激活指示条（带动画）
    Rectangle {
        id: activeIndicator
        width: 3
        height: 24
        radius: 1.5
        color: "white"
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        opacity: root.isActive ? 1.0 : 0.0
        // 缩放动画会让指示条出现得更自然（可选）
        scale: root.isActive ? 1.0 : 0.5
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
    }

    // 2. 按钮背景（使用清晰的 if-else 逻辑）
    Rectangle {
        id: bg
        anchors.centerIn: parent
        width: 40
        height: 40
        radius: 10
        color: {
            if (root.pressed) return Qt.rgba(1, 1, 1, 0.25)
            if (root.hovered) return Qt.rgba(1, 1, 1, 0.15)
            if (root.isActive) return Qt.rgba(1, 1, 1, 0.2)
            return "transparent"
        }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // 3. 图标文字（使用 contentItem 承载，带有颜色动画）
    contentItem: Text {
        text: root.iconText
        font.pixelSize: 20
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: root.isActive ? "white" : Qt.rgba(1, 1, 1, 0.75)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // 4. 悬浮提示（严谨判断）
    ToolTip.visible: root.hovered && root.tooltipText.length > 0
    ToolTip.text: root.tooltipText
    ToolTip.delay: 600
}
