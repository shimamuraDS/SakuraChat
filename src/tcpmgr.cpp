#include "tcpmgr.h"
#include "usermgr.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

TcpMgr::TcpMgr() : _host(""), _port(0), _b_recv_pending(false), _message_id(0), _message_len(0) {
    QObject::connect(&_socket, &QTcpSocket::connected, [&]() {
        emit sig_con_success(true);
    });

    QObject::connect(&_socket, &QTcpSocket::readyRead, [&]() {
        // 读取数据并追加到缓冲区
        _buffer.append(_socket.readAll());
        QDataStream stream(&_buffer, QIODevice::ReadOnly);
        stream.setVersion(QDataStream::Qt_6_8);

        forever {
            // 先解析头部
            if (!_b_recv_pending) {
                // 检查缓冲区
                if (_buffer.size() < static_cast<int>(sizeof(quint16) * 2)) {
                    return;
                }
                // 预读取
                stream >> _message_id >> _message_len;
                // 移除前四个字节
                _buffer = _buffer.mid(sizeof(quint16) * 2);
                qDebug() << "Message ID: " << _message_id << ", Length: " << _message_len;
            }

            // 检查剩余长度
            if (_buffer.size() < _message_len) {
                _b_recv_pending = true;
                return;
            }

            _b_recv_pending = false;
            QByteArray messageBody = _buffer.mid(0, _message_len);

            _buffer = _buffer.mid(_message_len);
            handleMsg(static_cast<ReqId>(_message_id), _message_len, messageBody);
        }
    });

    QObject::connect(&_socket, QOverload<QAbstractSocket::SocketError>::of(&QTcpSocket::errorOccurred), [&](QAbstractSocket::SocketError socketError) {
        Q_UNUSED(socketError)
        qDebug() << "Error: " << _socket.errorString();
    });

    // 处理连接断开
    QObject::connect(&_socket, &QTcpSocket::disconnected, [&] {
        qDebug() << "Disconnected from server.";
    });

    // 连接发送信号用来发送数据
    QObject::connect(this, &TcpMgr::sig_send_data, this, &TcpMgr::slot_send_data);

    // 注册消息
    initHandlers();
}

TcpMgr::~TcpMgr() {

}

void TcpMgr::initHandlers() {
    _handlers.insert(ID_CHAT_LOGIN_RSP, [this](ReqId id, int len, const QByteArray &data) {
        Q_UNUSED(len);
        qDebug() << "handle id is " << id << "data is " << data;
        QJsonDocument jsonDoc = QJsonDocument::fromJson(data);
        if (jsonDoc.isNull()) {
            qDebug() << "Failed to create QJsonDocument.";
            return;
        }
        QJsonObject jsonObj = jsonDoc.object();
        if (!jsonObj.contains("error")) {
            int err = ErrorCodes::ERR_JSON;
            qDebug() << "Login Failed, err is Json Parse Err" << err;
            emit sig_login_failed(err);
            return;
        }
        int err = jsonObj["error"].toInt();
        if (err != ErrorCodes::SUCCESS) {
            qDebug() << "Login Failed, err is " << err;
            emit sig_login_failed(err);
            return;
        }

        UserMgr::GetInstance()->SetName(jsonObj["name"].toString());
        UserMgr::GetInstance()->SetUid(jsonObj["uid"].toInt());
        UserMgr::GetInstance()->SetToken(jsonObj["token"].toString());

        QVariantList applications;
        const auto array = jsonObj["apply_list"].toArray();
        for (const auto &value : array) {
            const auto source = value.toObject();
            QVariantMap item;
            item["applyId"] = source["apply_id"].toVariant().toLongLong();
            item["uid"] = source["uid"].toInt();
            item["name"] = source["name"].toString();
            item["head"] = source["icon"].toString();
            item["message"] = source["message"].toString();
            item["status"] = source["status"].toInt();
            applications.append(item);
        }
        _friendApplySnapshot = applications;
        emit friendApplySnapshotChanged();

        emit sig_switch_chatlg();
    });

    _handlers.insert(ID_SEARCH_USER_RSP,
                     [this](ReqId, int, const QByteArray &data) {
                         _searchPending = false;
                         emit searchPendingChanged();

                         const auto doc = QJsonDocument::fromJson(data);
                         if (!doc.isObject()) {
                             emit sig_search_failed(ErrorCodes::ERR_JSON, "响应格式错误");
                             return;
                         }

                         const QJsonObject root = doc.object();
                         if (root["error"].toInt(-1) != ErrorCodes::SUCCESS) {
                             emit sig_search_failed(root["error"].toInt(), "查询失败");
                             return;
                         }

                         QVariantList results;
                         if (root["found"].toBool(false)) {
                             QVariantMap user;
                             user["uid"] = root["uid"].toInt();
                             user["name"] = root["name"].toString();
                             user["nick"] = root["nick"].toString();
                             user["desc"] = root["desc"].toString();
                             user["gender"] = root["gender"].toInt();
                             user["icon"] = root["icon"].toString();
                             user["isFriend"] = root["is_friend"].toBool(false);
                             results.append(user);
                         }
                         emit sig_user_search(results);
                     });

    _handlers.insert(ID_ADD_FRIEND_RSP,
                     [this](ReqId, int, const QByteArray &data) {
                         _applyPending = false;
                         emit applyPendingChanged();

                         const auto doc = QJsonDocument::fromJson(data);
                         if (!doc.isObject()) {
                             emit sig_friend_apply_result(ErrorCodes::ERR_JSON, -1, 0);
                             return;
                         }

                         const auto root = doc.object();
                         emit sig_friend_apply_result(
                             root["error"].toInt(-1),
                             root["result"].toInt(-1),
                             root["apply_id"].toVariant().toLongLong());
                     });

    _handlers.insert(ID_NOTIFY_ADD_FRIEND_REQ,
                     [this](ReqId, int, const QByteArray &data) {
                         const auto root = QJsonDocument::fromJson(data).object();
                         if (root["error"].toInt(-1) != ErrorCodes::SUCCESS)
                             return;

                         QVariantMap item;
                         item["applyId"] = root["apply_id"].toVariant().toLongLong();
                         item["uid"] = root["applyuid"].toInt();
                         item["name"] = root["name"].toString();
                         item["head"] = root["icon"].toString();
                         item["message"] = root["message"].toString();
                         item["status"] = 0;
                         emit sig_friend_apply(item);
                     });

    _handlers.insert(ID_AUTH_FRIEND_RSP,
                     [this](ReqId, int, const QByteArray &data) {
                         _reviewPending = false;
                         emit reviewPendingChanged();

                         const auto doc = QJsonDocument::fromJson(data);
                         if (!doc.isObject()) {
                             emit sig_friend_apply_resolved(
                                 ErrorCodes::ERR_JSON, -1, 0, false);
                             return;
                         }

                         const auto root = doc.object();
                         emit sig_friend_apply_resolved(
                             root["error"].toInt(-1),
                             root["result"].toInt(-1),
                             root["apply_id"].toVariant().toLongLong(),
                             root["agree"].toBool(false));
                     });

    _handlers.insert(ID_NOTIFY_AUTH_FRIEND_REQ,
                     [this](ReqId, int, const QByteArray &data) {
                         const auto doc = QJsonDocument::fromJson(data);
                         if (!doc.isObject())
                             return;

                         const auto root = doc.object();
                         if (root["error"].toInt(-1) != ErrorCodes::SUCCESS ||
                             root["result"].toInt(-1) != 0) {
                             return;
                         }

                         emit sig_friend_auth_notified(
                             root["apply_id"].toVariant().toLongLong(),
                             root["agree"].toBool(false),
                             root["peer_uid"].toInt());
                     });
}

void TcpMgr::handleMsg(ReqId id, int len, const QByteArray &data) {
    auto find_iter = _handlers.find(id);
    if (find_iter == _handlers.end()) {
        qDebug() << "not found id [" << id << "] to handle";
        return;
    }

    find_iter.value()(id, len, data);
}

void TcpMgr::slot_tcp_connect(ServerInfo si) {
    qDebug() << "receive tcp connect signal";
    qDebug() << "connecting to server...";

    // 如果当前socket已经连接或者正在连接，先关闭并重置
    if (_socket.state() != QAbstractSocket::UnconnectedState) {
        _socket.close();
    }

    _host = si.Host;
    _port = static_cast<uint16_t>(si.Port.toUInt());
    _socket.connectToHost(si.Host, _port);
}

void TcpMgr::slot_send_data(ReqId reqId, QString data) {
    const auto id = static_cast<quint16>(reqId);
    QByteArray dataBytes = data.toUtf8();
    quint16 len = static_cast<quint16>(dataBytes.size());
    QByteArray block;
    QDataStream out(&block, QIODevice::WriteOnly);

    out.setByteOrder(QDataStream::BigEndian);
    out << id << len;
    block.append(dataBytes);

    _socket.write(block);
}

void TcpMgr::sendJson(ReqId id, const QJsonObject &object) {
    slot_send_data(id, QString::fromUtf8(QJsonDocument(object).toJson(QJsonDocument::Compact)));
}


void TcpMgr::searchUser(const QString &keyword) {
    const QString value = keyword.trimmed();
    if (value.isEmpty() || _searchPending)
        return;

    _searchPending = true;
    emit searchPendingChanged();
    sendJson(ID_SEARCH_USER_REQ, {{"keyword", value}});
}

void TcpMgr::applyFriend(int toUid, const QString &descs, const QString &backName) {
    if (toUid <= 0 || _applyPending)
        return;

    _applyPending = true;
    emit applyPendingChanged();
    sendJson(ID_ADD_FRIEND_REQ, {
                                    {"touid", toUid},
                                    {"descs", descs.trimmed()},
                                    {"back_name", backName.trimmed()}
                                });
}

void TcpMgr::resolveFriendApply(qint64 applyId, bool agree) {
    if (applyId <= 0 || _reviewPending)
        return;

    _reviewPending = true;
    emit reviewPendingChanged();
    sendJson(ID_AUTH_FRIEND_REQ, {
                                     {"apply_id", applyId},
                                     {"agree", agree}
                                 });
}

void TcpMgr::resetBusinessPending() {
    if (_searchPending) {
        _searchPending = false;
        emit searchPendingChanged();
    }
    if (_applyPending) {
        _applyPending = false;
        emit applyPendingChanged();
    }
    if (_reviewPending) {
        _reviewPending = false;
        emit reviewPendingChanged();
    }
}
