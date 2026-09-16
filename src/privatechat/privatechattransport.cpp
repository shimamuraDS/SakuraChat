#include "privatechattransport.h"
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QSet>
#include <QUuid>

PrivateChatTransport::PrivateChatTransport(QObject *parent) : QObject(parent) {}
bool PrivateChatTransport::beginSession(int uid, const QString &token, const QUrl &gateway) {
    endSession();
    const bool local = gateway.host() == "localhost" || gateway.host() == "127.0.0.1" || gateway.host() == "::1";
    if (uid <= 0 || token.size() != 64 || !gateway.isValid() || gateway.host().isEmpty()
        || !gateway.userInfo().isEmpty() || gateway.hasQuery() || gateway.hasFragment()
        || (gateway.scheme() != "https" && !(gateway.scheme() == "http" && local))) return false;
    uid_ = uid; token_ = token; endpoint_ = gateway;
    endpoint_.setPath("/private/v1"); return true;
}
void PrivateChatTransport::endSession() {
    ++generation_;
    if (pending_) { pending_->abort(); pending_->deleteLater(); pending_.clear(); }
    uid_ = 0; token_.clear(); endpoint_.clear();
}
bool PrivateChatTransport::submit(const QJsonObject &command) {
    if (!uid_ || pending_) return false;
    const auto id = command["request_id"].toString();
    if (QUuid(id).isNull() || id.size() != 36 || !command["identity"].isArray()) return false;
    const auto op = command["op"].toString();
    QSet<QString> allowed{"op", "request_id", "identity"};
    if (op == "register" || op == "poll") {}
    else if (op == "publish") {
        allowed.insert("bundle");
        const auto bundle = command["bundle"].toObject();
        const QSet<QString> publicFields{"registration", "id", "identity", "prekey", "signed", "signature", "kyber", "kyber_signature"};
        if (bundle.size() != publicFields.size()) return false;
        for (auto it = bundle.begin(); it != bundle.end(); ++it) if (!publicFields.contains(it.key())) return false;
    } else if (op == "identity" || op == "claim") allowed.insert("peer");
    else if (op == "send") {
        allowed.unite({"peer", "peer_identity", "id", "kind", "ciphertext"});
        if (!command["ciphertext"].isString()) return false;
    } else if (op == "ack") allowed.insert("sequence");
    else return false;
    for (auto it = command.begin(); it != command.end(); ++it) if (!allowed.contains(it.key())) return false;
    QJsonObject request = command; request["uid"] = uid_; request["token"] = token_;
    const auto data = QJsonDocument(request).toJson(QJsonDocument::Compact);
    if (data.size() > 96 * 1024) return false;
    QNetworkRequest http(endpoint_);
    http.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    http.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    http.setTransferTimeout(10000);
    auto *reply = network_.post(http, data); pending_ = reply;
    const auto generation = generation_;
    reply->setReadBufferSize(100 * 1024);
    auto buffer = std::make_shared<QByteArray>();
    connect(reply, &QIODevice::readyRead, this, [reply, buffer] {
        buffer->append(reply->readAll());
        if (buffer->size() > 96 * 1024) reply->abort();
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, id, generation, buffer] {
        reply->deleteLater();
        if (generation != generation_) return;
        pending_.clear(); buffer->append(reply->readAll());
        QJsonObject response{{"error", 1206}};
        if (reply->error() == QNetworkReply::NoError && reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() == 200
            && buffer->size() <= 96 * 1024) {
            const auto parsed = QJsonDocument::fromJson(*buffer).object();
            if (parsed["request_id"].toString() == id && parsed["error"].isDouble()) response = parsed;
        }
        emit finished(id, response);
    });
    return true;
}
