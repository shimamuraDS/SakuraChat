import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: registerDialog
    width: 350
    height: 550
    radius: 12
    color: "#fefefe"
    border.color: "#dddddd"
    border.width: 1
    gradient: Gradient {
        GradientStop {
            position: 0.0;
            color: "#e8f0fe"
        }
        GradientStop {
            position: 1.0;
            color: "#ffffff"
        }
    }

    property bool isLoading: false

    // 切换登录界面
    signal switchLogin()

    // 错误提示缓存
    property var tipErrors: ({})
    property int currentPage: 0
    property int countdown: 5

    // 错误提示枚举
    readonly property int tipSuccess: 0
    readonly property int tipEmailErr: 1
    readonly property int tipPwdErr: 2
    readonly property int tipConfirmErr: 3
    readonly property int tipPwdConfirm: 4
    readonly property int tipVarifyErr: 5
    readonly property int tipUserErr: 6

    // 提示函数
    function showTip(message, isError = false, fromValidation = false, tipType = -1) {
        if (fromValidation) {
            // 强制字符串键，避免删除失败
            var key = String(tipType)

            if (isError) {
                tipErrors[key] = message
            } else {
                if (tipErrors.hasOwnProperty(key))
                    delete tipErrors[key]
            }

            // 显示第一个错误
            var keys = Object.keys(tipErrors)
            if (keys.length === 0) {
                errTip.text = ""
                errTip.state = "normal"
            } else {
                errTip.text = tipErrors[keys[0]]
                errTip.state = "err"
            }
        } else {
            // 非表单验证提示
            errTip.text = message
            errTip.state = isError ? "err" : "normal"
        }
    }



    // 验证用户名
    function checkUserValid() {
        if (regUsernameField.text === "") {
            showTip("用户名不能为空", true, true, tipUserErr)
            return false
        }
        showTip("", false, true, tipUserErr)
        return true
    }

    // 验证邮箱
    function checkEmailValid() {
        var emailRegex = /(\w+)(\.|_)?(\w*)@(\w+)(\.(\w+))+/
        if (!emailRegex.test(emailField.text)) {
            showTip("邮箱地址不正确", true, true, tipEmailErr)
            return false
        }
        showTip("", false, true, tipEmailErr)
        return true
    }

    // 验证密码
    function checkPassValid() {
        var pass = regPasswordField.text
        if (pass.length < 6 || pass.length > 15) {
            showTip("密码长度应为6~15", true, true, tipPwdErr)
            return false
        }
        var passRegex = /^[a-zA-Z0-9!@#$%^&*]{6,15}$/
        if (!passRegex.test(pass)) {
            showTip("不能包含非法字符", true, true, tipPwdErr)
            return false
        }
        showTip("", false, true, tipPwdErr)
        return true
    }

    // 验证确认密码
    function checkConfirmValid() {
        if (confirmPasswordField.text !== regPasswordField.text) {
            showTip("两次密码输入不一致", true, true, tipPwdConfirm)
            return false
        }
        showTip("", false, true, tipPwdConfirm)
        return true
    }

    // 验证验证码
    function checkVerifyValid() {
        if (verifyCodeField.text === "") {
            showTip("验证码不能为空", true, true, tipVarifyErr)
            return false
        }
        showTip("", false, true, tipVarifyErr)
        return true
    }

    // 切换到提示页面
    function changeTipPage() {
        countdownTimer.stop()
        currentPage = 1
        countdown = 5
        countdownTimer.start()
    }

    // 倒计时定时器
    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (countdown === 0) {
                countdownTimer.stop()
                root.switchToLogin()
                return
            }
            countdown--
        }
    }

    // 连接C++信号
    Connections {
        target: registerController

        function onVerifyCodeResult(success, message) {
            console.log("收到验证码结果信号 - 成功:", success, "消息:", message)
            showTip(message, !success)
        }

        function onRegisterResult(success, message) {
            isLoading = false;

            console.log("收到注册结果信号 - 成功:", success, "消息:", message)
            showTip(message, !success)
            if (success) {
                // 注册成功，切换登录页面
                showTip("注册成功", !success)
                registerDialog.switchLogin()
            } else {
                showTip(message || "注册失败，请重试", !success)
                console.log("Registration failed:", message);
            }
        }
    }

    // 获取验证码
    function getVerifyCode() {
        if (!checkEmailValid())
            return
        // 调用C++后端获取验证码
        registerController.getVerifyCode(emailField.text)
    }

    // 加载指示器
    BusyIndicator {
        anchors.centerIn: parent
        visible: isLoading
        running: isLoading
    }

    // 注册
    function onSureBtnClicked() {
        console.log("Sure button clicked");

        tipErrors = {}

        var valid = checkUserValid()
        if (!valid) return

        valid = checkEmailValid()
        if (!valid) return

        valid = checkPassValid()
        if (!valid) return

        valid = checkConfirmValid()
        if (!valid) return

        valid = checkVerifyValid()
        if (!valid) return

        BusyIndicator.running = true

        var username = regUsernameField.text
        var email = emailField.text
        var varifyCode = verifyCodeField.text
        var password = regPasswordField.text
        var confirmPassword = confirmPasswordField.text

        isLoading = true;

        registerController.registerUser(username, email, varifyCode, password, confirmPassword)
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12
        width: parent.width * 0.8

        // 返回
        Button {
            Layout.alignment: Qt.AlignLeft
            Layout.preferredWidth: 60
            Layout.preferredHeight: 30
            text: "<- 返回"

            background: Rectangle {
                color: "transparent"
            }

            contentItem: Text {
                text: parent.text
                font.pixelSize: 14
                color: "#666666"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                registerDialog.switchLogin()
            }
        }

        // 标题
        Text {
            Layout.fillWidth: true
            text: "用户注册"
            font.pixelSize: 22
            font.bold: true
            color: "#333333"
            horizontalAlignment: Text.AlignHCenter
        }

        // 错误提示
        Rectangle {
            id: errTipWidget
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            color: "transparent"

            Text {
                id: errTip
                anchors.centerIn: parent
                text: ""
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter

                // 状态管理
                states: [
                    State {
                        name: "normal"
                        PropertyChanges {
                            target: errTip
                            color: "#4CAF50"
                        }
                    },
                    State {
                        name: "err"
                        PropertyChanges {
                            target: errTip
                            color: "#F44336"
                        }
                    }
                ]

                transitions: [
                    Transition {
                        ColorAnimation {
                            duration: 200
                            easing.type: Easing.InOutQuad
                        }
                    }
                ]

                // 初始状态
                state: "normal"
            }
        }

        // 用户名
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            Text {
                text: "用户名"
                font.pixelSize: 14
                color: "#666666"
            }

            TextField {
                id: regUsernameField
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                placeholderText: "请输入用户名"
                font.pixelSize: 16

                background: Rectangle {
                    border.color: regUsernameField.activeFocus ? "#1DDCC1" : "#E0E0E0"
                    border.width: 1
                    radius: 5
                    color: "#FAFAFA"
                }

                onEditingFinished: checkUserValid()
            }
        }

        // 邮箱
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            Text {
                text: "邮箱"
                font.pixelSize: 14
                color: "#666666"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                TextField {
                    id: emailField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    placeholderText: "请输入邮箱"
                    font.pixelSize: 16

                    background: Rectangle {
                        border.color: emailField.activeFocus ? "#1DDCC1" : "#E0E0E0"
                        border.width: 1
                        radius: 5
                        color: "#FAFAFA"
                    }
                    onEditingFinished: checkEmailValid()
                }

                TimerButton {
                    id: timerButton
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 40
                    countdownTime: 60
                    normalText: "获取验证码"

                    onClicked: {
                        startCountdown()
                        getVerifyCode()
                    }
                }
            }
        }

        // 验证码
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            Text {
                text: "验证码"
                font.pixelSize: 14
                color: "#666666"
            }

            TextField {
                id: verifyCodeField
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                placeholderText: "请输入验证码"
                font.pixelSize: 16

                background: Rectangle {
                    border.color: verifyCodeField.activeFocus ? "#1DDCC1" : "#E0E0E0"
                    border.width: 1
                    radius: 5
                    color: "#FAFAFA"
                }
                onEditingFinished: checkVerifyValid()
            }
        }

        // 密码
        ColumnLayout {
            Layout.fillHeight: true
            spacing: 5

            Text {
                text: "密码"
                font.pixelSize: 14
                color: "#666666"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 5
                TextField {
                    id: regPasswordField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    placeholderText: "请输入密码"
                    font.pixelSize: 16
                    echoMode: passwordVisible.isSelected ? TextInput.Normal : TextInput.Password

                    background: Rectangle {
                        border.color: regPasswordField.activeFocus ? "#1DDCC1" : "#E0E0E0"
                        border.width: 1
                        radius: 5
                        color: "#FAFAFA"
                    }
                    onEditingFinished: checkPassValid()
                }

                ClickableLabel {
                    id: passwordVisible
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlighVCenter

                    Component.onCompleted: {
                        setState("qrc:/res/unvisible.png",
                                 "qrc:/res/unvisible_hover.png",
                                 "qrc:/res/visible.png",
                                 "qrc:/res/visible_hover.png")
                    }
                }
            }
        }

        // 确认密码
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            Text {
                text: "确认密码"
                font.pixelSize: 14
                color: "#666666"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 5
                TextField {
                    id: confirmPasswordField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    placeholderText: "请再次输入密码"
                    font.pixelSize: 16

                    echoMode: confirmPasswordVisible.isSelected ? TextInput.Normal : TextInput.Password

                    background: Rectangle {
                        border.color: confirmPasswordField.activeFocus ? "#1DDCC1" : "#E0E0E0"
                        border.width: 1
                        radius: 5
                        color: "#FAFAFA"
                    }
                    onEditingFinished: checkConfirmValid()
                }

                ClickableLabel {
                    id: confirmPasswordVisible
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignVCenter

                    Component.onCompleted: {
                        setState("qrc:/res/unvisible.png",
                                 "qrc:/res/unvisible_hover.png",
                                 "qrc:/res/visible.png",
                                 "qrc:/res/visible_hover.png")
                    }
                }
            }
        }

        // 注册
        Button {
            id: registerBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 45
            Layout.topMargin: 10
            text: isLoading ? "注册中..." : "注册"
            enabled: !isLoading

            background: Rectangle {
                color: registerBtn.pressed ? "#1DDCC0" : "#1DDCC1"
                radius: 5
            }

            contentItem: Text {
                text: registerBtn.text
                font.pixelSize: 16
                font.bold: true
                color: "#ffffff"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                onSureBtnClicked()
            }
        }
    }
}
