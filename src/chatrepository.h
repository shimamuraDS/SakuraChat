#pragma once
#include <QSqlDatabase>
#include <QVariantList>
#include <QVariantMap>
#include <QStringList>
#include <functional>

// Owned and used by ChatStore on the GUI thread. No connection crosses threads.
class ChatRepository {
public:
    ~ChatRepository();
    bool open(const QString &environment, int uid);
    void close();
    bool ready() const { return _db.isOpen() && !_cryptoFailure; }
    QString error() const { return _error; }
    void setProtectionErrorHandler(std::function<void(QString)> handler) { _onProtectionError = std::move(handler); }
    bool put(QVariantMap message);
    QVariantMap find(int sender, const QString &id) const;
    QVariantMap findServer(const QString &id) const;
    QVariantList messages(int peer, int limit) const;
    QList<int> peers() const;
    int unread(int peer) const;
    bool read(const QString &id);
    QVariantList receipts() const;
    bool acknowledgeReceipt(const QString &id, int status, bool readSuppressed = false);
    QString cursor(int peer) const;
    bool setCursor(int peer, const QString &seq);
    QStringList statusIds(int offset) const;
    QVariantList contacts() const;
    bool saveContacts(const QVariantList &rows);
    bool isDeleted(int sender, const QString &id) const;
    bool applyDeletions(const QVariantList &events, const QString &next);
    bool hideDeletedMessage(int sender, const QString &id, const QString &serverId);
private:
    void protectionFailed(const QString &message) const;
    std::function<void(QString)> _onProtectionError;
    bool protectExisting();
    QByteArray seal(const QVariantMap &message, const QByteArray &identity) const;
    QVariantMap reveal(const QVariant &value, const QByteArray &identity) const;
    QByteArray _protectionContext;
    mutable bool _cryptoFailure = false;
    QSqlDatabase _db;
    QString _connection;
    mutable QString _error;
};
