#include "tcpmgr.h"
#include "usermgr.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

TcpMgr::TcpMgr() : _host(""), _port(0), _b_recv_pending(false), _message_id(0), _message_len(0) {
    _chatStore = new ChatStore(this);
    _friendTimer.setSingleShot(true);
    _friendTimer.setInterval(5000);
    connect(&_friendTimer, &QTimer::timeout, this, [this] {
        failFriendSync("联系人同步超时；保留旧列表，可手动刷新");
    });

    QObject::connect(&_socket, &QTcpSocket::connected, [&]() {
        emit sig_con_success(true);
    });

    connect(&_socket, &QTcpSocket::readyRead, this, [this] {
        _buffer.append(_socket.readAll());
        while (_buffer.size() >= 4) {
            const QByteArray header = _buffer.left(4);
            QDataStream stream(header);
            stream.setByteOrder(QDataStream::BigEndian);
            quint16 id = 0, length = 0;
            stream >> id >> length;
            // 接收仍兼容现有登录回包；服务端内部长度为 short。
            if (length == 0 || length > 32763) {
                emit chatError("收到非法长度帧");
                _socket.abort();
                return;
            }
            if (_buffer.size() < 4 + length) return; // 半包继续等待
            const QByteArray body = _buffer.mid(4, length);
            _buffer.remove(0, 4 + length);
            handleMsg(static_cast<ReqId>(id), length, body);
        }
    });

    connect(&_socket, &QTcpSocket::errorOccurred, this,
            [this](QAbstractSocket::SocketError) { handleTransportLoss(); });
    connect(&_socket, &QTcpSocket::disconnected, this,
            [this] { handleTransportLoss(); });

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

        _chatStore->reset(UserMgr::GetInstance()->GetUid(), UserMgr::GetInstance()->GetName());
        _chatReady = true;
        emit chatReadyChanged();
        refreshFriends();
        emit sig_switch_chatlg();
    });

    _handlers.insert(ID_FRIEND_LIST_RSP, [this](ReqId, int, const QByteArray &data) {
        onFriendPage(data);
    });
    _handlers.insert(ID_TEXT_CHAT_MSG_RSP, [this](ReqId, int, const QByteArray &data) {
        onTextReply(data);
    });
    _handlers.insert(ID_NOTIFY_TEXT_CHAT_MSG_REQ, [this](ReqId, int, const QByteArray &data) {
        onTextNotify(data);
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
                         if (root["error"].toInt(-1) == 0 &&
                             root["result"].toInt(-1) == 0 && root["agree"].toBool(false)) {
                             refreshFriends();
                         }
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

                         if (root["agree"].toBool(false))
                             refreshFriends();

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
    handleTransportLoss();
    _chatStore->reset(0, QString{});
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

void TcpMgr::handleTransportLoss()
{
    const bool wasReady = _chatReady;
    _chatReady = false;
    if (wasReady) emit chatReadyChanged();
    _friendTimer.stop();
    _friendRequestId.clear();
    _friendStaging.clear();
    _friendSyncAgain = false;
    if (_friendSyncBusy) {
        _friendSyncBusy = false;
        emit friendSyncBusyChanged();
    }
    _pendingTexts.clear();
    _chatStore->disconnectPending();
    resetBusinessPending(); // 上一课已有定义，现在实际接入
    _buffer.clear();
    _b_recv_pending = false;
    if (wasReady) emit chatError("连接已断开，未确认消息状态未知");
}

bool TcpMgr::sendSmallJson(ReqId id, const QJsonObject &object)
{
    if (!_chatReady || _socket.state() != QAbstractSocket::ConnectedState)
        return false;
    const auto body = QJsonDocument(object).toJson(QJsonDocument::Compact);
    if (body.isEmpty() || body.size() > 1800 || _socket.bytesToWrite() > 65536)
        return false;
    QByteArray frame;
    QDataStream stream(&frame, QIODevice::WriteOnly);
    stream.setByteOrder(QDataStream::BigEndian);
    stream << static_cast<quint16>(id) << static_cast<quint16>(body.size());
    frame.append(body);
    if (_socket.write(frame) != frame.size()) {
        _socket.abort(); // 不在流中继续拼接下一条请求
        return false;
    }
    return true;
}

void TcpMgr::refreshFriends() {
    if (!_chatReady) {
        emit chatError("请先完成聊天服务器登录");
        return;
    }
    if (_friendSyncBusy) {
        _friendSyncAgain = true;
        return;
    }
    _friendSyncBusy = true;
    _friendSyncAgain = false;
    _friendCursor = 0;
    _friendStaging.clear();
    _friendRequestId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    emit friendSyncBusyChanged();
    requestFriendPage();
}

void TcpMgr::requestFriendPage() {
    const QJsonObject request{
        {"request_id", _friendRequestId}, {"after_uid", _friendCursor}
    };
    if (!sendSmallJson(ID_FRIEND_LIST_REQ, request)) {
        failFriendSync("联系人请求提交失败；旧列表未变");
        return;
    }
    _friendTimer.start();
}

void TcpMgr::failFriendSync(const QString &reason) {
    if (!_friendSyncBusy) return;
    _friendTimer.stop();
    _friendStaging.clear();
    _friendRequestId.clear();
    _friendSyncAgain = false;
    _friendSyncBusy = false;
    emit friendSyncBusyChanged();
    emit chatError(reason);
}

void TcpMgr::onFriendPage(const QByteArray &data) {
    if (!_chatReady || !_friendSyncBusy) return;
    QJsonParseError parseError;
    const auto doc = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        failFriendSync("联系人回包格式错误");
        return;
    }
    const auto root = doc.object();
    // 迟到的上一轮回包不能污染这一轮。
    if (root["request_id"].toString() != _friendRequestId ||
        root["after_uid"].toInt(-1) != _friendCursor) return;
    if (root["error"].toInt(-1) != 0) {
        failFriendSync("联系人查询失败：" + QString::number(root["error"].toInt(-1)));
        return;
    }
    if (!root["friend_list"].isArray() || !root["has_more"].isBool()) {
        failFriendSync("联系人分页字段错误");
        return;
    }
    QVariantList rows;
    int last = _friendCursor;
    for (const auto &v : root["friend_list"].toArray()) {
        if (!v.isObject()) { failFriendSync("联系人条目错误"); return; }
        const auto o = v.toObject();
        const int uid = o["uid"].toInt(-1);
        if (uid <= last || !o["name"].isString() || !o["nick"].isString() ||
            !o["icon"].isString() || !o["remark"].isString()) {
            failFriendSync("联系人字段或游标错误");
            return;
        }
        last = uid;
        rows.append(o.toVariantMap());
    }
    const bool more = root["has_more"].toBool();
    if (root["next_uid"].toInt(-1) != last || (more && last <= _friendCursor)) {
        failFriendSync("联系人分页未前进");
        return;
    }
    _friendTimer.stop();
    _friendStaging.append(rows);
    _friendCursor = last;
    if (more) {
        requestFriendPage();
        return;
    }
    _chatStore->replaceFriends(_friendStaging);
    _friendStaging.clear();
    _friendSyncBusy = false;
    emit friendSyncBusyChanged();
    const bool again = _friendSyncAgain;
    _friendSyncAgain = false;
    if (again) refreshFriends();
}

QString TcpMgr::sendTextMessage(int toUid, const QString &text) {
    const QString content = text.trimmed();
    if (!_chatReady || !_chatStore->hasFriend(toUid) ||
        toUid == UserMgr::GetInstance()->GetUid()) {
        emit chatError("未登录或未选择有效好友");
        return {};
    }
    if (content.isEmpty() || content.toUtf8().size() > 512) {
        emit chatError("正文需为 1～512 个 UTF-8 字节");
        return {};
    }
    if (_pendingTexts.size() >= 32) {
        emit chatError("待确认消息过多，请稍后再发");
        return {};
    }
    const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    QJsonArray array;
    array.append(QJsonObject{{"msgid", id}, {"content", content}});
    const QJsonObject request{{"touid", toUid}, {"text_array", array}};
    if (QJsonDocument(request).toJson(QJsonDocument::Compact).size() > 1800) {
        emit chatError("转义后的消息包过大");
        return {};
    }

    _chatStore->appendOutgoing(toUid, id, content);
    _pendingTexts.insert(id, toUid);
    if (!sendSmallJson(ID_TEXT_CHAT_MSG_REQ, request)) {
        _pendingTexts.remove(id);
        _chatStore->mark(toUid, id, "unknown");
        emit chatError("发送未确认，请勿自动重发");
        return id;
    }
    QTimer::singleShot(10000, this, [this, id] {
        auto it = _pendingTexts.find(id);
        if (it == _pendingTexts.end()) return;
        const int peer = it.value();
        _pendingTexts.erase(it);
        _chatStore->mark(peer, id, "unknown");
        emit chatError("消息回包超时，结果未知");
    });
    return id;
}

void TcpMgr::onTextReply(const QByteArray &data) {
    if (!_chatReady) return;
    const auto doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) return; // 关联不到请求，保留 pending 等超时
    const auto root = doc.object();
    const QString id = root["msgid"].toString();
    auto it = _pendingTexts.find(id);
    if (it == _pendingTexts.end()) return;
    const int peer = it.value();
    if (root["fromuid"].toInt() != UserMgr::GetInstance()->GetUid() ||
        root["touid"].toInt() != peer) return;
    _pendingTexts.erase(it);
    const int error = root["error"].toInt(-1);
    const QString state = error == 0 ? "forward_attempted"
                          : (error == 1101 || error == 1102 || error == 1103) ? "failed" : "unknown";
    _chatStore->mark(peer, id, state);
    if (error != 0) emit chatError("消息处理结果：" + QString::number(error));
}

void TcpMgr::onTextNotify(const QByteArray &data) {
    if (!_chatReady || data.size() > 1800) return;
    const auto doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) return;
    const auto root = doc.object();
    if (root["error"].toInt(-1) != 0 ||
        root["touid"].toInt() != UserMgr::GetInstance()->GetUid() ||
        !root["text_array"].isArray()) return;
    const int sender = root["fromuid"].toInt();
    const auto array = root["text_array"].toArray();
    if (sender <= 0 || sender == UserMgr::GetInstance()->GetUid() || array.size() != 1)
        return;
    const auto item = array.first().toObject();
    const QString id = item["msgid"].toString();
    const QString content = item["content"].toString();
    if (id.size() != 36 || QUuid(id).isNull() ||
        content.isEmpty() || content.toUtf8().size() > 512) return;
    _chatStore->appendIncoming(sender, id, content);
    if (!_chatStore->hasFriend(sender)) refreshFriends();
}
