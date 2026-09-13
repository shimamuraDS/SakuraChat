#include "chatrepository.h"
#include "localprotection.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QStandardPaths>
#include <QDir>
#include <QCryptographicHash>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUuid>
#include <algorithm>

namespace {
QByteArray encode(const QVariantMap &m) { return QJsonDocument(QJsonObject::fromVariantMap(m)).toJson(QJsonDocument::Compact); }
QByteArray messageIdentity(int sender, const QString &id) { return QJsonDocument(QJsonArray{"message", sender, id}).toJson(QJsonDocument::Compact); }
QByteArray contactIdentity(int uid) { return QJsonDocument(QJsonArray{"contact", uid}).toJson(QJsonDocument::Compact); }
int rank(const QString &s) { return s == "read" ? 3 : s == "delivered" ? 2 : s == "accepted" ? 1 : 0; }
void logSqlFailure(const char *operation, const QSqlError &error) {
    // Do not log bound values: they may contain private message content.
    qWarning().noquote() << "ChatRepository:" << operation
                         << "code=" << error.nativeErrorCode()
                         << "driver=" << error.driverText()
                         << "database=" << error.databaseText();
}
bool exec(QSqlQuery &q, const QString &sql, const QVariantList &args = {}) {
    if (!q.prepare(sql)) { logSqlFailure("prepare", q.lastError()); return false; }
    for (const auto &v : args) q.addBindValue(v);
    if (!q.exec()) { logSqlFailure("execute", q.lastError()); return false; }
    return true;
}
}
ChatRepository::~ChatRepository() { close(); }
void ChatRepository::protectionFailed(const QString &message) const {
    const bool first = !_cryptoFailure;
    _cryptoFailure = true; _error = message;
    if (first && _onProtectionError) _onProtectionError(message);
}
QByteArray ChatRepository::seal(const QVariantMap &m, const QByteArray &identity) const {
    auto result = LocalProtection::protect(encode(m), _protectionContext + identity);
    if (result.isEmpty()) {
        protectionFailed("无法加密本地聊天记录，已停止保存；请检查 Windows 用户配置，不要删除原缓存");
    }
    return result;
}
QVariantMap ChatRepository::reveal(const QVariant &value, const QByteArray &identity) const {
    auto plain = LocalProtection::unprotect(value.toByteArray(), _protectionContext + identity);
    const auto json = QJsonDocument::fromJson(plain);
    plain.fill(0);
    if (json.isNull() || !json.isObject() || json.object().isEmpty()) {
        protectionFailed("无法解密本地聊天记录，已停止读写；请使用原 Windows 用户及原环境，保留缓存以便恢复");
        return {};
    }
    return json.object().toVariantMap();
}

bool ChatRepository::protectExisting() {
    QSqlQuery q(_db);
    if (!q.exec("CREATE TABLE IF NOT EXISTS local_security(id INTEGER PRIMARY KEY CHECK(id=1),version INTEGER NOT NULL,probe BLOB NOT NULL)")) return false;
    if (!q.exec("SELECT version,probe FROM local_security WHERE id=1")) return false;
    if (q.next()) {
        if (q.value(0).toInt() != 1) { _error = "本地缓存版本不兼容，请保留文件并升级客户端"; return false; }
        if (LocalProtection::unprotect(q.value(1).toByteArray(), _protectionContext + "probe") != "SakuraChat local protection v1") {
            _cryptoFailure = true; _error = "无法解锁本地缓存，请使用原 Windows 用户，切勿删除缓存或覆盖原记录"; return false;
        }
        return true;
    }
    q.finish();
    if (!_db.transaction()) return false;
    // Bounded batches, one transaction: interrupted conversion rolls back all rows and the marker.
    for (const auto &table : {QStringLiteral("messages"), QStringLiteral("contacts")}) {
        qint64 last = 0; bool first = true;
        for (;;) {
            QSqlQuery rows(_db);
            const QString columns = table == "messages" ? "rowid,payload,sender,msgid" : "rowid,payload,uid";
            const QString sql = "SELECT " + columns + " FROM " + table + (first ? "" : " WHERE rowid>?") + " ORDER BY rowid LIMIT 100";
            if (!exec(rows, sql, first ? QVariantList{} : QVariantList{last})) { _db.rollback(); return false; }
            struct Row { qint64 id; QByteArray payload; QByteArray identity; };
            QList<Row> batch;
            while (rows.next()) batch.append({rows.value(0).toLongLong(), rows.value(1).toByteArray(),
                table == "messages" ? messageIdentity(rows.value(2).toInt(), rows.value(3).toString()) : contactIdentity(rows.value(2).toInt())});
            rows.finish();
            if (batch.isEmpty()) break;
            for (const auto &row : batch) {
                QVariantMap map;
                if (LocalProtection::isProtected(row.payload)) map = reveal(row.payload, row.identity);
                else {
                    const auto json = QJsonDocument::fromJson(row.payload);
                    if (json.isObject()) map = json.object().toVariantMap();
                }
                if (map.isEmpty()) { _error = "旧聊天缓存损坏或无法解密，转换已回滚，请保留原文件"; _db.rollback(); return false; }
                const auto encrypted = seal(map, row.identity);
                if (encrypted.isEmpty() || !exec(q, "UPDATE " + table + " SET payload=? WHERE rowid=?", {encrypted, row.id})) { _db.rollback(); return false; }
                last = row.id;
            }
            first = false;
        }
    }
    const auto probe = LocalProtection::protect("SakuraChat local protection v1", _protectionContext + "probe");
    if (probe.isEmpty() || !exec(q, "INSERT INTO local_security(id,version,probe) VALUES(1,1,?)", {probe}) || !_db.commit()) { _db.rollback(); return false; }
    return true;
}
void ChatRepository::close() {
    if (_db.isValid()) _db.close();
    _db = QSqlDatabase{};
    if (!_connection.isEmpty()) QSqlDatabase::removeDatabase(_connection);
    _connection.clear();
    _protectionContext.clear(); _cryptoFailure = false;
}
bool ChatRepository::open(const QString &environment, int uid) {
    close(); _error.clear();
    if (uid <= 0) return false;
    const auto base = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    const auto key = QCryptographicHash::hash(environment.toUtf8(), QCryptographicHash::Sha256).toHex();
    _protectionContext = QByteArray("SakuraChat-cache-v1:") + key + ':' + QByteArray::number(uid) + ':';
    const auto path = base + "/chat/" + QString::fromLatin1(key) + "/" + QString::number(uid);
    if (base.isEmpty() || !QDir().mkpath(path)) { _error = "无法创建聊天记录目录，请检查存储空间和权限"; return false; }
    _connection = "chat-" + QUuid::createUuid().toString(QUuid::WithoutBraces);
    _db = QSqlDatabase::addDatabase("QSQLITE", _connection);
    _db.setDatabaseName(path + "/chat.sqlite");
    if (!_db.open()) { _error = "无法打开本地聊天记录，请检查 SQLite 驱动和文件权限"; return false; }
    QSqlQuery q(_db);
    const QStringList statements{
        "PRAGMA busy_timeout=1000", "PRAGMA journal_mode=WAL", "PRAGMA synchronous=FULL", "PRAGMA secure_delete=ON",
        "CREATE TABLE IF NOT EXISTS messages(sender INTEGER NOT NULL,msgid TEXT NOT NULL,peer INTEGER NOT NULL,server_id TEXT,seq TEXT NOT NULL DEFAULT '',created_ms INTEGER NOT NULL,state TEXT NOT NULL,local_read INTEGER NOT NULL,payload BLOB NOT NULL,PRIMARY KEY(sender,msgid))",
        "CREATE UNIQUE INDEX IF NOT EXISTS server_id_unique ON messages(server_id) WHERE server_id IS NOT NULL",
        "CREATE INDEX IF NOT EXISTS peer_messages ON messages(peer,seq,created_ms)",
        "CREATE TABLE IF NOT EXISTS receipts(id TEXT PRIMARY KEY,status INTEGER NOT NULL)",
        "CREATE TABLE IF NOT EXISTS sync_cursor(peer INTEGER PRIMARY KEY,seq TEXT NOT NULL)",
        "CREATE TABLE IF NOT EXISTS contacts(uid INTEGER PRIMARY KEY,payload BLOB NOT NULL)",
        "CREATE TABLE IF NOT EXISTS local_deleted(sender INTEGER NOT NULL,msgid TEXT NOT NULL,PRIMARY KEY(sender,msgid))"
    };
    for (const auto &s : statements) if (!q.exec(s)) { _error = "本地聊天记录初始化失败，请检查存储空间"; return false; }
    if (!protectExisting()) { if (_error.isEmpty()) _error = "本地缓存加密转换失败，原记录未被清空，请稍后重试"; return false; }
    // A process restart cannot establish the outcome of an interrupted send.
    if (!q.exec("SELECT payload,sender,msgid FROM messages WHERE state='pending'")) return false;
    QVariantList pending;
    while (q.next()) { const auto m = reveal(q.value(0), messageIdentity(q.value(1).toInt(), q.value(2).toString())); if (_cryptoFailure) return false; pending.append(m); }
    q.finish();
    for (auto v : pending) { auto m = v.toMap(); m["status"] = "unknown"; if (!put(m)) return false; }
    return true;
}
QVariantMap ChatRepository::find(int sender, const QString &id) const {
    if (!ready()) return {};
    QSqlQuery q(_db);
    if (exec(q, "SELECT payload FROM messages WHERE sender=? AND msgid=?", {sender, id}) && q.next()) return reveal(q.value(0), messageIdentity(sender, id));
    return {};
}
QVariantMap ChatRepository::findServer(const QString &id) const {
    if (!ready() || id.isEmpty()) return {};
    QSqlQuery q(_db);
    if (exec(q, "SELECT payload,sender,msgid FROM messages WHERE server_id=?", {id}) && q.next()) return reveal(q.value(0), messageIdentity(q.value(1).toInt(), q.value(2).toString()));
    return {};
}
bool ChatRepository::put(QVariantMap incoming) {
    if (_cryptoFailure) return false;
    if (isDeleted(incoming.value("senderUid").toInt(), incoming.value("msgid").toString())) return true;
    if (_cryptoFailure) return false;
    _error.clear();
    if (!ready()) { _error = "本地聊天记录尚未打开，请重新登录后重试"; return false; }
    auto m = find(incoming.value("senderUid").toInt(), incoming.value("msgid").toString());
    if (_cryptoFailure) return false;
    const auto old = m;
    for (auto it = incoming.begin(); it != incoming.end(); ++it) m[it.key()] = it.value();
    if (rank(old.value("status").toString()) > rank(m.value("status").toString())) m["status"] = old.value("status");
    m["localRead"] = old.value("localRead").toBool() || m.value("localRead").toBool() ||
                     (!m.value("isSentByMe").toBool() && m.value("status").toString() == "read");
    const QString serverId = m.value("messageId").toString();
    if (m.value("senderUid").toInt() <= 0 || m.value("peerUid").toInt() <= 0 || m.value("msgid").toString().isEmpty()) {
        _error = "消息信息不完整，暂时无法保存";
        return false;
    }
    const auto encrypted = seal(m, messageIdentity(m.value("senderUid").toInt(), m.value("msgid").toString()));
    if (encrypted.isEmpty()) return false;
    if (!_db.transaction()) {
        logSqlFailure("begin message transaction", _db.lastError());
        _error = "暂时无法保存聊天记录，请稍后重试";
        return false;
    }
    QSqlQuery q(_db);
    QString seq = m.value("seq").toString();
    // Pending messages have no server sequence yet. A null QString binds as
    // SQL NULL and violates seq NOT NULL; explicitly bind non-null empty text.
    if (seq.isEmpty()) seq = QStringLiteral("");
    else seq = seq.rightJustified(20, '0');
    const bool ok = exec(q, "INSERT INTO messages(sender,msgid,peer,server_id,seq,created_ms,state,local_read,payload) "
        "VALUES(?,?,?,?,?,?,?,?,?) ON CONFLICT(sender,msgid) DO UPDATE SET peer=excluded.peer,server_id=excluded.server_id,"
        "seq=excluded.seq,created_ms=excluded.created_ms,state=excluded.state,local_read=excluded.local_read,payload=excluded.payload",
        {m["senderUid"], m["msgid"], m["peerUid"], serverId.isEmpty() ? QVariant{} : QVariant(serverId), seq,
         m.value("createdAtMs").toLongLong(), m["status"], m["localRead"], encrypted});
    bool receiptOk = true;
    if (ok && !m.value("isSentByMe").toBool() && !serverId.isEmpty()) {
        // Receiving read state from the authoritative history needs no further receipt.
        if (m.value("status").toString() == "read")
            receiptOk = exec(q, "DELETE FROM receipts WHERE id=?", {serverId});
        else if (m.value("localRead").toBool() || m.value("status").toString() != "delivered")
            receiptOk = exec(q, "INSERT INTO receipts(id,status) VALUES(?,?) ON CONFLICT(id) DO UPDATE SET status=MAX(status,excluded.status)",
                             {serverId, m.value("localRead").toBool() ? 1 : 0});
    }
    if (!ok || !receiptOk) {
        // exec() already captured the query error before rollback can replace it.
        if (!_db.rollback()) logSqlFailure("rollback message transaction", _db.lastError());
        _error = "暂时无法保存聊天记录，请稍后重试";
        return false;
    }
    if (!_db.commit()) {
        logSqlFailure("commit message transaction", _db.lastError());
        if (!_db.rollback()) logSqlFailure("rollback message transaction", _db.lastError());
        _error = "暂时无法保存聊天记录，请稍后重试";
        return false;
    }
    return true;
}
QVariantList ChatRepository::messages(int peer, int limit) const {
    QVariantList rows; if (!ready()) return rows;
    QSqlQuery q(_db);
    if (exec(q, "SELECT payload,sender,msgid FROM messages WHERE peer=? ORDER BY (seq='') DESC,seq DESC,created_ms DESC LIMIT ?", {peer, limit}))
        while (q.next()) { auto m = reveal(q.value(0), messageIdentity(q.value(1).toInt(), q.value(2).toString())); if (_cryptoFailure) return {}; rows.append(m); }
    std::reverse(rows.begin(), rows.end()); return rows;
}
QList<int> ChatRepository::peers() const {
    QList<int> rows; if (!ready()) return rows;
    QSqlQuery q(_db);
    if (q.exec("SELECT peer FROM messages GROUP BY peer ORDER BY MAX(created_ms) DESC")) while(q.next()) rows.append(q.value(0).toInt());
    return rows;
}
int ChatRepository::unread(int peer) const {
    if (!ready()) return 0;
    QSqlQuery q(_db);
    if (exec(q, "SELECT COUNT(*) FROM messages WHERE peer=? AND sender=peer AND local_read=0", {peer}) && q.next()) return q.value(0).toInt();
    return 0;
}
bool ChatRepository::read(const QString &id) {
    auto m = findServer(id);
    if (m.isEmpty() || m.value("isSentByMe").toBool()) return false;
    m["localRead"] = true; return put(m);
}
QVariantList ChatRepository::receipts() const {
    QVariantList r; if (!ready()) return r;
    QSqlQuery q(_db);
    if (q.exec("SELECT id,status FROM receipts ORDER BY status DESC,id LIMIT 1"))
        while(q.next()) r.append(QVariantMap{{"id",q.value(0)}, {"status",q.value(1)}});
    return r;
}
bool ChatRepository::acknowledgeReceipt(const QString &id, int status, bool readSuppressed) {
    auto m = findServer(id); if (m.isEmpty()) return false;
    m["status"] = status == 1 ? "read" : "delivered";
    if (!put(m)) return false;
    QSqlQuery q(_db); return exec(q, "DELETE FROM receipts WHERE id=? AND status<=?", {id,readSuppressed ? 1 : status});
}
QString ChatRepository::cursor(int peer) const {
    if (!ready()) return "0";
    QSqlQuery q(_db);
    return exec(q, "SELECT seq FROM sync_cursor WHERE peer=?", {peer}) && q.next() ? q.value(0).toString() : "0";
}
bool ChatRepository::setCursor(int peer, const QString &seq) {
    if (!ready()) return false;
    QSqlQuery q(_db); return exec(q, "INSERT INTO sync_cursor(peer,seq) VALUES(?,?) ON CONFLICT(peer) DO UPDATE SET seq=excluded.seq", {peer,seq});
}
QStringList ChatRepository::statusIds(int offset) const {
    QStringList r; if (!ready()) return r;
    QSqlQuery q(_db);
    if (exec(q, "SELECT msgid FROM messages WHERE sender<>peer AND state NOT IN ('read','failed') ORDER BY created_ms LIMIT 4 OFFSET ?", {offset}))
        while(q.next()) r.append(q.value(0).toString());
    return r;
}
QVariantList ChatRepository::contacts() const {
    QVariantList r; if (!ready()) return r;
    QSqlQuery q(_db); if(q.exec("SELECT payload,uid FROM contacts")) while(q.next()) { auto m = reveal(q.value(0), contactIdentity(q.value(1).toInt())); if (_cryptoFailure) return {}; r.append(m); } return r;
}
bool ChatRepository::saveContacts(const QVariantList &rows) {
    if (!ready() || !_db.transaction()) return false;
    QSqlQuery q(_db);
    if (!q.exec("DELETE FROM contacts")) { _db.rollback(); return false; }
    for (const auto &v : rows) { auto m=v.toMap(); auto encrypted = seal(m, contactIdentity(m.value("uid").toInt())); if(encrypted.isEmpty() || !exec(q,"INSERT INTO contacts(uid,payload) VALUES(?,?)",{m["uid"],encrypted})) { _db.rollback(); return false; } }
    if (!_db.commit()) { _db.rollback(); return false; } return true;
}

bool ChatRepository::isDeleted(int sender, const QString &id) const {
    if (!ready()) return false;
    QSqlQuery q(_db);
    if (!exec(q, "SELECT 1 FROM local_deleted WHERE sender=? AND msgid=?", {sender,id})) {
        protectionFailed("无法读取本地删除状态，已停止保存，请稍后重新登录"); return false;
    }
    return q.next();
}

bool ChatRepository::hideDeletedMessage(int sender, const QString &id, const QString &serverId) {
    if (!ready() || sender <= 0 || id.isEmpty() || serverId.isEmpty() || !_db.transaction()) return false;
    QSqlQuery q(_db);
    if (!exec(q,"INSERT OR IGNORE INTO local_deleted(sender,msgid) VALUES(?,?)",{sender,id}) ||
        !exec(q,"DELETE FROM messages WHERE sender=? AND msgid=?",{sender,id}) ||
        !exec(q,"DELETE FROM receipts WHERE id=?",{serverId}) || !_db.commit()) {
        _db.rollback(); return false;
    }
    // Do not advance the event cursor from a command acknowledgement.
    return true;
}

bool ChatRepository::applyDeletions(const QVariantList &events, const QString &next) {
    if (!ready()) return false;
    bool ok = false;
    auto last = cursor(0).toULongLong(&ok); if (!ok) return false;
    for (const auto &v : events) {
        const auto item = v.toMap(); const auto seq = item.value("event_seq").toString().toULongLong(&ok);
        if (!ok || seq <= last || item.value("sender_uid").toInt() <= 0 ||
            item.value("msgid").toString().isEmpty() || item.value("msgid").toString().size() > 64) return false;
        const auto id = item.value("message_id").toString().toULongLong(&ok);
        if (!ok || !id) return false;
        last = seq;
    }
    const auto end = next.toULongLong(&ok); if (!ok || end != last || !_db.transaction()) return false;
    QSqlQuery q(_db);
    for (const auto &v : events) {
        const auto item = v.toMap();
        const QVariantList identity{item.value("sender_uid"),item.value("msgid")};
        if (!exec(q,"INSERT OR IGNORE INTO local_deleted(sender,msgid) VALUES(?,?)",identity) ||
            !exec(q,"DELETE FROM messages WHERE sender=? AND msgid=?",identity) ||
            !exec(q,"DELETE FROM receipts WHERE id=?",{item.value("message_id")})) { _db.rollback(); return false; }
    }
    // peer=0 is reserved for the account's deletion cursor; real peers are positive UIDs.
    if (!setCursor(0,next) || !_db.commit()) { _db.rollback(); return false; }
    return true;
}
