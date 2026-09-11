#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QHash>
#include <QList>
#include <QString>
#include <QDateTime>
#include <QtQml/qqml.h>

class ChatStore : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("由 TcpMgr 持有，通过 tcpMgr.chatStore 使用")
    Q_PROPERTY(QVariantList friends READ friends NOTIFY stateChanged)
    Q_PROPERTY(QVariantList conversations READ conversations NOTIFY stateChanged)
    Q_PROPERTY(QVariantList messages READ messages NOTIFY stateChanged)
    Q_PROPERTY(int activeUid READ activeUid NOTIFY stateChanged)
    Q_PROPERTY(QString activeName READ activeName NOTIFY stateChanged)
public:
    explicit ChatStore(QObject *parent = nullptr) : QObject(parent) {}
    QVariantList friends() const { return _friends; }
    QVariantList messages() const { return _history.value(_active); }
    int activeUid() const { return _active; }
    QString activeName() const { return displayName(_active); }
    bool hasFriend(int uid) const { return !friendInfo(uid).isEmpty(); }

    void reset(int uid, const QString &name) {
        _self = uid; _selfName = name; _active = 0;
        _friends.clear(); _history.clear(); _order.clear(); _unread.clear();
        emit stateChanged();
    }

    void replaceFriends(const QVariantList &rows) {
        _friends.clear();
        for (const auto &v : rows) {
            auto row = v.toMap();
            const int uid = row.value("uid").toInt();
            if (uid <= 0 || uid == _self || hasFriend(uid)) continue;
            QString name = row.value("remark").toString();
            if (name.isEmpty()) name = row.value("nick").toString();
            if (name.isEmpty()) name = row.value("name").toString();
            if (name.isEmpty()) name = QString::number(uid);
            row["displayName"] = name;
            _friends.append(row);
            if (!_order.contains(uid)) _order.append(uid);
        }
        if (_active && !hasFriend(_active)) _active = 0;
        emit stateChanged();
    }

    Q_INVOKABLE bool openConversation(int uid) {
        if (!hasFriend(uid)) return false;
        _active = uid; _unread[uid] = 0;
        touch(uid);
        emit stateChanged();
        return true;
    }

    QVariantList conversations() const {
        QVariantList rows;
        for (int uid : _order) {
            // 已不在好友表中的旧会话暂不提供发送入口。
            if (!hasFriend(uid)) continue;
            const auto history = _history.value(uid);
            const auto last = history.isEmpty() ? QVariantMap{} : history.last().toMap();
            rows.append(QVariantMap{
                {"uid", uid}, {"name", displayName(uid)},
                {"head", friendInfo(uid).value("icon")},
                {"lastMsg", last.value("messageText", "")},
                {"time", last.value("timestamp", "")},
                {"unread", _unread.value(uid)}
            });
        }
        return rows;
    }

    void appendOutgoing(int peer, const QString &id, const QString &text) {
        append(peer, _self, id, text, true);
    }
    void appendIncoming(int peer, const QString &id, const QString &text) {
        append(peer, peer, id, text, false);
    }

    void mark(int peer, const QString &id, const QString &status) {
        auto it = _history.find(peer);
        if (it == _history.end()) return;
        for (auto &v : it.value()) {
            auto m = v.toMap();
            if (m.value("msgid").toString() == id &&
                m.value("isSentByMe").toBool()) {
                m["status"] = status; v = m;
                emit stateChanged();
                return;
            }
        }
    }

    void disconnectPending() {
        for (auto it = _history.begin(); it != _history.end(); ++it) {
            for (auto &v : it.value()) {
                auto m = v.toMap();
                if (m.value("status").toString() == "pending") {
                    m["status"] = "unknown"; v = m;
                }
            }
        }
        emit stateChanged();
    }

signals:
    void stateChanged();

private:
    QVariantMap friendInfo(int uid) const {
        for (const auto &v : _friends)
            if (v.toMap().value("uid").toInt() == uid) return v.toMap();
        return {};
    }
    QString displayName(int uid) const {
        const auto info = friendInfo(uid);
        return info.value("displayName", QString::number(uid)).toString();
    }
    void touch(int uid) {
        _order.removeAll(uid);
        _order.prepend(uid);
    }
    void append(int peer, int sender, const QString &id,
                const QString &text, bool mine) {
        auto &rows = _history[peer];
        // 去重键同时包含发送者，避免双方碰巧使用同一个 msgid。
        for (const auto &v : rows) {
            const auto m = v.toMap();
            if (m.value("msgid").toString() == id &&
                m.value("senderUid").toInt() == sender) return;
        }
        rows.append(QVariantMap{
            {"msgid", id}, {"senderUid", sender}, {"messageText", text},
            {"isSentByMe", mine}, {"imageSource", ""},
            {"senderName", mine ? _selfName : displayName(peer)},
            {"avatarSource", mine ? QString{} : friendInfo(peer).value("icon").toString()},
            {"timestamp", QDateTime::currentDateTime().toString("hh:mm")},
            {"status", mine ? "pending" : "received"}
        });
        // 教学版只保留每个会话最近 200 条；不是完整历史。
        while (rows.size() > 200) rows.removeFirst();
        if (!mine && peer != _active) ++_unread[peer];
        touch(peer);
        emit stateChanged();
    }
    int _self = 0, _active = 0;
    QString _selfName;
    QVariantList _friends;
    QHash<int, QVariantList> _history;
    QList<int> _order;
    QHash<int, int> _unread;
};
