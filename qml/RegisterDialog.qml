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

    // 样式管理
    function setTipState(tipText, isError) {
        errTip.text = tipText
        errTip.state = isError ? "err" : "normal"
    }

    // 提示信息
    function showTip(str, isError) {
        setTipState(str, isError)
    }

    // 获取验证码
    function getVerifyCode() {
        var email = emailField.text

        // 邮箱地址验证
        var emailRegex = /^(\w+)(\.|_)?(\w*)@(\w+)(\.(\w+))+$/

        if (emailRegex.test(email)) {
            // 调用C++后端获取验证码
            registerController.getVerifyCode(email)
        } else {
            showTip(qsTr("邮箱地址不正确"), true)
        }
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

        var username = regUsernameField.text
        var email = emailField.text
        var varifyCode = verifyCodeField.text
        var password = regPasswordField.text
        var confirmPassword = confirmPasswordField.text

        if (password != confirmPassword) {
            showTip(qsTr("密码不匹配"), true)
            return
        }

        if (username === "" || email === "" || varifyCode === "" || password === "") {
            showTip(qsTr("请填写完整信息"), true)
            return
        }

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
