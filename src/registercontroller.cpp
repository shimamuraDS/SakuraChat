#include "registercontroller.h"
#include <QObject>
#include "global.h"
#include "httpmgr.h"

RegisterController::RegisterController(QObject *parent) : QObject(parent) {
    initHttpHandlers();
    connect(HttpMgr::GetInstance().get(), &HttpMgr::sig_reg_mod_finish, this, &RegisterController::slot_reg_mod_finish);
}

void RegisterController::getVerifyCode(const QString& email) {
    QJsonObject json;
    json["email"] = email;

    QString url = gate_url_prefix + "/get_varifycode";
    HttpMgr::GetInstance()->PostHttpReq(QUrl(url), json, ReqId::ID_GET_VARIFY_CODE, Modules::REGISTERMOD);
}

void RegisterController::registerUser(const QString& username, const QString& email, const QString& varifyCode, const QString& password, const QString& confirm){
    QJsonObject json;
    json["username"] = username;
    json["email"] = email;
    json["varifycode"] = varifyCode;
    json["password"] = password;
    json["confirm"] = confirm;

    QString url = gate_url_prefix + "/user_register";
    HttpMgr::GetInstance()->PostHttpReq(QUrl(url), json, ReqId::ID_REG_USER, Modules::REGISTERMOD);
}

void RegisterController::initHttpHandlers() {
    // 注册获取验证码回包逻辑
    _handlers.insert(ReqId::ID_GET_VARIFY_CODE, [this](QJsonObject jsonObj) {
        int error = jsonObj["error"].toInt();
        if (error != ErrorCodes::SUCCESS) {
            qDebug() << "Received JSON:" << jsonObj;
            qDebug() << "Error code:" << error;

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
    if (_handlers.contains(id)){
        _handlers[id](jsonObj);
    }
}
