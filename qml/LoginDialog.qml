import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: loginDialog
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

    // 切换注册
    signal switchRegister()
    // 切换重置
    signal switchReset()

    // 登录处理函数
    function handleLogin() {
        if (!checkUserValid()) return;
        if (!checkPassValid()) return;

        var userData = {
            user: usernameField.text,
            passwd: loginController.xorString(passwordField.text)
        };

        loginController.loginUser(userData);
    }

    // 用户名验证
    function checkUserValid() {
        if (user_edit.text === "") {
            showTip("用户名不能为空", false);
            return false;
        }
        return true;
    }

    // 密码验证
    function checkPassValid() {
        var pwd = pass_edit.text;
        if (pwd.length < 6 || pwd.length > 15) {
            showTip("密码长度必须在6-15位之间", false);
            return false;
        }
        return true;
    }

    // 显示提示信息
    function showTip(message, success) {
        err_tip.text = message;
        err_tip.color = success ? "green" : "red";
        tipTimer.restart();
    }

    // 监听登录结果
    Connections {
        target: loginController
        function onLoginResult(success, error, message, user) {
            if (!success) {
                if (error === ErrorCodes.ERR_NETWORK) {
                    showTip("网络请求错误", false);
                } else {
                    showTip(message || "登录失败", false);
                }
                return;
            }

            showTip("登录成功", true);
            console.log("User logged in:", user);
            // TODO: 跳转到主界面
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 18
        width: parent.width * 0.8

        // Logo
        Item {
            Layout.preferredHeight: 100
            Layout.fillWidth: true

            Image {
                anchors.centerIn: parent
                source: "qrc:/res/SakuraChat.png"
                width: 72
                height: 72
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }

        // 标题
        Text {
            text: "SakuraChat"
            Layout.fillWidth: true
            font.pixelSize: 24
            font.bold: true
            color: "#222222"
            horizontalAlignment: Text.AlignHCenter
            font.letterSpacing: 2
        }

        Text {
                id: err_tip
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 20
                color: "red"
                visible: text !== ""
            }

        // 用户名输入框
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "用户名"
                font.pixelSize: 14
                color: "#555555"
            }

            TextField {
                id: usernameField
                placeholderText: "请输入用户名"
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                font.pixelSize: 16

                background: Rectangle {
                    radius: 6
                    color: "#f9f9f9"
                    border.color: usernameField.activeFocus ? "#1DDCC1" : "#cccccc"
                    border.width: 1
                }
            }
        }

        // 密码输入框
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "密码"
                font.pixelSize: 14
                color: "#555555"
            }

            TextField {
                id: passwordField
                echoMode: TextInput.Password
                placeholderText: "请输入密码"
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                font.pixelSize: 16

                background: Rectangle {
                    radius: 6
                    color: "#f9f9f9"
                    border.color: passwordField.activeFocus ? "#1DDCC1" : "#cccccc"
                    border.width: 1
                }
            }
        }

        // 忘记密码
        Text {
            id: forgetLabel
            text: "忘记密码?"
            color: "#1976d2"
            font.pixelSize: 12
            Layout.alignment: Qt.AlignRight

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onEntered: {
                    forgetLabel.color = "#1565c0"
                    forgetLabel.font.underline = true
                }
                onExited: {
                    forgetLabel.color = "#1976d2"
                    forgetLabel.font.underline = false
                }
                onClicked: {
                    loginDialog.switchReset()
                }
            }
        }

        // 空白间隔
        Item {
            Layout.preferredHeight: 18
        }

        // 登录按钮
        Button {
            id: loginBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            text: "登录"

            background: Rectangle {
                color: loginBtn.pressed ? "#1DDCC0" : "#1DDCC1"
                radius: 6
            }

            contentItem: Text {
                text: loginBtn.text
                font.pixelSize: 16
                font.bold: true
                color: "#ffffff"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                handleLogin()
            }
        }

        // 注册按钮
        Button {
            id: regBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            text: "注册"

            background: Rectangle {
                color: "transparent"
                border.color: "#1DDCC1"
                border.width: 1
                radius: 6
            }

            contentItem: Text {
                text: regBtn.text
                font.pixelSize: 14
                color: "#1DDCC1"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                loginDialog.switchRegister()
            }
        }
    }
}
