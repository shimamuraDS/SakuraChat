import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SakuraChat

Rectangle {
    id: registerDialog
    radius: 0
    color: UiTheme.canvas
    border.color: UiTheme.border
    border.width: 1
    gradient: Gradient {
        GradientStop { position: 0.0; color: UiTheme.canvas }
        GradientStop { position: 1.0; color: UiTheme.surface }
    }

    property bool isLoading: false
    signal switchLogin()

    // ─────────────────────────────────────────────────────────
    // 核心逻辑区：统一的错误提示与表单校验
    // ─────────────────────────────────────────────────────────
    function showTip(message, isError = false) {
        errTip.text = message
        errTip.color = isError ? UiTheme.danger : UiTheme.success
    }

    function validateEmailOnly() {
        const emailRegex = /^[\w\.-]+@[\w\.-]+\.\w+$/
        if (!emailRegex.test(emailField.text)) {
            showTip("邮箱格式不正确", true)
            return false
        }
        showTip("", false)
        return true
    }

    function validateForm() {
        if (regUsernameField.text.trim() === "") return showTip("用户名不能为空", true) || false;

        if (!validateEmailOnly()) return false;

        if (!/^[0-9]{6}$/.test(verifyCodeField.text.trim())) return showTip("请输入六位数字验证码", true) || false;

        const pass = regPasswordField.text;
        // UTF-8 字节长度由 C++ 控制器与服务器统一校验。
        if (pass.length === 0) return showTip("密码不能为空", true) || false;

        if (confirmPasswordField.text !== pass) return showTip("两次密码输入不一致", true) || false;

        showTip("", false) // 校验通过，清空错误
        return true
    }

    // ─────────────────────────────────────────────────────────
    // 信号与控制器交互区
    // ─────────────────────────────────────────────────────────
    Connections {
        target: RegisterController

        function onVerifyCodeResult(success, message) {
            showTip(message, !success)
        }

        function onRegisterResult(success, message) {
            isLoading = false
            showTip(message || (success ? "注册成功，即将返回登录..." : "注册失败"), !success)

            if (success) {
                // 注册成功后，延迟 1.5 秒自动跳转到登录界面
                successDelayTimer.start()
            }
        }
    }

    Timer {
        id: successDelayTimer
        interval: 1500
        onTriggered: registerDialog.switchLogin()
    }

    function onSureBtnClicked() {
        if (!validateForm()) return;

        isLoading = true
        registerController.registerUser(
            regUsernameField.text,
            emailField.text,
            verifyCodeField.text,
            regPasswordField.text,
            confirmPasswordField.text
        )
    }

    function getVerifyCode() {
        if (!validateEmailOnly()) return;
        registerController.getVerifyCode(emailField.text)
        timerButton.startCountdown()
    }

    // 全局加载遮罩
    BusyIndicator {
        anchors.centerIn: parent
        visible: isLoading
        running: isLoading
        z: 99
    }

    // ─────────────────────────────────────────────────────────
    // UI 布局区
    // ─────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12
        width: parent.width * 0.8

        // 返回按钮
        SakuraButton {
            Layout.alignment: Qt.AlignLeft
            Layout.preferredWidth: 60
            Layout.preferredHeight: 30
            text: "<- 返回"
            background: Item {} // 透明背景
            contentItem: Text {
                text: parent.text
                font.pixelSize: 14
                color: parent.hovered ? UiTheme.accent : UiTheme.secondary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            onClicked: registerDialog.switchLogin()
        }

        Text {
            Layout.fillWidth: true
            text: "创建你的账号"
            font.pixelSize: 22
            font.bold: true
            color: UiTheme.text
            horizontalAlignment: Text.AlignHCenter
        }

        // 统一错误提示文本框
        Text {
            id: errTip
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            text: ""
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        // 用户名
        ColumnLayout {
            Layout.fillWidth: true; spacing: 5
            Text { text: "用户名"; font.pixelSize: 14; color: UiTheme.secondary }
            SakuraField {
                id: regUsernameField
                Layout.fillWidth: true; Layout.preferredHeight: 42
                placeholderText: "请输入用户名"; font.pixelSize: 15

            }
        }

        // 邮箱与验证码按钮
        ColumnLayout {
            Layout.fillWidth: true; spacing: 5
            Text { text: "邮箱"; font.pixelSize: 14; color: UiTheme.secondary }
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                SakuraField {
                    id: emailField
                    Layout.fillWidth: true; Layout.preferredHeight: 42
                    placeholderText: "请输入邮箱"; font.pixelSize: 15

                }
                TimerButton {
                    id: timerButton
                    Layout.preferredWidth: 90; Layout.preferredHeight: 42
                    countdownTime: 60
                    normalText: "获取验证码"
                    onClicked: getVerifyCode()
                }
            }
        }

        // 验证码输入框
        ColumnLayout {
            Layout.fillWidth: true; spacing: 5
            Text { text: "验证码"; font.pixelSize: 14; color: UiTheme.secondary }
            SakuraField {
                id: verifyCodeField
                Layout.fillWidth: true; Layout.preferredHeight: 42
                placeholderText: "请输入验证码"; font.pixelSize: 15

            }
        }

        // 密码输入框
        ColumnLayout {
            Layout.fillWidth: true; spacing: 5
            Text { text: "密码"; font.pixelSize: 14; color: UiTheme.secondary }
            RowLayout {
                Layout.fillWidth: true; spacing: 5
                SakuraField {
                    id: regPasswordField
                    Layout.fillWidth: true; Layout.preferredHeight: 42
                    placeholderText: "请输入密码"; font.pixelSize: 15
                    echoMode: passwordVisible.checked ? TextInput.Normal : TextInput.Password

                }
                ClickableLabel {
                    id: passwordVisible
                    Layout.preferredWidth: 24; Layout.preferredHeight: 24
                    normalIcon: "qrc:/res/unvisible.png"
                    checkedIcon: "qrc:/res/visible.png"
                }
            }
        }

        // 确认密码输入框
        ColumnLayout {
            Layout.fillWidth: true; spacing: 5
            Text { text: "确认密码"; font.pixelSize: 14; color: UiTheme.secondary }
            RowLayout {
                Layout.fillWidth: true; spacing: 5
                SakuraField {
                    id: confirmPasswordField
                    Layout.fillWidth: true; Layout.preferredHeight: 42
                    placeholderText: "请再次输入密码"; font.pixelSize: 15
                    echoMode: confirmPasswordVisible.checked ? TextInput.Normal : TextInput.Password

                }
                ClickableLabel {
                    id: confirmPasswordVisible
                    Layout.preferredWidth: 24; Layout.preferredHeight: 24
                    normalIcon: "qrc:/res/unvisible.png"
                    checkedIcon: "qrc:/res/visible.png"
                }
            }
        }

        // 注册按钮
        SakuraButton {
            primary: true
            id: registerBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            Layout.topMargin: 10
            text: isLoading ? "注册中..." : "注 册"
            enabled: !isLoading



            contentItem: Text {
                text: registerBtn.text
                font.pixelSize: 16
                font.bold: true
                color: UiTheme.text
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: onSureBtnClicked()
        }
    }
}
