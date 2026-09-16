#include "privatechatengine.h"
#include <QJsonArray>
#include <QJsonDocument>
#include <QCryptographicHash>
#include <QStandardPaths>
#include <QDir>
#include <QUuid>
#include <QDateTime>

namespace {
QJsonArray bytes(const QByteArray &data) { QJsonArray result; for (auto c : data) result.append(static_cast<unsigned char>(c)); return result; }
QByteArray binary(const QJsonArray &array) { QByteArray result; for (const auto &value : array) result.append(char(value.toInt())); return result; }
}
QJsonObject PrivateChatEngine::protocol(QJsonObject request) {
    if (!bridge_) return {};
    if (request["op"] != "create" && !request.contains("state")) {
        auto state = store_.state(); if (state.isEmpty()) return {};
        request["state"] = state;
    }
    return QJsonDocument::fromJson(bridge_->execute(QJsonDocument(request).toJson(QJsonDocument::Compact))).object();
}
QJsonObject PrivateChatEngine::execute(const QJsonObject &command) {
    const auto op = command["op"].toString();
    QJsonObject result{{"ok", false}};
    if (op == "close") { store_.close(); self_ = 0; bridge_.reset(); return {{"ok", true}}; }
    if (op == "open") {
        store_.close(); self_ = 0; bridge_.reset();
        const int uid = command["uid"].toInt();
        if (uid <= 0) return result;
        bridge_ = std::make_unique<SignalBridge>();
        if (!bridge_->available()) return {{"ok", false}, {"error", "bridge"}};
        const auto scope = command["scope"].toString();
        const auto directory = storageDirectory_.isEmpty()
            ? QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) + "/private-chat/"
            : QDir(storageDirectory_).absolutePath() + "/";
        if (!QDir().mkpath(directory)) return result;
        const auto hash = QString::fromLatin1(QCryptographicHash::hash(scope.toUtf8(), QCryptographicHash::Sha256).toHex());
        if (!store_.open(directory + hash + "-" + QString::number(uid) + ".db", QString::number(uid), scope)) return result;
        if (!store_.initialized()) {
            const auto created = protocol({{"op", "create"}, {"account", QString::number(uid)}});
            if (!store_.commit(created["state"].toObject())) return result;
        }
        // The bridge derives the public identity without exposing the private state to the controller.
        const auto state = store_.state();
        auto publicKey = protocol({{"op", "public_identity"}});
        if (publicKey.isEmpty()) return result;
        self_ = uid;
        return {{"ok", true}, {"identity", publicKey["identity"]}, {"bundles", state["published_bundles"]}};
    }
    if (!self_) return result;
    const auto peer = command["peer"].toInt();
    if (op == "history") return {{"ok", true}, {"messages", store_.messages(peer)}};
    if (op == "pending") return {{"ok", true}, {"outbox", store_.pending()}};
    if (op == "ack") return {{"ok", store_.acknowledge(command["id"].toString())}};
    if (op == "bundle") {
        const auto state = store_.state();
        if (!state["pending_bundle"].toObject().isEmpty()) return {{"ok", true}, {"bundle", state["pending_bundle"]}};
        auto generated = protocol({{"op", "bundle"}});
        auto next = generated["state"].toObject();
        if (next.isEmpty()) return result;
        next["pending_bundle"] = generated["bundle"];
        if (!store_.commit(next)) return result;
        return {{"ok", true}, {"bundle", generated["bundle"]}};
    }
    if (op == "published") {
        auto state = store_.state(); if (state.isEmpty()) return result;
        state.remove("pending_bundle"); state["published_bundles"] = state["published_bundles"].toInt() + 1;
        return {{"ok", store_.commit(state)}};
    }
    if (op == "safety_number" || op == "approve" || op == "first_trust" || op == "establish") {
        auto request = command; request["peer"] = QString::number(peer);
        auto response = protocol(request);
        if (response.isEmpty()) return result;
        if (op != "safety_number" && !store_.commit(response["state"].toObject())) return result;
        return {{"ok", true}, {"safety_number", response["safety_number"]}, {"has_session", response["has_session"]},
                {"identity_changed", response["identity_changed"]}, {"verified", response["verified"]}};
    }
    if (op == "send") {
        const auto text = command["text"].toString();
        if (peer <= 0 || peer == self_ || text.trimmed().isEmpty() || text.toUtf8().size() > 4000) return result;
        const auto id = QUuid::createUuid().toString(QUuid::WithoutBraces);
        const QJsonObject payload{{"version", 1}, {"id", id}, {"sender", self_}, {"recipient", peer}, {"text", text}};
        const auto encrypted = protocol({{"op", "encrypt"}, {"peer", QString::number(peer)}, {"plaintext", bytes(QJsonDocument(payload).toJson(QJsonDocument::Compact))}});
        if (encrypted.isEmpty()) return result;
        const QJsonValue identity = encrypted["state"].toObject()["identity"].toObject()["approved"].toObject()[QString::number(peer) + ":1"];
        QJsonObject envelope{{"id", id}, {"peer", QString::number(peer)}, {"peer_identity", identity}, {"kind", encrypted["kind"]}, {"ciphertext", encrypted["ciphertext"]}};
        QJsonObject message{{"id", id}, {"peer", peer}, {"text", text}, {"outgoing", true}, {"time", QDateTime::currentDateTime().toString("HH:mm")}};
        return {{"ok", store_.commit(encrypted["state"].toObject(), envelope, message)}};
    }
    if (op == "receive") {
        const auto envelope = command["envelope"].toObject();
        const auto sender = envelope["sender"].toInt(); const auto id = envelope["id"].toString();
        if (sender <= 0 || QUuid(id).isNull()) return result;
        if (store_.received(sender, id)) return {{"ok", true}};
        const auto decoded = QByteArray::fromBase64Encoding(envelope["ciphertext"].toString().toLatin1(), QByteArray::AbortOnBase64DecodingErrors);
        if (!decoded) return result;
        const auto trust = protocol({{"op", "first_trust"}, {"peer", QString::number(sender)}, {"identity", envelope["identity"]}});
        if (trust.isEmpty() || trust["identity_changed"].toBool()) return {{"ok", false}, {"error", "identity_changed"}};
        auto plain = protocol({{"op", "decrypt"}, {"state", trust["state"]}, {"peer", QString::number(sender)}, {"kind", envelope["kind"]}, {"ciphertext", bytes(decoded.decoded)}});
        if (plain.isEmpty()) return {{"ok", false}, {"error", "identity_or_ciphertext"}, {"peer", sender}, {"identity", envelope["identity"]}};
        const auto payload = QJsonDocument::fromJson(binary(plain["plaintext"].toArray())).object();
        if (payload["version"].toInt() != 1 || payload["id"].toString() != id || payload["sender"].toInt() != sender
            || payload["recipient"].toInt() != self_ || !payload["text"].isString()
            || payload["text"].toString().toUtf8().size() > 4000) return result;
        const QJsonObject message{{"id", id}, {"peer", sender}, {"text", payload["text"]}, {"outgoing", false}, {"time", QDateTime::currentDateTime().toString("HH:mm")}};
        return {{"ok", store_.commit(plain["state"].toObject(), {}, message)}};
    }
    return result;
}
