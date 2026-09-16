#pragma once
#include <QJsonObject>
#include <QSqlDatabase>
#include <QString>

// One instance per account, owned and called by the private-chat worker thread.
// Protocol state and the outgoing ciphertext are committed in one SQLite transaction.
class PrivateChatStore final {
public:
    ~PrivateChatStore();
    bool open(const QString &path, const QString &account, const QString &serverScope);
    void close();
    QJsonObject state() const;
    bool initialized() const;
    bool commit(const QJsonObject &state, const QJsonObject &outgoing = {}, const QJsonObject &message = {});
    QJsonArray messages(int peer) const;
    bool received(int peer, const QString &id) const;
    QJsonArray pending() const;
    bool acknowledge(const QString &messageId);
private:
    QSqlDatabase db_;
    QString connection_;
    QByteArray context_;
    mutable QByteArray baseline_;
};
