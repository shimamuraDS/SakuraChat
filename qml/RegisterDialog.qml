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

    // 切换登录界面
    signal switchLogin()

    // 连接C++信号
    Connections {
        target: registerControll

        function onVerifyCodeResult(success, message) {
            showTip(message, !success)
        }

        function onRegisterResult(success, message) {
            showTip(message, !success)
            if (success) {
                // 注册成功，切换登录页面
                registerDialog.switchLogin()
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

    // 注册
    function doRegister() {
        var username = regUsernameField.text
        var email = emailField.text
        var verifyCode = verifyCodeField.text
        var password = regPasswordField.text
        var confirmPassword = confirmPasswordField.text

        if (password != confirmPassword) {
            showTip(qsTr("密码不匹配"), true)
            return
        }

        if (username == "" || email == "" || verifyCode == "" || password == "") {
            showTip(qsTr("请填写完整信息"), true)
            return
        }

        registerController.registerUser(username, email, verifyCode, password)
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

                Button {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 40
                    text: "获取验证码"

                    background: Rectangle {
                        color: parent.pressed ? "#1DDCC0" : "#1DDCC1"
                        radius: 5
                    }

                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 12
                        color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
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

            TextField {
                id: regPasswordField
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                placeholderText: "请输入密码"
                font.pixelSize: 16

                echoMode: TextInput.Password

                background: Rectangle {
                    border.color: regPasswordField.activeFocus ? "#1DDCC1" : "#E0E0E0"
                    border.width: 1
                    radius: 5
                    color: "#FAFAFA"
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

            TextField {
                id: confirmPasswordField
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                placeholderText: "请再次输入密码"
                font.pixelSize: 16

                echoMode: TextInput.Password

                background: Rectangle {
                    border.color: confirmPasswordField.activeFocus ? "#1DDCC1" : "#E0E0E0"
                    border.width: 1
                    radius: 5
                    color: "#FAFAFA"
                }
            }
        }

        // 注册
        Button {
            id: registerBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 45
            Layout.topMargin: 10
            text: "注册"

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
                doRegister()
            }
        }
    }
}
