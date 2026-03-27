#include "resetcontroller.h"
#include "httpmgr.h"
#include <QJsonDocument>
#include <QDebug>
#include "configmanager.h"

ResetController::ResetController(QObject *parent)
    : QObject{parent}
{
    initHttpHandlers();
    connect(HttpMgr::GetInstance().get(), &HttpMgr::sig_reset_mod_finish,
            this, &ResetController::slot_reset_mod_finish);
}

void ResetController::getVerifyCode(const QString& email)
{
    QJsonObject json_obj;
    json_obj["email"] = email;
    HttpMgr::GetInstance()->PostHttpReq(
        QUrl(ConfigManager::instance().gateUrlPrefix() + "/get_varifycode"),
        json_obj, ReqId::ID_GET_VARIFY_CODE, Modules::RESETMOD);
}

void ResetController::resetPassword(const QString& user, const QString& email,
                                    const QString& password, const QString& verifyCode)
{
    QJsonObject json_obj;
    json_obj["user"] = user;
    json_obj["email"] = email;
    json_obj["passwd"] = password; // 需要加密处理
    json_obj["varifycode"] = verifyCode;

    HttpMgr::GetInstance()->PostHttpReq(
        QUrl(ConfigManager::instance().gateUrlPrefix() + "/reset_pwd"),
        json_obj, ReqId::ID_RESET_PWD, Modules::RESETMOD);
}

void ResetController::initHttpHandlers()
{
    _handlers.insert(ReqId::ID_GET_VARIFY_CODE, [this](const QJsonObject& jsonObj){
        int error = jsonObj["error"].toInt();
        if (error != ErrorCodes::SUCCESS) {
            emit verifyCodeResult(false, "参数错误");
            return;
        }
        emit verifyCodeResult(true, "验证码已发送到邮箱，注意查收");
    });

    _handlers.insert(ReqId::ID_RESET_PWD, [this](const QJsonObject& jsonObj){
        int error = jsonObj["error"].toInt();
        if (error != ErrorCodes::SUCCESS) {
            emit resetResult(false, "重置失败，请检查信息");
            return;
        }
        emit resetResult(true, "重置成功，即将返回登录");
    });
}

void ResetController::slot_reset_mod_finish(ReqId id, QString res, ErrorCodes err)
{
    if (err != ErrorCodes::SUCCESS) {
        emit resetResult(false, "网络请求错误");
        return;
    }

    QJsonDocument jsonDoc = QJsonDocument::fromJson(res.toUtf8());
    if (jsonDoc.isNull() || !jsonDoc.isObject()) {
        emit resetResult(false, "json解析错误");
        return;
    }

    _handlers[id](jsonDoc.object());
}
