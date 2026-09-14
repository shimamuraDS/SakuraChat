import QtQuick
import QtQuick.Controls
import QtQuick.Effects

AbstractButton {
    id: root
    width: 72
    height: 56

    // ---- 对外属性 ----
    property string iconText: ""
    property string tooltipText: ""
    property bool isActive: false
    property int badgeCount: 0

    hoverEnabled: true

    // 1. 左侧激活指示条（带动画）
    Rectangle {
        id: activeIndicator
        width: 3
        height: 42
        radius: 1
        color: UiTheme.cyan
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        opacity: root.isActive ? 1.0 : 0.0
        // 缩放动画会让指示条出现得更自然（可选）
        scale: root.isActive ? 1.0 : 0.5
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        layer.enabled: root.isActive
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: UiTheme.cyan
            shadowBlur: 1
            shadowOpacity: 0.85
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: 12
        }
    }

    // 2. 按钮背景（使用清晰的 if-else 逻辑）
    Rectangle {
        id: bg
        anchors.centerIn: parent
        width: 36
        height: 32
        radius: 16
        color: {
            return UiTheme.accent
        }
        opacity: root.pressed ? 0.55 : root.isActive ? 0.4 : root.hovered ? 0.2 : 0
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 24 }
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // 3. 图标文字（使用 contentItem 承载，带有颜色动画）
    contentItem: Item {
        SakuraIcon {
            anchors.centerIn: parent
            width: 24; height: 24
            name: root.iconText
            color: root.isActive || root.hovered ? UiTheme.cyan : UiTheme.secondary
            Behavior on color { ColorAnimation { duration: 120 } }
            layer.enabled: root.isActive
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: UiTheme.accent
                shadowBlur: 1; shadowOpacity: 0.7
                shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 12
            }
        }
    }
    Rectangle {
        visible: root.badgeCount > 0
        anchors.right: parent.right; anchors.rightMargin: 9
        anchors.top: parent.top; anchors.topMargin: 3
        width: root.badgeCount > 99 ? 26 : 18; height: 18; radius: 9
        color: UiTheme.accent
        Text { anchors.centerIn: parent; text: root.badgeCount > 99 ? "99+" : root.badgeCount; color: UiTheme.accentText; font.pixelSize: 9 }
    }

    // 4. 悬浮提示（严谨判断）
    ToolTip.visible: root.hovered && root.tooltipText.length > 0
    ToolTip.text: root.tooltipText
    ToolTip.delay: 600
}
