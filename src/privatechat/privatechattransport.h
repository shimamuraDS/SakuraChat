#pragma once
#include <QObject>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QPointer>
#include <QUrl>

class QNetworkReply;
// Authenticated ciphertext transport. No protocol state, private key, or plaintext is accepted.
class PrivateChatTransport final : public QObject {
    Q_OBJECT
public:
    explicit PrivateChatTransport(QObject *parent = nullptr);
    bool beginSession(int uid, const QString &token, const QUrl &gateway);
    void endSession();
    bool submit(const QJsonObject &command);
signals:
    void finished(QString requestId, QJsonObject response);
private:
    QNetworkAccessManager network_;
    QPointer<QNetworkReply> pending_;
    QUrl endpoint_;
    int uid_ = 0;
    QString token_;
    quint64 generation_ = 0;
};
