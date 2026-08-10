import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SakuraChat

Rectangle {
    id: loginDialog
    radius: 16
    border.color: "#ebebeb"
    border.width: 1
    gradient: Gradient {
        GradientStop {
            position: 0.0;
            color: "#f0f8ff"
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

    // TCP连接状态
    property bool isConnectingTcp: false

    Timer {
        id: tipTimer
        interval: 3000
        onTriggered: err_tip.text = ""
    }

    // 显示提示信息
    function showTip(message, success) {
        err_tip.text = message;
        err_tip.color = success ? "#10b981" : "#ef4444";
        tipTimer.restart();
    }

    // 登录处理函数
    function handleLogin() {
        if (!checkUserValid()) return;
        if (!checkPassValid()) return;

        var userData = {
            email: emailField.text,
            passwd: passwordField.text
        };

        LoginController.loginUser(userData);
    }

    // 邮箱验证
    function checkUserValid() {
        if (emailField.text === "") {
            showTip("邮箱不能为空", false);
            return false;
        }
        return true;
    }

    // 密码验证
    function checkPassValid() {
        var pwd = passwordField.text;
        if (pwd.length < 6 || pwd.length > 15) {
            showTip("密码长度必须在6-15位之间", false);
            return false;
        }
        return true;
    }

    // 监听 LoginController 的信号
    Connections {
        target: LoginController

        function onLoginResult(success, error, message, user) {
            if (!success) {
                showTip(message || "登录失败", false);
                return;
            }
            showTip("登录成功", true);
            console.log("User logged in:", user);
            // TODO: 跳转到主界面
        }

        // 把 onSig_connect_tcp 移回 LoginController 下
        function onSig_connect_tcp(serverInfo) {
            console.log("开始连接聊天服务器...")
            isConnectingTcp = true
            showTip("正在连接聊天服务器...", true)
        }
    }

    // 监听 TcpMgr 的信号（注意 target 改为大写）
    Connections {
        target: TcpMgr

        function onSig_con_success(success) {
            if (success) {
                console.log("聊天服务连接成功")
                showTip("聊天服务连接成功，正在登录...", true)
            } else {
                console.log("聊天服务连接失败")
                showTip("网络异常", false)
                isConnectingTcp = false
                loginBtn.enabled = true
            }
        }

        function onSig_login_failed(err) {
            console.log("聊天登录失败，错误码:", err)
            showTip("聊天登录失败", false)
            isConnectingTcp = false
            loginBtn.enabled = true
        }

        function onSig_switch_chatlg() {
            console.log("登录成功，准备切换到聊天界面")
            showTip("登录成功！", true)
            // TODO: 切换到聊天主界面
        }
    }

    // 监听登录结果
    Connections {
        target: LoginController
        function onLoginResult(success, error, message, user) {
            if (!success) {
                showTip(message || "登录失败", false);
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
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            color: "red"
            visible: text !== ""
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 13
        }

        // 邮箱输入框
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "邮箱"
                font.pixelSize: 14
                color: "#555555"
            }

            TextField {
                id: emailField
                placeholderText: "请输入邮箱"
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                font.pixelSize: 16

                background: Rectangle {
                    radius: 6
                    color: "#f9f9f9"
                    border.color: emailField.activeFocus ? "#1DDCC1" : "#cccccc"
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
