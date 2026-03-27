import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: resetDialog
    anchors.fill: parent
    color: "#f0f0f0"
    radius: 10

    signal switchLogin()

    // 统一的提示函数，替代原版臃肿的 tipErrors 字典逻辑
    function showTip(message, isSuccess = false) {
        errTip.text = message
        errTip.color = isSuccess ? "#28a745" : "#dc3545"
    }

    // 集中式、线性的表单校验拦截器
    function validateForm() {
        const emailRegex = /^[\w\.-]+@[\w\.-]+\.\w+$/
        const passRegex = /^[a-zA-Z0-9!@#$%^&*]{6,15}$/

        if (userEdit.text.trim() === "") {
            showTip("用户名不能为空", false)
            return false
        }
        if (!emailRegex.test(emailEdit.text.trim())) {
            showTip("邮箱地址不正确", false)
            return false
        }
        if (verifyEdit.text.trim() === "") {
            showTip("验证码不能为空", false)
            return false
        }

        const pass = pwdEdit.text
        if (pass.length < 6 || pass.length > 15) {
            showTip("密码长度应为6~15", false)
            return false
        }
        if (!passRegex.test(pass)) {
            showTip("密码不能包含非法字符", false)
            return false
        }

        showTip("", true) // 校验通过，清空错误提示
        return true
    }

    // 获取验证码逻辑
    function onVerifyBtnClicked() {
        const emailRegex = /^[\w\.-]+@[\w\.-]+\.\w+$/
        if (!emailRegex.test(emailEdit.text.trim())) {
            showTip("请输入正确的邮箱以获取验证码", false)
            return
        }

        // 调用 C++ 后端获取验证码
        resetController.getVerifyCode(emailEdit.text.trim())

        // 启动倒计时 (调用你在 TimerButton 中定义的函数)
        verifyBtn.startCountdown()
    }

    // 确认重置逻辑
    function onSureBtnClicked() {
        // 触发集中校验，失败则直接拦截
        if (!validateForm()) {
            return
        }

        resetController.resetPassword(
            userEdit.text.trim(),
            emailEdit.text.trim(),
            pwdEdit.text,
            verifyEdit.text.trim()
        )
    }

    // 监听 C++ 后端信号
    Connections {
        target: resetController

        function onVerifyCodeResult(success, message) {
            showTip(message, success)
        }

        function onResetResult(success, message) {
            showTip(message, success)
            if (success) {
                // 成功后延迟 1.5 秒自动返回登录界面
                returnTimer.start()
            }
        }
    }

    Timer {
        id: returnTimer
        interval: 1500
        onTriggered: resetDialog.switchLogin()
    }

    // ---------------- UI 布局 ----------------
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
            // 删除了繁琐的 onEditingFinished
        }

        TextField {
            id: emailEdit
            placeholderText: "邮箱"
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            TextField {
                id: verifyEdit
                placeholderText: "验证码"
                Layout.fillWidth: true
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
        }

        // 统一的错误提示文本框
        Text {
            id: errTip
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            font.pixelSize: 13
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
