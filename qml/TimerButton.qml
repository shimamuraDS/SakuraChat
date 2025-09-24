import QtQuick
import QtQuick.Controls

Button {
    id: timerButton

    property int countdownTime: 60 // 倒计时时间（秒）
    property int currentCount: 60 // 当前倒计时
    property bool isCountingDown: false
    property string normalText: "获取验证码" //正常状态文本

    text: isCountingDown ? currentCount.toString() : normalText
    enabled: !isCountingDown

    // 倒计时定时器
    Timer {
        id: countdownTimer
        interval: 1000 // 1秒
        repeat: true
        running: false

        onTriggered: {
            timerButton.currentCount--
            if (timerButton.currentCount <= 0) {
                stop()
                timerButton.isCountingDown = false
                timerButton.currentCount = timerButton.countdownTime
            }
        }
    }

    // 启动倒计时
    function startCountdown() {
        if (!isCountingDown) {
            isCountingDown = true
            currentCount = countdownTime
            countdownTimer.start()
        }
    }

    // 停止倒计时
    function stopCountdown() {
        countdownTimer.stop()
        isCountingDown = false
        currentCount = countdownTime
    }

    // 重置倒计时
    function resetCountdown() {
        stopCountdown()
    }

    // 样式
    background: Rectangle {
        color: timerButton.enabled ? "#83ECF8" : "#CCCCCC"
        radius: 5
        border.color: timerButton.enabled ? "#1DDCC1" : "#AAAAAA"
        border.width: 1

        // 悬浮
        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    contentItem: Text {
        text: timerButton.text
        font.pixelSize: 12
        color: timerButton.enabled ? "black" : "#666666"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        anchors.fill: parent

        // 文本变化
        Behavior on text {
            SequentialAnimation {
                NumberAnimation {
                    target: parent;
                    property: "opacity";
                    to: 0.7;
                    duration: 100
                }
                PropertyAction { }
                NumberAnimation {
                    target: parent;
                    property: "opacity";
                    to: 1.0;
                    duration: 100
                }
            }
        }
    }

    // 点击缩放
    scale: pressed ? 0.95 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: 100
        }
    }
}
