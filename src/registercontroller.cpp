#include "registercontroller.h"
#include <QObject>

RegisterController::RegisterController(QObject *parent) : QObject(parent) {
    initHttpHandlers();
    connect(HttpMgr::GetInstance().get(), &HttpMgr::sig_reg_mod_finish, this, &RegisterController::slot_reg_mod_finish);
}

void RegisterController::getVerifyCode(const QString& email) {
    QJsonObject json;
    json["email"] = email;

    // TODO: 服务器地址
    QUrl url("http://server.com/get_verify_code");
    HttpMgr::GetInstance()->PostHttpReq(url, json, ReqId::ID_GET_VARIFY_CODE, Modules::REGISTERMOD);
}

void RegisterController::registerUser(const QString& username, const QString& email, const QString& verifyCode, const QString& password){
    QJsonObject json;
    json["username"] = username;
    json["email"] = email;
    json["verify_code"] = verifyCode;
    json["password"] = password;

    // TODO: 服务器地址
    QUrl url("http://your-server.com/register");
    HttpMgr::GetInstance()->PostHttpReq(url, json, ReqId::ID_REG_USER, Modules::REGISTERMOD);
}

void RegisterController::initHttpHandlers() {
    // 注册获取验证码回包逻辑
    _handlers.insert(ReqId::ID_GET_VARIFY_CODE, [this](QJsonObject jsonObj) {
        int error = jsonObj["error"].toInt();
        if (error != ErrorCodes::SUCCESS) {
            emit verifyCodeResult(false, QObject::tr("参数错误"));
            return;
        }
        auto email = jsonObj["email"].toString();
        emit verifyCodeResult(true, QObject::tr("验证码已发送到邮箱，注意查收"));
        qDebug() << "email is " << email;
    });

    // 注册用户回包逻辑
    _handlers.insert(ReqId::ID_REG_USER, [this](QJsonObject jsonObj) {
        int error = jsonObj["error"].toInt();
        if (error != ErrorCodes::SUCCESS) {
            emit registerResult(false, QObject::tr("注册失败"));
            return;
        }
        emit registerResult(true, QObject::tr("注册成功"));
    });
}

void RegisterController::slot_reg_mod_finish(ReqId id, QString res, ErrorCodes err) {
    if (err != ErrorCodes::SUCCESS) {
        if (id == ReqId::ID_GET_VARIFY_CODE) {
            emit verifyCodeResult(false, QObject::tr("网络请求错误"));
        } else if (id == ReqId::ID_REG_USER) {
            emit registerResult(false, QObject::tr("网络请求错误"));
        }
        return;
    }

    // 解析JSON
    QJsonDocument jsonDoc = QJsonDocument::fromJson(res.toUtf8());
    // json解析错误
    if (jsonDoc.isNull() || !jsonDoc.isObject()) {
        if (id == ReqId::ID_GET_VARIFY_CODE) {
            emit verifyCodeResult(false, QObject::tr("json解析错误"));
        } else if (id == ReqId::ID_REG_USER) {
            emit verifyCodeResult(false, QObject::tr("json解析错误"));
        }
        return;
    }

    QJsonObject jsonObj = jsonDoc.object();
    // 根据id回调
    _handlers[id](jsonObj);
}
