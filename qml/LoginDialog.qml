import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: loginDialog
    width: 350
    height: 500
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

            onClicked: loginDialog.switchRegister()
        }
    }
}
