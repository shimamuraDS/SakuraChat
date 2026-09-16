#include "privatechatcontroller.h"
#include "privatechatengine.h"
#include <QUuid>

PrivateChatController::PrivateChatController(QObject *parent) : QObject(parent), engine_(new PrivateChatEngine) {
    engine_->moveToThread(&thread_);
    connect(&thread_, &QThread::finished, engine_, &QObject::deleteLater);
    thread_.start(); timer_.setInterval(3000);
    connect(&timer_, &QTimer::timeout, this, &PrivateChatController::tick);
    retryTimer_.setSingleShot(true);
    retryTimer_.setTimerType(Qt::PreciseTimer);
    connect(&retryTimer_, &QTimer::timeout, this, [this] { retry(); emit changed(); });
    connect(&transport_, &PrivateChatTransport::finished, this, [this](const QString &, QJsonObject response) {
        busy_ = false;
        if (response["error"].toInt(1206) != 0) {
            failedNetwork_ = pendingNetwork_; failedDone_ = std::move(networkDone_);
            const int error = response["error"].toInt(1206);
            if (error == 1202) { trusted_ = false; verified_ = false; identityChanged_ = true; }
            connectionNotice_ = error == 1202 ? tr("设备身份不一致，已停止操作。请核对安全码，不要覆盖本地密钥。")
                   : error == 1208 ? tr("本设备的预密钥存储已达上限，需要维护后才能继续；反复重试无效。")
                   : error == 1209 ? tr("对方待收消息已满，请等待对方接收后重试。")
                   : error == 1205 ? tr("对方暂无可用预密钥，请让对方打开隐私对话后重试。")
                   : error == 1104 ? tr("隐私服务存储不可用，请确认服务器已执行 006 数据库迁移。")
                   : error == 1201 ? tr("对方尚未启用隐私对话。")
                   : tr("隐私请求未完成（%1），可重试。不会改用普通消息发送。").arg(error);
            if (error == 1204 || error == 1207 || error == 1206) {
                transientFailures_ = qMin(transientFailures_ + 1, 5);
                const int delay = error == 1204 ? qBound(1, response["retry_after"].toInt(60), 3600)
                    : qMax(qBound(1, response["retry_after"].toInt(5), 60), qMin(60, 5 * (1 << (transientFailures_ - 1))));
                retryDeadline_.setRemainingTime(delay * 1000);
                if (active_) retryTimer_.start(delay * 1000);
                connectionNotice_ = error == 1204 ? tr("请求暂时受限，约 %1 秒后自动重试。安全码核验状态保持不变。").arg(delay)
                    : tr("后台连接暂不可用，约 %1 秒后自动重试。不会改用普通消息发送。").arg(delay);
            }
            emit changed();
            return;
        }
        retryTimer_.stop(); retryDeadline_.setRemainingTime(0); transientFailures_ = 0; connectionNotice_.clear();
        auto done = std::move(networkDone_); failedNetwork_ = {}; failedDone_ = {};
        if (done) done(response);
        emit changed();
    });
}
PrivateChatController::~PrivateChatController() { endSession(); thread_.quit(); thread_.wait(); }
void PrivateChatController::status(const QString &message) { notice_ = message; emit changed(); }
void PrivateChatController::beginSession(int uid, const QString &token, const QString &gateway) {
    endSession(); gateway_ = gateway;
    if (transport_.beginSession(uid, token, QUrl(gateway))) { uid_ = uid; status(tr("切换到隐私对话以启用本设备。")); }
    else status(tr("隐私对话需要 HTTPS 网关；仅本机开发允许 HTTP。"));
}
void PrivateChatController::endSession() {
    ++generation_; timer_.stop(); retryTimer_.stop(); retryDeadline_.setRemainingTime(0);
    transientFailures_ = 0; connectionNotice_.clear(); transport_.endSession();
    QMetaObject::invokeMethod(engine_, [engine = engine_] { engine->execute({{"op", "close"}}); }, Qt::QueuedConnection);
    uid_ = peer_ = 0; ready_ = busy_ = trusted_ = active_ = false; receivePaused_ = false;
    verified_ = identityChanged_ = false;
    identity_ = {}; candidate_ = {}; setMessages({}); safety_.clear(); peerName_.clear();
    failedNetwork_ = {}; pendingNetwork_ = {}; networkDone_ = {}; failedDone_ = {};
    status(tr("请先登录同一个云端账号。"));
}
void PrivateChatController::setActive(bool active) {
    if (active_ == active) return;
    active_ = active;
    if (!active) { timer_.stop(); retryTimer_.stop(); }
    else if (!retryDeadline_.hasExpired()) retryTimer_.start(static_cast<int>(retryDeadline_.remainingTime()));
    else if (!failedNetwork_.isEmpty()) { if (transientFailures_ > 0) retry(); emit changed(); return; }
    else if (uid_ && !busy_ && !ready_) boot();
    else if (ready_) timer_.start();
    emit changed();
}
void PrivateChatController::work(QJsonObject command, Done done) {
    busy_ = true; emit changed(); const auto generation = generation_;
    QMetaObject::invokeMethod(engine_, [this, command, done = std::move(done), generation] {
        QJsonObject result;
        try { result = engine_->execute(command); } catch (...) { result["ok"] = false; }
        QMetaObject::invokeMethod(this, [this, result, done, generation] {
            if (generation != generation_) return;
            busy_ = false;
            if (!result["ok"].toBool()) {
                status(result["error"] == "bridge" ? tr("未找到匹配的 libsignal 桥接库，请先运行隐私模块构建脚本。")
                       : tr("隐私操作失败：请检查本地存储、身份核验或密文完整性。消息未确认。"));
            }
            done(result); emit changed();
        }, Qt::QueuedConnection);
    }, Qt::QueuedConnection);
}
void PrivateChatController::network(QJsonObject command, Done done) {
    command["identity"] = identity_;
    if (!command.contains("request_id")) command["request_id"] = QUuid::createUuid().toString(QUuid::WithoutBraces);
    pendingNetwork_ = command; networkDone_ = std::move(done); busy_ = true; emit changed();
    if (!transport_.submit(command)) {
        busy_ = false; failedNetwork_ = command; failedDone_ = std::move(networkDone_);
        connectionNotice_ = tr("隐私请求无法发送，请检查登录状态和连接。"); emit changed();
    }
}
void PrivateChatController::boot() {
    if (!uid_ || !active_ || busy_) return;
    work({{"op", "open"}, {"uid", uid_}, {"scope", gateway_}}, [this](QJsonObject response) {
        if (!response["ok"].toBool()) return;
        identity_ = response["identity"].toArray(); published_ = response["bundles"].toInt();
        network({{"op", "register"}}, [this](QJsonObject registered) {
            if (!registered["available_prekeys"].isDouble()) {
                status(tr("隐私服务版本不匹配，请更新服务器。")); return;
            }
            published_ = registered["available_prekeys"].toInt();
            publishNext();
        });
    });
}
void PrivateChatController::publishNext() {
    if (published_ >= 10) {
        ready_ = true; if (active_) timer_.start(); status(tr("隐私设备已就绪。请选择好友开始加密聊天；安全码核验可选。")); return;
    }
    work({{"op", "bundle"}}, [this](QJsonObject response) {
        if (!response["ok"].toBool()) return;
        network({{"op", "publish"}, {"bundle", response["bundle"]}}, [this](QJsonObject published) {
            if (!published["available_prekeys"].isDouble()) {
                status(tr("隐私服务版本不匹配，请更新服务器。")); return;
            }
            published_ = published["available_prekeys"].toInt();
            work({{"op", "published"}}, [this](QJsonObject saved) { if (saved["ok"].toBool()) publishNext(); });
        });
    });
}
void PrivateChatController::setMessages(const QVariantList &messages) {
    if (messages_ == messages) return;
    messages_ = messages; emit messagesChanged();
}
void PrivateChatController::history() {
    work({{"op", "history"}, {"peer", peer_}}, [this](QJsonObject r) { setMessages(r["messages"].toArray().toVariantList()); });
}
void PrivateChatController::openPeer(int uid, const QString &name) {
    if (!ready_ || !canRetry() || uid <= 0 || uid == uid_) return;
    peer_ = uid; peerName_ = name; trusted_ = false; verified_ = identityChanged_ = false;
    candidate_ = {}; safety_.clear(); setMessages({});
    failedNetwork_ = {}; failedDone_ = {};
    work({{"op", "history"}, {"peer", peer_}}, [this](QJsonObject historyResult) {
        setMessages(historyResult["messages"].toArray().toVariantList());
        network({{"op", "identity"}, {"peer", peer_}}, [this](QJsonObject response) {
            candidate_ = response["identity"].toArray();
            work({{"op", "first_trust"}, {"peer", peer_}, {"identity", candidate_}}, [this](QJsonObject result) {
                if (!result["ok"].toBool()) return;
                safety_ = result["safety_number"].toString();
                identityChanged_ = result["identity_changed"].toBool(); verified_ = result["verified"].toBool();
                if (identityChanged_) { status(tr("对方身份密钥已变化，发送已暂停。请通过可信渠道核对新安全码。")); return; }
                establishSession(result);
            });
        });
    });
}
void PrivateChatController::approveIdentity() {
    if (!ready_ || !canRetry() || safety_.isEmpty() || candidate_.isEmpty()) return;
    work({{"op", "approve"}, {"peer", peer_}, {"identity", candidate_}}, [this](QJsonObject response) {
        if (!response["ok"].toBool()) return;
        verified_ = true; identityChanged_ = false;
        establishSession(response);
    });
}
void PrivateChatController::establishSession(QJsonObject trust) {
    receivePaused_ = false;
    if (trust["has_session"].toBool()) {
        trusted_ = true; status(verified_ ? tr("端到端加密 · 身份已核验") : tr("端到端加密 · 身份未核验")); return;
    }
    network({{"op", "claim"}, {"peer", peer_}}, [this](QJsonObject claim) {
        work({{"op", "establish"}, {"peer", peer_}, {"bundle", claim["bundle"]}}, [this](QJsonObject established) {
            trusted_ = established["ok"].toBool();
            if (trusted_) status(verified_ ? tr("端到端加密 · 身份已核验") : tr("端到端加密 · 身份未核验"));
        });
    });
}
void PrivateChatController::send(const QString &text) {
    if (!canSend()) return;
    work({{"op", "send"}, {"peer", peer_}, {"text", text}}, [this](QJsonObject response) {
        if (response["ok"].toBool()) { emit messageQueued(); history(); }
    });
}
void PrivateChatController::retry() {
    if (!canRetry()) return;
    if (!failedNetwork_.isEmpty()) { auto command = failedNetwork_; auto done = failedDone_; network(command, done); }
    else if (!ready_) boot();
    else { receivePaused_ = false; tick(); }
}
void PrivateChatController::tick() {
    if (!ready_ || busy_ || !active_ || !failedNetwork_.isEmpty()) return;
    work({{"op", "pending"}}, [this](QJsonObject pending) {
        const auto list = pending["outbox"].toArray();
        if (!list.isEmpty()) {
            auto envelope = list.first().toObject(); const auto id = envelope["id"].toString();
            QByteArray bytes; for (auto v : envelope["ciphertext"].toArray()) bytes.append(char(v.toInt()));
            envelope["ciphertext"] = QString::fromLatin1(bytes.toBase64()); envelope["peer"] = envelope["peer"].toString().toInt(); envelope["op"] = "send";
            network(envelope, [this, id](QJsonObject) { work({{"op", "ack"}, {"id", id}}, [this](QJsonObject r) { if (r["ok"].toBool() && peer_) history(); }); });
        } else if (!receivePaused_) {
            network({{"op", "poll"}}, [this](QJsonObject response) {
                if (!response["envelope"].isObject()) return;
                const auto envelope = response["envelope"].toObject();
                work({{"op", "receive"}, {"envelope", envelope}}, [this, envelope](QJsonObject received) {
                    if (!received["ok"].toBool()) {
                        receivePaused_ = true;
                        if (received["error"] == "identity_changed" && envelope["sender"].toInt() == peer_) {
                            trusted_ = false; verified_ = false; identityChanged_ = true;
                            candidate_ = {}; safety_.clear();
                        }
                        status(tr("消息验证失败（UID %1），未确认收件。若身份已变化，请重新选择该好友核对安全码。").arg(envelope["sender"].toInt()));
                        return;
                    }
                    network({{"op", "ack"}, {"sequence", envelope["sequence"]}}, [this](QJsonObject) { if (peer_) history(); });
                });
            });
        }
    });
}
