#include "privatechatstore.h"
#include "localprotection.h"
#include <QJsonArray>
#include <QJsonDocument>
#include <QSqlQuery>
#include <QUuid>

PrivateChatStore::~PrivateChatStore() { close(); }
void PrivateChatStore::close() {
    if (db_.isValid()) db_.close();
    db_ = QSqlDatabase();
    if (!connection_.isEmpty()) QSqlDatabase::removeDatabase(connection_);
    connection_.clear(); context_.clear(); baseline_.clear();
}
bool PrivateChatStore::open(const QString &path, const QString &account, const QString &serverScope) {
    close();
    if (account.isEmpty() || serverScope.isEmpty()) return false;
    context_ = QJsonDocument(QJsonArray{"sakura-private-state-v1", serverScope, account}).toJson(QJsonDocument::Compact);
    connection_ = "private-" + QUuid::createUuid().toString(QUuid::WithoutBraces);
    db_ = QSqlDatabase::addDatabase("QSQLITE", connection_);
    db_.setDatabaseName(path);
    if (!db_.open()) return false;
    QSqlQuery query(db_);
    if (!query.exec("PRAGMA synchronous=FULL")
        || !query.exec("CREATE TABLE IF NOT EXISTS protocol_state (id INTEGER PRIMARY KEY CHECK(id=1), sealed BLOB NOT NULL)")
        || !query.exec("CREATE TABLE IF NOT EXISTS outbox (id TEXT PRIMARY KEY, envelope BLOB NOT NULL)")
        || !query.exec("CREATE TABLE IF NOT EXISTS messages (peer INTEGER NOT NULL,id TEXT NOT NULL,outgoing INTEGER NOT NULL,sealed BLOB NOT NULL,PRIMARY KEY(peer,id,outgoing))")) return false;
    if (initialized() && state().isEmpty()) { close(); return false; }
    return true;
}
bool PrivateChatStore::initialized() const {
    QSqlQuery query(db_);
    return query.exec("SELECT 1 FROM protocol_state WHERE id=1") && query.next();
}
QJsonObject PrivateChatStore::state() const {
    QSqlQuery query(db_);
    if (!query.exec("SELECT sealed FROM protocol_state WHERE id=1") || !query.next()) return {};
    baseline_ = query.value(0).toByteArray();
    const auto plain = LocalProtection::unprotect(baseline_, context_);
    return QJsonDocument::fromJson(plain).object();
}
bool PrivateChatStore::commit(const QJsonObject &state, const QJsonObject &outgoing, const QJsonObject &message) {
    if (state.isEmpty() || !db_.isOpen()) return false;
    const auto sealed = LocalProtection::protect(QJsonDocument(state).toJson(QJsonDocument::Compact), context_);
    if (sealed.isEmpty() || !db_.transaction()) return false;
    {
        QSqlQuery query(db_);
        if (!query.exec("SELECT sealed FROM protocol_state WHERE id=1")) { db_.rollback(); return false; }
        const auto current = query.next() ? query.value(0).toByteArray() : QByteArray();
        if (current != baseline_) { db_.rollback(); return false; }
    }
    bool ok = true;
    if (!outgoing.isEmpty()) {
        // Only allow the transport envelope, never a protocol response containing private state.
        const auto keys = outgoing.keys();
        for (const auto &key : keys)
            if (key != "id" && key != "peer" && key != "kind" && key != "ciphertext" && key != "peer_identity") ok = false;
        if (outgoing["id"].toString().isEmpty() || outgoing["peer"].toString().isEmpty()
            || !outgoing["ciphertext"].isArray()) ok = false;
        if (ok) {
            QSqlQuery query(db_);
            query.prepare("INSERT INTO outbox(id,envelope) VALUES(?,?)");
            query.addBindValue(outgoing["id"].toString());
            query.addBindValue(QJsonDocument(outgoing).toJson(QJsonDocument::Compact));
            ok = query.exec();
        }
    }
    if (ok && !message.isEmpty()) {
        const auto sealedMessage = LocalProtection::protect(QJsonDocument(message).toJson(QJsonDocument::Compact), context_ + ":message");
        if (sealedMessage.isEmpty() || message["peer"].toInt() <= 0 || message["id"].toString().isEmpty()) ok = false;
        else {
            QSqlQuery query(db_);
            query.prepare("INSERT INTO messages(peer,id,outgoing,sealed) VALUES(?,?,?,?)");
            query.addBindValue(message["peer"].toInt()); query.addBindValue(message["id"].toString());
            query.addBindValue(message["outgoing"].toBool() ? 1 : 0); query.addBindValue(sealedMessage); ok = query.exec();
        }
    }
    if (ok) {
        QSqlQuery query(db_);
        query.prepare("INSERT INTO protocol_state(id,sealed) VALUES(1,?) ON CONFLICT(id) DO UPDATE SET sealed=excluded.sealed");
        query.addBindValue(sealed); ok = query.exec();
    }
    if (ok && db_.commit()) { baseline_ = sealed; return true; }
    db_.rollback(); return false;
}
QJsonArray PrivateChatStore::messages(int peer) const {
    QJsonArray result;
    QSqlQuery query(db_);
    query.prepare("SELECT sealed,id,outgoing FROM messages WHERE peer=? ORDER BY rowid DESC LIMIT 200"); query.addBindValue(peer);
    if (!query.exec()) return result;
    while (query.next()) {
        auto message = QJsonDocument::fromJson(LocalProtection::unprotect(query.value(0).toByteArray(), context_ + ":message")).object();
        if (message.isEmpty()) return {};
        if (query.value(2).toBool()) {
            QSqlQuery waiting(db_); waiting.prepare("SELECT 1 FROM outbox WHERE id=?"); waiting.addBindValue(query.value(1));
            message["status"] = waiting.exec() && waiting.next() ? "pending" : "sent";
        }
        result.prepend(message);
    }
    return result;
}
bool PrivateChatStore::received(int peer, const QString &id) const {
    QSqlQuery query(db_); query.prepare("SELECT 1 FROM messages WHERE peer=? AND id=? AND outgoing=0");
    query.addBindValue(peer); query.addBindValue(id); return query.exec() && query.next();
}
QJsonArray PrivateChatStore::pending() const {
    QJsonArray result;
    QSqlQuery query(db_);
    if (query.exec("SELECT envelope FROM outbox ORDER BY rowid"))
        while (query.next()) result.append(QJsonDocument::fromJson(query.value(0).toByteArray()).object());
    return result;
}
bool PrivateChatStore::acknowledge(const QString &messageId) {
    QSqlQuery query(db_);
    query.prepare("DELETE FROM outbox WHERE id=?"); query.addBindValue(messageId);
    return query.exec();
}
