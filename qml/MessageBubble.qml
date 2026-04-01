// MessageBubble.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    // ── 对外属性接口 ──────────────────────────────────────────
    property string messageText: ""
    property url    imageSource          // 空 url 表示文本消息
    property bool   isSentByMe: false
    property string senderName: ""
    property url    avatarSource
    property string timestamp: ""

    // ── 全局配色常量（与 ChatDialog.qml 保持一致）─────────────
    readonly property color _bubbleSelf:    "#2B5278"   // Telegram 深蓝
    readonly property color _bubbleOther:   "#FFFFFF"
    readonly property color _textSelf:      "#FFFFFF"
    readonly property color _textOther:     "#222222"
    readonly property color _nameColor:     "#5B8AC4"
    readonly property color _timeColor:     "#A0AEC0"

    readonly property bool  _isPic: imageSource.toString().length > 0

    // 气泡最大宽度：聊天区域 72%（由父级 ChatView 传入或写死）
    readonly property int   _maxBubbleWidth: 400

    implicitHeight: row.implicitHeight + 8
    width: parent ? parent.width : 600

    // ── 出现动画（替代原 paintEvent 扩展入口）────────────────
    scale: 0.85
    Component.onCompleted: appearAnim.start()
    NumberAnimation {
        id: appearAnim
        target: root
        property: "scale"
        from: 0.85; to: 1.0
        duration: 180
        easing.type: Easing.OutBack
    }

    // ── 主行布局 ──────────────────────────────────────────────
    RowLayout {
        id: row
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.margins: 8
        spacing: 8
        // 镜像方向：己方消息从右向左排列，对方从左向右排列
        layoutDirection: isSentByMe ? Qt.RightToLeft : Qt.LeftToRight

        // ── 头像（替代原 IconLabel QLabel）──────────────────
        Rectangle {
            id: avatarRect
            width: 36; height: 36
            radius: 18
            color: isSentByMe ? "#3A6EA5" : "#8EB4D8"
            Layout.alignment: Qt.AlignTop

            // 有头像路径则显示图片，否则显示首字母占位
            Image {
                anchors.fill: parent
                source: avatarSource
                fillMode: Image.PreserveAspectCrop
                visible: avatarSource.toString().length > 0
                layer.enabled: true
                layer.effect: null   // 可替换为圆形裁剪 ShaderEffect
            }
            Text {
                anchors.centerIn: parent
                text: senderName.length > 0 ? senderName[0].toUpperCase() : "?"
                color: "white"
                font.pixelSize: 15
                font.bold: true
                visible: avatarSource.toString().length === 0
            }
        }

        // ── 气泡列（名字 + 气泡体 + 时间戳）────────────────
        ColumnLayout {
            spacing: 3
            // 对方消息左对齐，己方右对齐
            Layout.alignment: isSentByMe ? Qt.AlignRight : Qt.AlignLeft

            // 发送者名称（己方消息隐藏，对应原 NameLabel）
            Text {
                id: nameLabel
                text: senderName
                visible: !isSentByMe && senderName.length > 0
                color: _nameColor
                font.pixelSize: 12
                font.bold: true
                Layout.alignment: Qt.AlignLeft
            }

            // ── 气泡体（替代原 BubbleFrame + QPainter 绘制）─
            Rectangle {
                id: bubble
                color: isSentByMe ? _bubbleSelf : _bubbleOther
                radius: 14

                // 己方：右下角不圆（Telegram 风格小尾巴通过遮罩模拟）
                // 对方：左下角不圆
                layer.enabled: true

                // 自适应宽度，最大不超过 _maxBubbleWidth
                implicitWidth:  Math.min(bubbleContent.implicitWidth  + 24, _maxBubbleWidth)
                implicitHeight: bubbleContent.implicitHeight + 16

                // Telegram 风格投影
                Rectangle {
                    anchors { fill: parent; margins: -1 }
                    radius: parent.radius + 1
                    color: "transparent"
                    border.color: Qt.rgba(0, 0, 0, 0.08)
                    border.width: 1
                    z: -1
                }

                // ── 气泡内容（文字 or 图片）──────────────────
                Item {
                    id: bubbleContent
                    anchors { fill: parent; margins: 12 }

                    // 文本消息（替代原 TextBubble + QTextEdit）
                    Text {
                        id: textMsg
                        visible: !_isPic
                        anchors.fill: parent
                        text: messageText
                        color: isSentByMe ? _textSelf : _textOther
                        font.pixelSize: 14
                        wrapMode: Text.Wrap
                        // 对应原 setPlainText 设置最大宽度
                        width: Math.min(implicitWidth, _maxBubbleWidth - 24)
                    }

                    // 图片消息（替代原 PictureBubble）
                    // 对应原 PIC_MAX_WIDTH=160, PIC_MAX_HEIGHT=90，Qt.KeepAspectRatio
                    Image {
                        id: picMsg
                        visible: _isPic
                        source: imageSource
                        fillMode: Image.PreserveAspectFit
                        // 宽高上限对应原宏定义
                        width:  Math.min(sourceSize.width,  160)
                        height: Math.min(sourceSize.height,  90)
                        // 保持宽高比（替代 Qt.KeepAspectRatio）
                        Component.onCompleted: {
                            if (sourceSize.width > 0) {
                                var ratio = sourceSize.width / sourceSize.height
                                if (sourceSize.width > 160) {
                                    width  = 160
                                    height = 160 / ratio
                                }
                                if (height > 90) {
                                    height = 90
                                    width  = 90 * ratio
                                }
                            }
                        }
                    }

                    implicitWidth:  _isPic ? picMsg.width  : textMsg.implicitWidth
                    implicitHeight: _isPic ? picMsg.height : textMsg.implicitHeight
                }
            }

            // 时间戳（替代原气泡内右下角绘制）
            Text {
                id: timeLabel
                text: timestamp
                color: _timeColor
                font.pixelSize: 11
                Layout.alignment: isSentByMe ? Qt.AlignRight : Qt.AlignLeft
            }
        }

        // 弹性占位（替代原 QSpacerItem，将气泡推向对应侧）
        Item { Layout.fillWidth: true }
    }
}
