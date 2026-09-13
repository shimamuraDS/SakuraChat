#include "chatstore.h"
#include <QDateTime>
#include <QSet>
#include <algorithm>

bool ChatStore::saved(bool ok) {
    if (!ok) emit storageError(_repo.error().isEmpty() ? tr("无法保存聊天记录，请检查存储空间") : _repo.error());
    else emit stateChanged();
    return ok;
}
bool ChatStore::beginAccount(int uid, const QString &name, const QString &environment) {
    endAccount();
    if (!_repo.open(environment, uid)) { saved(false); _repo.close(); return false; }
    _friends = _repo.contacts();
    if (!_repo.ready()) { saved(false); _friends.clear(); _repo.close(); return false; }
    _self = uid; _selfName = name; emit stateChanged(); return true;
}
void ChatStore::endAccount() {
    disconnectPending(); _repo.close(); _self = 0; _active = 0; _windowSize = 200;
    _selfName.clear(); _friends.clear(); emit stateChanged();
}
QVariantMap ChatStore::friendInfo(int uid) const {
    for (const auto &v : _friends) if (v.toMap().value("uid").toInt() == uid) return v.toMap();
    return {};
}
QString ChatStore::displayName(int uid) const {
    if (uid <= 0) return tr("选择联系人开始聊天");
    const auto m = friendInfo(uid);
    for (const auto &key : {"remark", "nick", "name"}) if (!m.value(key).toString().isEmpty()) return m.value(key).toString();
    return QString::number(uid);
}
void ChatStore::replaceFriends(const QVariantList &rows) {
    QVariantList clean;
    QSet<int> seen;
    for (const auto &v : rows) {
        auto m = v.toMap(); int uid = m.value("uid").toInt();
        if (uid <= 0 || uid == _self || seen.contains(uid)) continue;
        seen.insert(uid);
        QString name;
        for (const auto &key : {"remark", "nick", "name"}) if (name.isEmpty()) name = m.value(key).toString();
        m["displayName"] = name.isEmpty() ? QString::number(uid) : name; clean.append(m);
    }
    if (!_repo.saveContacts(clean)) { saved(false); return; }
    _friends = clean; emit stateChanged();
}
QVariantList ChatStore::messages() const {
    auto rows = _repo.messages(_active, _windowSize);
    for (auto &v : rows) {
        auto m = v.toMap(); const bool mine = m.value("isSentByMe").toBool();
        m["senderName"] = mine ? _selfName : displayName(_active);
        m["avatarSource"] = mine ? QString{} : friendInfo(_active).value("icon").toString();
        const auto time = QDateTime::fromMSecsSinceEpoch(m.value("createdAtMs").toLongLong());
        m["timestamp"] = time.toString(time.date() == QDate::currentDate() ? "hh:mm" : "yyyy-MM-dd hh:mm");
        const auto expiry = m.value("expiresAtMs").toString().toLongLong();
        m["expiryText"] = expiry > 0 ? tr("自动删除：%1").arg(QDateTime::fromMSecsSinceEpoch(expiry).toString("MM-dd hh:mm")) : QString();
        v = m;
    }
    return rows;
}
QVariantList ChatStore::conversations() const {
    QVariantList result; auto peers = _repo.peers();
    for (const auto &v : _friends) if (!peers.contains(v.toMap().value("uid").toInt())) peers.append(v.toMap().value("uid").toInt());
    for (int peer : peers) {
        auto rows = _repo.messages(peer, 1); auto last = rows.isEmpty() ? QVariantMap{} : rows.last().toMap();
        result.append(QVariantMap{{"uid",peer},{"name",displayName(peer)},
            {"head",friendInfo(peer).value("icon")},{"lastMsg",last.value("messageText", "")},
            {"time",last.isEmpty() ? QString{} : QDateTime::fromMSecsSinceEpoch(last.value("createdAtMs").toLongLong()).toString("MM-dd hh:mm")},
            {"unread",_repo.unread(peer)}});
    }
    return result;
}
bool ChatStore::openConversation(int uid) {
    if (!ready() || uid <= 0 || uid == _self || (!hasFriend(uid) && !_repo.peers().contains(uid))) return false;
    _active = uid; _windowSize = 200; emit stateChanged(); emit conversationOpened(uid); return true;
}
bool ChatStore::hasOlder() const { return _repo.messages(_active, _windowSize + 1).size() > _windowSize; }
void ChatStore::loadOlder() { if (_active > 0) { _windowSize += 200; emit stateChanged(); } }
bool ChatStore::appendOutgoing(int peer, const QString &id, const QString &text) {
    if (!ready()) return false;
    return saved(_repo.put({{"msgid",id},{"senderUid",_self},{"peerUid",peer},{"messageText",text},
        {"isSentByMe",true},{"createdAtMs",QString::number(QDateTime::currentMSecsSinceEpoch())},
        {"status","pending"},{"localRead",true}}));
}
bool ChatStore::mergeServer(const QJsonObject &o) {
    if (!ready()) return false;
    const int from = o["fromuid"].toInt(), to = o["touid"].toInt();
    const QString id = o["msgid"].toString(), state = o["state"].toString();
    bool validId = false, validSeq = false, validTime = false, validThread = false;
    const auto messageId = o["message_id"].toString().toULongLong(&validId);
    const auto seq = o["seq"].toString().toULongLong(&validSeq);
    const auto thread = o["thread_id"].toString().toULongLong(&validThread);
    const auto time = o["created_at_ms"].toString().toLongLong(&validTime);
    if (from <= 0 || to <= 0 || from == to || (from != _self && to != _self) || id.isEmpty() || id.size() > 64 ||
        !validId || !messageId || !validSeq || !seq || !validThread || !thread || !validTime || time <= 0 ||
        (state != "accepted" && state != "delivered" && state != "read")) return false;
    if (_repo.isDeleted(from, id)) return true;
    auto m = _repo.find(from, id);
    if (m.isEmpty() && !o["content"].isString()) return false;
    m["msgid"] = id; m["senderUid"] = from; m["peerUid"] = from == _self ? to : from;
    m["isSentByMe"] = from == _self; m["messageId"] = o["message_id"].toString();
    m["seq"] = o["seq"].toString(); m["threadId"] = o["thread_id"].toString();
    m["createdAtMs"] = o["created_at_ms"].toString(); m["status"] = state;
    if (o["expires_at_ms"].isString()) m["expiresAtMs"] = o["expires_at_ms"].toString();
    if (o["content"].isString()) m["messageText"] = o["content"].toString();
    if (o["message_status"].toInt() != 0) m["messageText"] = tr("此消息已撤回或删除");
    return saved(_repo.put(m));
}
bool ChatStore::mark(int peer, const QString &id, const QString &status) {
    auto m = _repo.find(_self, id); if (m.isEmpty() || m.value("peerUid").toInt() != peer) return false;
    m["status"] = status; return saved(_repo.put(m));
}
bool ChatStore::markRead(const QString &id) {
    const auto m = _repo.findServer(id);
    if (m.isEmpty() || m.value("isSentByMe").toBool() || m.value("peerUid").toInt() != _active || m.value("localRead").toBool()) return false;
    return saved(_repo.read(id));
}
void ChatStore::disconnectPending() {
    if (!ready()) return;
    for (int offset = 0;; offset += 4) {
        const auto ids = _repo.statusIds(offset); if(ids.isEmpty()) break;
        for (const auto &id : ids) { auto m = _repo.find(_self, id); if (m.value("status").toString() == "pending") { m["status"] = "unknown"; _repo.put(m); } }
    }
    emit stateChanged();
}
