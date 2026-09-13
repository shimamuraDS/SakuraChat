#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QJsonObject>
#include <QtQml/qqml.h>
#include "chatrepository.h"

class ChatStore : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("由 TcpMgr 持有，通过 tcpMgr.chatStore 使用")
    Q_PROPERTY(QVariantList friends READ friends NOTIFY stateChanged)
    Q_PROPERTY(QVariantList conversations READ conversations NOTIFY stateChanged)
    Q_PROPERTY(QVariantList messages READ messages NOTIFY stateChanged)
    Q_PROPERTY(int activeUid READ activeUid NOTIFY stateChanged)
    Q_PROPERTY(QString activeName READ activeName NOTIFY stateChanged)
    Q_PROPERTY(bool hasOlder READ hasOlder NOTIFY stateChanged)
    Q_PROPERTY(bool activeCanSend READ activeCanSend NOTIFY stateChanged)
public:
    explicit ChatStore(QObject *parent = nullptr) : QObject(parent) {
        _repo.setProtectionErrorHandler([this](QString message) {
            // A read can occur inside a QML property evaluation; notify after it unwinds.
            QMetaObject::invokeMethod(this, [this, message] {
                emit storageError(message); emit stateChanged();
            }, Qt::QueuedConnection);
        });
    }
    bool beginAccount(int uid, const QString &name, const QString &environment);
    void endAccount();
    int selfUid() const { return _self; }
    bool ready() const { return _repo.ready() && _self > 0; }
    QVariantList friends() const { return _friends; }
    QVariantList messages() const;
    QVariantList conversations() const;
    int activeUid() const { return _active; }
    QString activeName() const { return displayName(_active); }
    bool hasFriend(int uid) const { return !friendInfo(uid).isEmpty(); }
    bool activeCanSend() const { return ready() && _active > 0 && hasFriend(_active); }
    void replaceFriends(const QVariantList &rows);
    Q_INVOKABLE bool openConversation(int uid);
    Q_INVOKABLE void loadOlder();
    bool hasOlder() const;
    bool appendOutgoing(int peer, const QString &id, const QString &text);
    bool mergeServer(const QJsonObject &message);
    bool mark(int peer, const QString &id, const QString &status);
    bool markRead(const QString &id);
    void disconnectPending();
    ChatRepository &repository() { return _repo; }
    void refresh() { emit stateChanged(); }
signals:
    void stateChanged();
    void conversationOpened(int uid);
    void storageError(QString message);
private:
    QVariantMap friendInfo(int uid) const;
    QString displayName(int uid) const;
    bool saved(bool ok);
    int _self = 0, _active = 0, _windowSize = 200;
    QString _selfName;
    QVariantList _friends;
    ChatRepository _repo;
};
