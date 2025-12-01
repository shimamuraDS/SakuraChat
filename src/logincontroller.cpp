#include "logincontroller.h"
#include "httpmgr.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>

LoginController::LoginController(QObject *parent)
    : QObject(parent)
{
    initHttpHandlers();

    // 连接登录回包信号
    connect(HttpMgr::GetInstance().get(), &HttpMgr::sig_login_mod_finish,
            this, &LoginController::slot_login_mod_finish);
}

void LoginController::loginUser(const QVariantMap &userData)
{
    QJsonObject json_obj;
    json_obj["email"] = userData["email"].toString();
    json_obj["passwd"] = userData["passwd"].toString();

    qDebug() << "Sending login request to:" << gate_url_prefix + "/user_login";

    HttpMgr::GetInstance()->PostHttpReq(
        QUrl(gate_url_prefix + "/user_login"),
        json_obj,
        ReqId::ID_LOGIN_USER,
        Modules::LOGINMOD
        );
}

void LoginController::initHttpHandlers()
{
    _handlers.insert(ReqId::ID_LOGIN_USER, [this](const QJsonObject &jsonObj) {
        qDebug() << "Login response received:" << jsonObj;

        int error = jsonObj["error"].toInt();
        if (error != ErrorCodes::SUCCESS) {
            QString msg = jsonObj["msg"].toString();
            qDebug() << "Login failed with error:" << error << "message:" << msg;
            emit loginResult(false, error, msg, "");
            return;
        }

        QString email = jsonObj["email"].toString();
        qDebug() << "Login successful, user:" << email;
        emit loginResult(true, ErrorCodes::SUCCESS, "登录成功", email);
    });
}

void LoginController::slot_login_mod_finish(ReqId id, QString res, ErrorCodes err)
{
    if (err != ErrorCodes::SUCCESS) {
        qDebug() << "Network error occurred";
        emit loginResult(false, err, "网络请求错误", "");
        return;
    }

    QJsonDocument jsonDoc = QJsonDocument::fromJson(res.toUtf8());
    if (jsonDoc.isNull() || !jsonDoc.isObject()) {
        qDebug() << "JSON parse error";
        emit loginResult(false, ErrorCodes::ERR_JSON, "JSON解析错误", "");
        return;
    }

    // 调用对应的处理器
    if (_handlers.contains(id)) {
        _handlers[id](jsonDoc.object());
    } else {
        qDebug() << "No handler found for ReqId:" << static_cast<int>(id);
    }
}
