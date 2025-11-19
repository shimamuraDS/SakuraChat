#include "logincontroller.h"
#include "httpmgr.h"
#include "global.h"

void LoginController::loginUser(const QVariantMap &userData) {
    QJsonObject json_obj;
    json_obj["user"] = userData["user"].toString();
    json_obj["passwd"] = userData["passwd"].toString();

    HttpMgr::GetInstance()->PostHttpReq(
        QUrl(gate_url_prefix + "/user_login"),
        json_obj,
        ReqId::ID_LOGIN_USER,
        Modules::LOGINMOD
        );
}

QString LoginController::xorString(const QString &input) {
    QString result;
    const QString key = "SakuraChat";
    for (int i = 0; i < input.length(); ++i) {
        result += QChar(input[i].unicode() ^ key[i % key.length()].unicode());
    }
    return result;
}

void LoginController::initHttpHandlers() {
    _handlers.insert(ReqId::ID_LOGIN_USER, [this](const QJsonObject &jsonObj) {
        int error = jsonObj["error"].toInt();
        if (error != ErrorCodes::SUCCESS) {
            emit loginResult(false, error, jsonObj["msg"].toString(), "");
            return;
        }

        QString user = jsonObj["user"].toString();
        emit loginResult(true, ErrorCodes::SUCCESS, "登录成功", user);
    });
}

void LoginController::slot_login_mod_finish(ReqId id, QString res, ErrorCodes err) {
    if (err != ErrorCodes::SUCCESS) {
        emit loginResult(false, err, "网络请求错误", "");
        return;
    }

    QJsonDocument jsonDoc = QJsonDocument::fromJson(res.toUtf8());
    if (jsonDoc.isNull() || !jsonDoc.isObject()) {
        emit loginResult(false, ErrorCodes::ERR_JSON, "JSON解析错误", "");
        return;
    }

    _handlers[id](jsonDoc.object());
}
