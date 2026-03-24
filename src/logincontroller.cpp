#include "logincontroller.h"
#include "httpmgr.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>
#include "tcpmgr.h"

LoginController::LoginController(QObject *parent)
    : QObject(parent)
{
    initHttpHandlers();

    // 连接登录回包信号
    connect(HttpMgr::GetInstance().get(), &HttpMgr::sig_login_mod_finish,
            this, &LoginController::slot_login_mod_finish);
    //连接tcp连接请求的信号和槽函数
    connect(this, &LoginController::sig_connect_tcp, TcpMgr::GetInstance().get(), &TcpMgr::slot_tcp_connect);
    //连接tcp管理者发出的连接成功信号
    connect(TcpMgr::GetInstance().get(), &TcpMgr::sig_con_success, this, &LoginController::slot_tcp_con_finish);
    //连接tcp管理者发出的登录失败信号
    connect(TcpMgr::GetInstance().get(), &TcpMgr::sig_login_failed, this, &LoginController::slot_login_failed);
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
    // 注册获取登录回包逻辑
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

        // 发送信号通知tcpMgr发送长链接
        ServerInfo si;
        si.Uid = jsonObj["uid"].toInt();
        si.Host = jsonObj["host"].toString();
        si.Port = jsonObj["port"].toString();
        si.Token = jsonObj["token"].toString();

        _uid = si.Uid;
        _token = si.Token;

        qDebug() << "User is" << email << "uid is" << si.Uid << "host is"
                 << si.Host << "Port is" << si.Port << "Token is" << si.Token;

        // 发送HTTP登录成功信号（QML会接收并显示提示）
        emit loginResult(true, ErrorCodes::SUCCESS, "登录验证成功", email);

        // 发起TCP连接
        emit sig_connect_tcp(si);
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

void LoginController::slot_tcp_con_finish(bool success)
{
    if (success) {
        qDebug() << "TCP connection successful, sending chat login request...";

        // 构造聊天登录请求
        QJsonObject jsonObj;
        jsonObj["uid"] = _uid;
        jsonObj["token"] = _token;

        QJsonDocument doc(jsonObj);
        QString jsonString = doc.toJson(QJsonDocument::Compact);

        // 发送TCP请求给chat server
        emit TcpMgr::GetInstance()->sig_send_data(ReqId::ID_CHAT_LOGIN, jsonString);

    } else {
        qDebug() << "TCP connection failed";
        // 通过loginResult信号通知QML连接失败
        emit loginResult(false, ErrorCodes::ERR_NETWORK, "网络异常", "");
    }
}

void LoginController::slot_login_failed(int error)
{
    qDebug() << "Chat login failed with error:" << error;

    QString errorMsg;
    switch (error) {
    case ErrorCodes::ERR_NETWORK:
        errorMsg = "网络连接失败";
        break;
    default:
        errorMsg = "登录失败";
        break;
    }

    // 通知QML登录失败
    emit loginResult(false, error, errorMsg, "");
}
