#pragma once
#include <QObject>
#include <QThread>
#include <QTimer>
#include <QDeadlineTimer>
#include <QVariantList>
#include <QJsonArray>
#include <functional>
#include "privatechattransport.h"

class PrivateChatEngine;
class PrivateChatController final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool canSend READ canSend NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)
    Q_PROPERTY(QString connectionNotice READ connectionNotice NOTIFY changed)
    Q_PROPERTY(bool canRetry READ canRetry NOTIFY changed)
    Q_PROPERTY(QString peerName READ peerName NOTIFY changed)
    Q_PROPERTY(int peerUid READ peerUid NOTIFY changed)
    Q_PROPERTY(bool identityVerified READ identityVerified NOTIFY changed)
    Q_PROPERTY(bool identityChanged READ identityChanged NOTIFY changed)
    Q_PROPERTY(QString safetyNumber READ safetyNumber NOTIFY changed)
    Q_PROPERTY(QVariantList messages READ messages NOTIFY messagesChanged)
public:
    explicit PrivateChatController(QObject *parent = nullptr);
    ~PrivateChatController() override;
    void beginSession(int uid, const QString &token, const QString &gateway);
    void endSession();
    Q_INVOKABLE void setActive(bool active);
    Q_INVOKABLE void openPeer(int uid, const QString &name);
    Q_INVOKABLE void approveIdentity();
    Q_INVOKABLE void send(const QString &text);
    Q_INVOKABLE void retry();
    bool ready() const { return ready_; }
    bool busy() const { return busy_; }
    bool canSend() const { return ready_ && trusted_ && active_ && !busy_ && failedNetwork_.isEmpty(); }
    QString notice() const { return notice_; }
    QString connectionNotice() const { return connectionNotice_; }
    bool canRetry() const { return active_ && !busy_ && retryDeadline_.hasExpired(); }
    QString peerName() const { return peerName_; }
    int peerUid() const { return peer_; }
    bool identityVerified() const { return verified_; }
    bool identityChanged() const { return identityChanged_; }
    QString safetyNumber() const { return safety_; }
    QVariantList messages() const { return messages_; }
signals:
    void messagesChanged();
    void changed();
    void messageQueued();
private:
    friend class PrivateChatControllerTest;
    using Done = std::function<void(QJsonObject)>;
    void work(QJsonObject command, Done done);
    void network(QJsonObject command, Done done);
    void boot();
    void publishNext();
    void tick();
    void history();
    void setMessages(const QVariantList &messages);
    void establishSession(QJsonObject trust);
    void status(const QString &message);
    QThread thread_;
    PrivateChatEngine *engine_;
    PrivateChatTransport transport_;
    QTimer timer_;
    QTimer retryTimer_;
    QDeadlineTimer retryDeadline_;
    int transientFailures_ = 0;
    QString connectionNotice_;
    int uid_ = 0, peer_ = 0, published_ = 0;
    quint64 generation_ = 0;
    bool ready_ = false, busy_ = false, trusted_ = false, active_ = false, receivePaused_ = false;
    bool verified_ = false, identityChanged_ = false;
    QString gateway_, notice_, peerName_, safety_;
    QJsonArray identity_, candidate_;
    QVariantList messages_;
    QJsonObject pendingNetwork_, failedNetwork_;
    Done networkDone_, failedDone_;
};
