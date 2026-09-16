#include "tcpmgr.h"
#include "applock.h"
#include "usermgr.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QGuiApplication>
#include <QUuid>
#include <QDateTime>
#include "configmanager.h"

TcpMgr::TcpMgr() : _host(""), _port(0), _b_recv_pending(false), _message_id(0), _message_len(0) {
    _chatStore = new ChatStore(this);
    connect(_chatStore, &ChatStore::storageError, this, &TcpMgr::chatError);
    connect(_chatStore, &ChatStore::conversationOpened, this, [this](int uid) { queueHistory(uid); pumpSync(); });
    _syncTimer.setInterval(500);
    connect(&_syncTimer, &QTimer::timeout, this, &TcpMgr::pumpSync);
    _friendTimer.setSingleShot(true);
    _friendTimer.setInterval(5000);
    connect(&_friendTimer, &QTimer::timeout, this, [this] {
        failFriendSync("联系人加载较慢，请稍后刷新");
    });

    QObject::connect(&_socket, &QTcpSocket::connected, [&]() {
        if (ConfigManager::instance().development()) emit sig_con_success(true);
    });
    connect(&_socket, &QSslSocket::encrypted, this, [this] { emit sig_con_success(true); });

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
                emit chatError("连接出现异常，请重新登录");
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
    _handlers.insert(ID_MESSAGE_DELETE_RSP, [this](ReqId, int, const QByteArray &data) {
        if (!_chatReady || _deleteRequest.isEmpty()) return;
        const auto r = QJsonDocument::fromJson(data).object();
        if (r["request_id"].toString() != _deleteRequest) return;
        if (r["error"].toInt(-1) == 0 && (r["message_id"].toString() != _deleteServerId ||
            !r["for_everyone"].isBool() || r["for_everyone"].toBool() != _deleteEveryone)) return;
        _deleteRequest.clear(); emit deletionPendingChanged();
        if (r["error"].toInt(-1) != 0) {
            emit deletionFinished(false, tr("暂时无法删除，请确认消息权限或稍后重试")); return;
        }
        const bool saved = _chatStore->repository().hideDeletedMessage(_deleteSender, _deleteClientId, _deleteServerId);
        if (_syncKind == ID_MESSAGE_RECEIPT_REQ && _receiptId == _deleteServerId) _syncRequest.clear();
        _pendingTexts.remove(_deleteClientId); _pendingAttempts.remove(_deleteClientId);
        _nextDeletionPoll = 0;
        _chatStore->refresh();
        emit deletionFinished(saved, saved ? tr("消息已删除") : tr("服务器已确认删除，但本地缓存处理失败，请保留缓存并重新登录同步"));
        pumpSync();
    });
    _handlers.insert(ID_PRIVACY_RSP, [this](ReqId, int, const QByteArray &data) {
        if (!_chatReady || _privacyRequest.isEmpty()) return;
        const auto r = QJsonDocument::fromJson(data).object();
        if (r["request_id"].toString() != _privacyRequest) return;
        _privacyRequest.clear();
        if (r["error"].toInt(-1) == 0) _privacy = r.toVariantMap();
        else emit chatError(tr("隐私设置暂不可用，请稍后重试"));
        emit privacyChanged();
    });
    for (ReqId id : {ID_CHAT_HISTORY_RSP, ID_MESSAGE_RECEIPT_RSP, ID_MESSAGE_STATUS_RSP, ID_CONVERSATION_LIST_RSP, ID_DELETION_EVENTS_RSP})
        _handlers.insert(id, [this](ReqId, int, const QByteArray &data) { onSyncReply(data); });
    _handlers.insert(ID_CHAT_LOGIN_RSP, [this](ReqId id, int len, const QByteArray &data) {
        Q_UNUSED(len);
        qDebug() << "Login response type" << id;
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

        if (jsonObj["uid"].toInt() != _connectingUid || jsonObj["chat_protocol_version"].toInt() < 2) {
            emit chatError("聊天服务版本不兼容，请先更新服务器");
            emit sig_login_failed(ErrorCodes::ERR_NETWORK);
            _socket.abort();
            return;
        }
        UserMgr::GetInstance()->SetName(jsonObj["name"].toString());
        UserMgr::GetInstance()->SetUid(jsonObj["uid"].toInt());
        UserMgr::GetInstance()->SetToken(_connectingToken);

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

        if (!_chatStore->beginAccount(UserMgr::GetInstance()->GetUid(), UserMgr::GetInstance()->GetName(),
                                     ConfigManager::instance().gateUrlPrefix())) {
            emit sig_login_failed(ErrorCodes::ERR_NETWORK);
            _socket.abort();
            return;
        }
        _chatReady = true;
        emit chatReadyChanged();
        _syncTimer.start();
        _nextSweep = 0;
        refreshFriends();
        emit sessionAuthenticated(_connectingUid, _connectingToken);
        emit sig_switch_chatlg();
        pumpSync();
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
    ++_sessionGeneration;
    _intentionalDisconnect = true;
    handleTransportLoss();
    _chatStore->endAccount();
    qDebug() << "receive tcp connect signal";
    qDebug() << "connecting to server...";

    // 如果当前socket已经连接或者正在连接，先关闭并重置
    if (_socket.state() != QAbstractSocket::UnconnectedState) {
        _socket.abort();
    }

    _host = si.Host;
    _connectingUid = si.Uid;
    _connectingToken = si.Token;
    _intentionalDisconnect = false;
    _port = static_cast<uint16_t>(si.Port.toUInt());
    if (ConfigManager::instance().development()) {
        if (si.Host != "127.0.0.1" && si.Host != "localhost" && si.Host != "::1") {
            emit sig_con_success(false);
            return;
        }
        _socket.connectToHost(si.Host, _port);
    } else {
        _socket.setSslConfiguration(ConfigManager::instance().tlsConfiguration());
        _socket.connectToHostEncrypted(si.Host, _port);
    }
}

void TcpMgr::slot_send_data(ReqId reqId, QString data) {
    const auto id = static_cast<quint16>(reqId);
    QByteArray dataBytes = data.toUtf8();
    if (dataBytes.isEmpty() || dataBytes.size() > 2048 ||
        (!ConfigManager::instance().development() && !_socket.isEncrypted())) return;
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
    resetSync();
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
    _pendingAttempts.clear();
    _chatStore->disconnectPending();
    resetBusinessPending(); // 上一课已有定义，现在实际接入
    _buffer.clear();
    _b_recv_pending = false;
    if (wasReady && !_intentionalDisconnect) emit chatError("连接已断开，请重新登录。聊天记录已保存在本机");
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
        emit chatError("连接尚未就绪，请稍后重试");
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
        failFriendSync("暂时无法加载联系人，请稍后刷新");
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
    qWarning() << "Contact synchronization:" << reason;
    emit chatError("暂时无法加载联系人，请稍后刷新");
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
    if (content.isEmpty()) return {};
    if (!_chatReady) { emit chatError(tr("连接尚未就绪，请重新登录后发送")); return {}; }
    if (!_chatStore->hasFriend(toUid) || toUid == _chatStore->selfUid()) {
        emit chatError(tr("请先选择一个有效联系人")); return {};
    }
    if (content.toUtf8().size() > 512 ||
        QJsonDocument(QJsonObject{{"content",content}}).toJson(QJsonDocument::Compact).size() > 850) {
        emit chatError(tr("消息太长，请分成几条发送")); return {};
    }
    if (_pendingTexts.size() >= 32) { emit chatError(tr("消息正在发送，请稍候")); return {}; }
    const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    if (!_chatStore->appendOutgoing(toUid, id, content)) return {};
    submitText(toUid, id, content);
    return id;
}

void TcpMgr::submitText(int peer, const QString &id, const QString &text) {
    const auto generation = _sessionGeneration;
    const auto attempt = ++_attemptCounter;
    _pendingTexts.insert(id, peer); _pendingAttempts.insert(id, attempt);
    QJsonArray array; array.append(QJsonObject{{"msgid",id},{"content",text}});
    if (!sendSmallJson(ID_TEXT_CHAT_MSG_REQ, {{"touid",peer},{"text_array",array}})) {
        _pendingTexts.remove(id); _pendingAttempts.remove(id);
        _chatStore->mark(peer, id, "unknown");
        emit chatError(tr("暂时无法确认发送结果，消息已保存在本机"));
        return;
    }
    QTimer::singleShot(10000, this, [this, generation, attempt, id, peer] {
        if (generation != _sessionGeneration || _pendingAttempts.value(id) != attempt) return;
        _pendingTexts.remove(id); _pendingAttempts.remove(id);
        _chatStore->mark(peer, id, "unknown");
        _nextStatePoll = 0;
    });
}

void TcpMgr::retryTextMessage(int peer, const QString &id) {
    if (!_chatReady) { emit chatError(tr("连接已断开，请重新登录后重试")); return; }
    if (_pendingTexts.contains(id) || _pendingTexts.size() >= 32) return;
    const auto m = _chatStore->repository().find(_chatStore->selfUid(), id);
    if (m.isEmpty() || m.value("peerUid").toInt() != peer) return;
    const auto state = m.value("status").toString();
    if (state != "failed" && state != "unknown") return;
    // Reuse both the original UUID and content; the server enforces idempotency.
    if (_chatStore->mark(peer, id, "pending")) submitText(peer, id, m.value("messageText").toString());
}

void TcpMgr::onTextReply(const QByteArray &data) {
    if (!_chatReady) return;
    const auto doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) return;
    const auto root = doc.object(); const auto id = root["msgid"].toString();
    const auto local = _chatStore->repository().find(_chatStore->selfUid(), id);
    if (local.isEmpty() || root["fromuid"].toInt() != _chatStore->selfUid() ||
        root["touid"].toInt() != local.value("peerUid").toInt()) return;
    // A late acknowledgement remains useful even after the request timer expired.
    const int error = root["error"].toInt(-1);
    if (error == 0) {
        if (!_chatStore->mergeServer(root)) return;
    } else {
        const bool rejected = error == 1101 || error == 1103;
        _chatStore->mark(local.value("peerUid").toInt(), id, rejected ? "failed" : "unknown");
        qWarning() << "Message response" << error << id;
        if (error == 1101) emit chatError(tr("暂时无法发送，请确认好友关系"));
        else if (error == 1103) emit chatError(tr("消息内容不符合要求，请缩短或调整后发送"));
        else emit chatError(tr("正在确认发送结果，请稍后查看消息状态"));
    }
    _pendingTexts.remove(id); _pendingAttempts.remove(id);
}

void TcpMgr::onTextNotify(const QByteArray &data) {
    if (!_chatReady || data.size() > 1800) return;
    const auto doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) return;
    const auto root = doc.object();
    if (root["error"].toInt(-1) != 0 || !root["message"].isObject()) return;
    const auto message = root["message"].toObject();
    if (message["touid"].toInt() != _chatStore->selfUid()) return;
    const int source = message["fromuid"].toInt();
    const auto clientId = message["msgid"].toString();
    const bool known = !_chatStore->repository().find(source, clientId).isEmpty() ||
                       _chatStore->repository().isDeleted(source, clientId);
    if (_chatStore->mergeServer(message)) {
        if (!known && message["message_status"].toInt(-1) == 0 && _chatStore->ready()) emit newPrivateMessage();
        const int sender = message["fromuid"].toInt();
        queueHistory(sender); // Never advance a history cursor from a live notification.
        if (!_chatStore->hasFriend(sender)) refreshFriends();
        pumpSync();
    }
}

void TcpMgr::logout() {
    ++_sessionGeneration; _intentionalDisconnect = true; _conversationVisible = false;
    if (_chatReady && sendSmallJson(ID_LOGOUT_REQ, {})) _socket.disconnectFromHost();
    else _socket.abort();
    handleTransportLoss(); _chatStore->endAccount();
    _friendApplySnapshot.clear(); emit friendApplySnapshotChanged();
    auto user = UserMgr::GetInstance(); user->SetUid(0); user->SetName({}); user->SetToken({});
    _connectingUid = 0; _connectingToken.clear(); emit loggedOut();
    _intentionalDisconnect = false;
}
void TcpMgr::setConversationVisible(bool visible) { _conversationVisible = visible; }
void TcpMgr::markMessageRead(const QString &id) {
    if (AppLock::instance().locked()) return;
    if (!_chatReady || !_conversationVisible || QGuiApplication::applicationState() != Qt::ApplicationActive) return;
    if (_chatStore->markRead(id)) pumpSync();
}
void TcpMgr::resetSync() {
    if (!_deleteRequest.isEmpty()) {
        _deleteRequest.clear(); emit deletionPendingChanged();
        emit deletionFinished(false, tr("连接已中断，删除结果尚未确认；重新登录后将同步最终状态"));
    }
    _nextDeletionPoll = 0;
    _privacyRequest.clear(); _privacy.clear(); emit privacyChanged();
    _syncTimer.stop(); _syncRequest.clear(); _historyQueue.clear(); _queuedPeers.clear();
    _listing = false; _conversationCursor = "0"; _nextSweep = 0; _statusOffset = 0;
    _nextStatePoll = 0; _retrySyncAt = 0; _receiptRetryAt = 0; _queriedIds.clear();
}

void TcpMgr::privacyCommand(const QVariantMap &command) {
    if (!_chatReady || !_privacyRequest.isEmpty()) return;
    _privacyRequest = QUuid::createUuid().toString(QUuid::WithoutBraces);
    auto request = QJsonObject::fromVariantMap(command);
    request["request_id"] = _privacyRequest;
    const auto id = _privacyRequest;
    const auto generation = _sessionGeneration;
    emit privacyChanged();
    if (!sendSmallJson(ID_PRIVACY_REQ, request)) {
        _privacyRequest.clear(); emit privacyChanged(); return;
    }
    QTimer::singleShot(8000, this, [this, id, generation] {
        if (generation != _sessionGeneration || _privacyRequest != id) return;
        _privacyRequest.clear(); emit privacyChanged();
        emit chatError(tr("隐私设置请求超时，请重新打开页面确认结果"));
    });
}
void TcpMgr::queueHistory(int peer) {
    if (peer <= 0 || peer == _chatStore->selfUid() || _queuedPeers.contains(peer)) return;
    _queuedPeers.insert(peer); _historyQueue.enqueue(peer);
}
void TcpMgr::deleteMessage(const QString &messageId, bool everyone) {
    if (AppLock::instance().locked() || !_deleteRequest.isEmpty()) return;
    if (!_chatReady || !_chatStore->ready()) { emit deletionFinished(false, tr("请连接服务器后再删除")); return; }
    bool valid = false; const auto numeric = messageId.toULongLong(&valid);
    const auto m = _chatStore->repository().findServer(messageId);
    if (!valid || !numeric || m.isEmpty() || (everyone && m.value("senderUid").toInt() != _chatStore->selfUid())) {
        emit deletionFinished(false, tr("消息已不可用，或没有对双方删除的权限")); return;
    }
    _deleteServerId = messageId; _deleteClientId = m.value("msgid").toString();
    _deleteSender = m.value("senderUid").toInt(); _deleteEveryone = everyone;
    _deleteRequest = QUuid::createUuid().toString(QUuid::WithoutBraces);
    const auto request = _deleteRequest; const auto generation = _sessionGeneration;
    emit deletionPendingChanged();
    if (!sendSmallJson(ID_MESSAGE_DELETE_REQ, {{"request_id",request},{"message_id",messageId},{"for_everyone",everyone}})) {
        _deleteRequest.clear(); emit deletionPendingChanged();
        emit deletionFinished(false, tr("删除请求未能发出，请检查连接后重试")); return;
    }
    QTimer::singleShot(8000, this, [this, request, generation] {
        if (generation != _sessionGeneration || _deleteRequest != request) return;
        _deleteRequest.clear(); emit deletionPendingChanged(); _nextDeletionPoll = 0;
        emit deletionFinished(false, tr("删除结果尚未确认，正在同步；可稍后重试，请勿视为未删除"));
    });
}

void TcpMgr::pumpSync() {
    if (!_chatReady || !_chatStore->ready()) return;
    const auto now = QDateTime::currentMSecsSinceEpoch();
    if (!_syncRequest.isEmpty()) {
        if (now < _syncDeadline) return;
        if (_syncKind == ID_CHAT_HISTORY_REQ) queueHistory(_syncPeer);
        if (_syncKind == ID_MESSAGE_RECEIPT_REQ) _receiptRetryAt = now + 30000;
        _syncRequest.clear(); _retrySyncAt = now + 2000;
    }
    if (now < _retrySyncAt) return;
    QJsonObject request;
    const auto receipts = _chatStore->repository().receipts();
    if (now >= _nextDeletionPoll) {
        _syncKind = ID_DELETION_EVENTS_REQ;
        _syncCursor = _chatStore->repository().cursor(0);
        request = {{"after_event",_syncCursor}};
        _nextDeletionPoll = now + 10000;
    } else if (!receipts.isEmpty() && now >= _receiptRetryAt) {
        const auto r = receipts.first().toMap();
        _receiptId = r.value("id").toString();
        _syncKind = ID_MESSAGE_RECEIPT_REQ;
        request = {{"message_id",r.value("id").toString()},
                   {"receipt",r.value("status").toInt() == 1 ? "read" : "delivered"}};
    } else if (!_historyQueue.isEmpty()) {
        _syncKind = ID_CHAT_HISTORY_REQ;
        _syncPeer = _historyQueue.dequeue(); _queuedPeers.remove(_syncPeer);
        _syncCursor = _chatStore->repository().cursor(_syncPeer);
        request = {{"peer_uid",_syncPeer},{"after_seq",_syncCursor}};
    } else if (_listing || now >= _nextSweep) {
        if (!_listing) { _listing = true; _conversationCursor = "0"; }
        _syncKind = ID_CONVERSATION_LIST_REQ;
        request = {{"after_thread",_conversationCursor}};
    } else if (now >= _nextStatePoll && QGuiApplication::applicationState() == Qt::ApplicationActive) {
        _nextStatePoll = now + 2000;
        _queriedIds = _chatStore->repository().statusIds(_statusOffset);
        if (_queriedIds.isEmpty()) { _statusOffset = 0; _queriedIds = _chatStore->repository().statusIds(0); }
        if (_queriedIds.isEmpty()) return;
        _syncKind = ID_MESSAGE_STATUS_REQ;
        QJsonArray ids; for (const auto &id : _queriedIds) ids.append(id);
        request = {{"msgids",ids}};
    } else return;
    _syncRequest = QUuid::createUuid().toString(QUuid::WithoutBraces);
    request["request_id"] = _syncRequest; _syncDeadline = now + 8000;
    if (!sendSmallJson(_syncKind, request)) {
        if (_syncKind == ID_CHAT_HISTORY_REQ) queueHistory(_syncPeer);
        if (_syncKind == ID_MESSAGE_RECEIPT_REQ) _receiptRetryAt = now + 30000;
        _syncRequest.clear(); _retrySyncAt = now + 2000;
    }
}

void TcpMgr::onSyncReply(const QByteArray &data) {
    if (!_chatReady || _syncRequest.isEmpty() || data.size() > 1800) return;
    const auto doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) return;
    const auto r = doc.object();
    if (r["request_id"].toString() != _syncRequest) return;
    const auto kind = _syncKind;
    _syncRequest.clear();
    auto failed = [this, kind] {
        if (kind == ID_CHAT_HISTORY_REQ) queueHistory(_syncPeer);
        // Keep the durable receipt for retry without starving history/status sync.
        if (kind == ID_MESSAGE_RECEIPT_REQ)
            _receiptRetryAt = QDateTime::currentMSecsSinceEpoch() + 30000;
        _retrySyncAt = QDateTime::currentMSecsSinceEpoch() + 5000;
        emit chatError(tr("聊天记录暂时无法同步，稍后将自动重试"));
    };
    if (r["error"].toInt(-1) != 0) { failed(); return; }
    auto &repo = _chatStore->repository();
    if (kind == ID_DELETION_EVENTS_REQ) {
        if (!r["items"].isArray() || !r["has_more"].isBool() || r["after_event"].toString() != _syncCursor ||
            (r["has_more"].toBool() && r["next_event"].toString().toULongLong() <= _syncCursor.toULongLong()) ||
            !repo.applyDeletions(r["items"].toArray().toVariantList(), r["next_event"].toString())) { failed(); return; }
        if (r["has_more"].toBool()) _nextDeletionPoll = 0;
        _chatStore->refresh();
    } else if (kind == ID_CHAT_HISTORY_REQ) {
        if (r["peer_uid"].toInt() != _syncPeer || r["after_seq"].toString() != _syncCursor ||
            !r["messages"].isArray() || !r["has_more"].isBool()) { failed(); return; }
        auto last = _syncCursor.toULongLong();
        for (const auto &v : r["messages"].toArray()) {
            const auto m = v.toObject(); bool ok = false;
            const auto seq = m["seq"].toString().toULongLong(&ok);
            const int peer = m["fromuid"].toInt() == _chatStore->selfUid() ? m["touid"].toInt() : m["fromuid"].toInt();
            if (!ok || seq <= last || peer != _syncPeer || !_chatStore->mergeServer(m)) { failed(); return; }
            last = seq;
        }
        bool cursorOk = false;
        const auto next = r["next_seq"].toString().toULongLong(&cursorOk);
        if (!cursorOk || next != last || (r["has_more"].toBool() && next <= _syncCursor.toULongLong()) ||
            !repo.setCursor(_syncPeer, r["next_seq"].toString())) { failed(); return; }
        if (r["has_more"].toBool()) queueHistory(_syncPeer);
    } else if (kind == ID_CONVERSATION_LIST_REQ) {
        if (!r["items"].isArray() || !r["has_more"].isBool() || r["after_thread"].toString() != _conversationCursor) { failed(); return; }
        auto last = _conversationCursor.toULongLong();
        for (const auto &v : r["items"].toArray()) {
            auto item = v.toObject(); bool ok = false;
            const auto thread = item["thread_id"].toString().toULongLong(&ok);
            const int peer = item["peer_uid"].toInt();
            if (!ok || thread <= last || peer <= 0 || peer == _chatStore->selfUid()) { failed(); return; }
            last = thread;
            bool seqOk = false;
            const auto lastSeq = item["last_seq"].toString().toULongLong(&seqOk);
            if (!seqOk) { failed(); return; }
            if (lastSeq > repo.cursor(peer).toULongLong()) queueHistory(peer);
        }
        bool ok = false; auto next = r["next_thread"].toString().toULongLong(&ok);
        if (!ok || next != last || (r["has_more"].toBool() && next <= _conversationCursor.toULongLong())) { failed(); return; }
        _conversationCursor = r["next_thread"].toString();
        _listing = r["has_more"].toBool();
        if (!_listing) _nextSweep = QDateTime::currentMSecsSinceEpoch() + 10000;
    } else if (kind == ID_MESSAGE_RECEIPT_REQ) {
        const auto state = r["state"].toString();
        if (r["message_id"].toString() != _receiptId || (state != "delivered" && state != "read") ||
            !repo.acknowledgeReceipt(r["message_id"].toString(), state == "read" ? 1 : 0, r["read_suppressed"].toBool())) { failed(); return; }
        _chatStore->refresh();
    } else if (kind == ID_MESSAGE_STATUS_REQ) {
        if (!r["items"].isArray()) { failed(); return; }
        for (const auto &v : r["items"].toArray()) {
            const auto m = v.toObject();
            if (!_queriedIds.contains(m["msgid"].toString())) { failed(); return; }
            if (m["state"].toString() == "not_found") continue;
            if (!_chatStore->mergeServer(m)) { failed(); return; }
            _pendingTexts.remove(m["msgid"].toString()); _pendingAttempts.remove(m["msgid"].toString());
        }
        _statusOffset += _queriedIds.size();
    }
    const auto generation = _sessionGeneration;
    QTimer::singleShot(25, this, [this, generation] { if (generation == _sessionGeneration) pumpSync(); });
}
