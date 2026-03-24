import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: resetDialog
    anchors.fill: parent
    color: "#f0f0f0"
    radius: 10

    signal switchLogin()

    // 错误提示映射
    property var tipErrors: ({})

    // 验证逻辑
    function checkUserValid() {
        if (userEdit.text === "") {
            addTipErr("TIP_USER_ERR", "用户名不能为空")
            return false
        }
        delTipErr("TIP_USER_ERR")
        return true
    }

    function checkEmailValid() {
        var email = emailEdit.text
        var regex = /(\w+)(\.|_)?(\w*)@(\w+)(\.(\w+))+/
        if (!regex.test(email)) {
            addTipErr("TIP_EMAIL_ERR", "邮箱地址不正确")
            return false
        }
        delTipErr("TIP_EMAIL_ERR")
        return true
    }

    function checkPassValid() {
        var pass = pwdEdit.text
        if (pass.length < 6 || pass.length > 15) {
            addTipErr("TIP_PWD_ERR", "密码长度应为6~15")
            return false
        }
        var regex = /^[a-zA-Z0-9!@#$%^&*]{6,15}$/
        if (!regex.test(pass)) {
            addTipErr("TIP_PWD_ERR", "不能包含非法字符")
            return false
        }
        delTipErr("TIP_PWD_ERR")
        return true
    }

    function checkVerifyValid() {
        if (verifyEdit.text === "") {
            addTipErr("TIP_VERIFY_ERR", "验证码不能为空")
            return false
        }
        delTipErr("TIP_VERIFY_ERR")
        return true
    }

    function addTipErr(key, tips) {
        tipErrors[key] = tips
        showTip(tips, false)
    }

    function delTipErr(key) {
        delete tipErrors[key]
        var keys = Object.keys(tipErrors)
        if (keys.length === 0) {
            errTip.text = ""
            return
        }
        showTip(tipErrors[keys[0]], false)
    }

    function showTip(str, isOk) {
        errTip.text = str
        errTip.color = isOk ? "#28a745" : "#dc3545"
    }

    // 获取验证码
    function onVerifyBtnClicked() {
        if (!checkEmailValid()) {
            return
        }
        resetController.getVerifyCode(emailEdit.text)
    }

    // 确认重置
    function onSureBtnClicked() {
        if (!checkUserValid() || !checkEmailValid() ||
            !checkPassValid() || !checkVerifyValid()) {
            return
        }

        resetController.resetPassword(
            userEdit.text,
            emailEdit.text,
            pwdEdit.text,
            verifyEdit.text
        )
    }

    // 连接C++信号
    Connections {
        target: resetController
        function onVerifyCodeResult(success, message) {
            showTip(message, success)
        }
        function onResetResult(success, message) {
            showTip(message, success)
            if (success) {
                // 延迟返回登录界面
                returnTimer.start()
            }
        }
    }

    Timer {
        id: returnTimer
        interval: 1500
        onTriggered: resetDialog.switchLogin()
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width * 0.85
        spacing: 15

        Text {
            text: "重置密码"
            font.pixelSize: 24
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        TextField {
            id: userEdit
            placeholderText: "用户名"
            Layout.fillWidth: true
            onEditingFinished: checkUserValid()
        }

        TextField {
            id: emailEdit
            placeholderText: "邮箱"
            Layout.fillWidth: true
            onEditingFinished: checkEmailValid()
        }

        RowLayout {
            Layout.fillWidth: true
            TextField {
                id: verifyEdit
                placeholderText: "验证码"
                Layout.fillWidth: true
                onEditingFinished: checkVerifyValid()
            }
            TimerButton {
                id: verifyBtn
                normalText: "获取验证码"
                countdownTime: 60
                onClicked: onVerifyBtnClicked()
            }
        }

        TextField {
            id: pwdEdit
            placeholderText: "新密码"
            echoMode: TextInput.Password
            Layout.fillWidth: true
            onEditingFinished: checkPassValid()
        }

        Text {
            id: errTip
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Button {
            text: "确认重置"
            Layout.fillWidth: true
            onClicked: onSureBtnClicked()
        }

        Button {
            text: "返回登录"
            Layout.fillWidth: true
            onClicked: resetDialog.switchLogin()
        }
    }
}
