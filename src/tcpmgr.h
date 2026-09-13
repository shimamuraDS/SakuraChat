#pragma once
#include <QTcpSocket>
#include <QSslSocket>
#include <QJsonObject>
#include <QMap>
#include <QVariant>
#include <QtQml/qqml.h>
#include <QQmlEngine>
#include <functional>
#include "singleton.h"
#include "global.h"
#include "chatstore.h"
#include <QTimer>
#include <QHash>
#include <QQueue>
#include <QSet>

class TcpMgr : public QObject, public Singleton<TcpMgr>, public std::enable_shared_from_this<TcpMgr>
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool searchPending READ searchPending NOTIFY searchPendingChanged)
    Q_PROPERTY(bool applyPending READ applyPending NOTIFY applyPendingChanged)
    Q_PROPERTY(bool reviewPending READ reviewPending NOTIFY reviewPendingChanged)
    Q_PROPERTY(QVariantList friendApplySnapshot READ friendApplySnapshot NOTIFY friendApplySnapshotChanged)
    Q_PROPERTY(ChatStore* chatStore READ chatStore CONSTANT)
    Q_PROPERTY(bool chatReady READ chatReady NOTIFY chatReadyChanged)
    Q_PROPERTY(bool friendSyncBusy READ friendSyncBusy NOTIFY friendSyncBusyChanged)
    Q_PROPERTY(QVariantMap privacy READ privacy NOTIFY privacyChanged)
    Q_PROPERTY(bool privacyPending READ privacyPending NOTIFY privacyChanged)
    Q_PROPERTY(bool deletionPending READ deletionPending NOTIFY deletionPendingChanged)
public:
    ~TcpMgr();

    static TcpMgr *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
    {
        Q_UNUSED(qmlEngine)
        Q_UNUSED(jsEngine)

        TcpMgr *instance = TcpMgr::GetInstance().get();

        QQmlEngine::setObjectOwnership(instance, QQmlEngine::CppOwnership);

        return instance;
    }

    bool searchPending() const { return _searchPending; }
    bool applyPending() const { return _applyPending; }
    bool reviewPending() const { return _reviewPending; }

    Q_INVOKABLE void searchUser(const QString &keyword);
    Q_INVOKABLE void applyFriend(int toUid, const QString &descs, const QString &backName);
    Q_INVOKABLE void resolveFriendApply(qint64 applyId, bool agree);
    QVariantList friendApplySnapshot() const {
        return _friendApplySnapshot;
    }
    ChatStore *chatStore() const { return _chatStore; }
    bool chatReady() const { return _chatReady; }
    bool friendSyncBusy() const { return _friendSyncBusy; }
    Q_INVOKABLE void refreshFriends();
    Q_INVOKABLE QString sendTextMessage(int toUid, const QString &text);
    Q_INVOKABLE void retryTextMessage(int peerUid, const QString &msgid);
    Q_INVOKABLE void markMessageRead(const QString &messageId);
    Q_INVOKABLE void logout();
    Q_INVOKABLE void setConversationVisible(bool visible);
    QVariantMap privacy() const { return _privacy; }
    bool privacyPending() const { return !_privacyRequest.isEmpty(); }
    Q_INVOKABLE void privacyCommand(const QVariantMap &command);
    bool deletionPending() const { return !_deleteRequest.isEmpty(); }
    Q_INVOKABLE void deleteMessage(const QString &messageId, bool forEveryone);

private:
    QString _deleteRequest, _deleteServerId, _deleteClientId;
    int _deleteSender = 0;
    bool _deleteEveryone = false;
    friend class Singleton<TcpMgr>;
    TcpMgr();
    void initHandlers();
    void handleMsg(ReqId id, int len, const QByteArray &data);
    QSslSocket _socket;
    QString _host;
    uint16_t _port;
    QByteArray _buffer;
    bool _b_recv_pending;
    quint16 _message_id;
    quint16 _message_len;
    QMap<ReqId, std::function<void(ReqId id, int len, const QByteArray &data)>> _handlers;
    void sendJson(ReqId id, const QJsonObject &object);
    void resetBusinessPending();
    bool sendSmallJson(ReqId id, const QJsonObject &object);
    void requestFriendPage();
    void failFriendSync(const QString &reason);
    void onFriendPage(const QByteArray &data);
    void onTextReply(const QByteArray &data);
    void onTextNotify(const QByteArray &data);
    void submitText(int peer, const QString &id, const QString &text);
    void pumpSync();
    void onSyncReply(const QByteArray &data);
    void queueHistory(int peer);
    void resetSync();
    QTimer _syncTimer;
    quint64 _sessionGeneration = 0, _attemptCounter = 0;
    QHash<QString, quint64> _pendingAttempts;
    QString _syncRequest, _syncCursor, _conversationCursor = "0";
    ReqId _syncKind = ID_CHAT_HISTORY_REQ;
    int _syncPeer = 0, _statusOffset = 0, _connectingUid = 0;
    qint64 _syncDeadline = 0, _nextSweep = 0, _nextStatePoll = 0, _retrySyncAt = 0;
    qint64 _receiptRetryAt = 0;
    qint64 _nextDeletionPoll = 0;
    QQueue<int> _historyQueue;
    QSet<int> _queuedPeers;
    QStringList _queriedIds;
    QString _receiptId;
    QVariantMap _privacy;
    QString _privacyRequest;
    bool _listing = false, _intentionalDisconnect = false, _conversationVisible = false;
    bool _searchPending = false;
    bool _applyPending = false;
    bool _reviewPending = false;
    QVariantList _friendApplySnapshot;
    ChatStore *_chatStore = nullptr; // QObject 子对象，由 TcpMgr 自动销毁
    bool _chatReady = false;
    bool _friendSyncBusy = false;
    bool _friendSyncAgain = false;
    QString _friendRequestId;
    int _friendCursor = 0;
    QVariantList _friendStaging;
    QTimer _friendTimer;
    QHash<QString, int> _pendingTexts; // msgid -> 接收者 UID
    void handleTransportLoss();
public slots:
    void slot_tcp_connect(ServerInfo);
    void slot_send_data(ReqId, QString data);
signals:
    void newPrivateMessage();
    void deletionPendingChanged();
    void deletionFinished(bool success, QString message);
    void sig_con_success(bool bsuccess);
    void sig_send_data(ReqId reqId, QString data);
    void sig_switch_chatlg();
    void sig_login_failed(int);
    void sig_user_search(QVariantList results);
    void searchPendingChanged();
    void applyPendingChanged();
    void sig_search_failed(int error, QString message);
    void sig_friend_apply(QVariantMap application);
    void reviewPendingChanged();
    void friendApplySnapshotChanged();
    void sig_friend_apply_result(int error, int result, qint64 applyId);
    void sig_friend_apply_resolved(int error, int result, qint64 applyId, bool agree);
    void sig_friend_auth_notified(qint64 applyId, bool agree, int peerUid);
    void chatReadyChanged();
    void friendSyncBusyChanged();
    void chatError(QString message);
    void loggedOut();
    void privacyChanged();
};
