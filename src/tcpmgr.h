#ifndef TCPMGR_H
#define TCPMGR_H
#include <QTcpSocket>
#include <QJsonObject>
#include <QMap>
#include <QVariant>
#include <QtQml/qqml.h>
#include <QQmlEngine>
#include <functional>
#include "singleton.h"
#include "global.h"

class TcpMgr : public QObject, public Singleton<TcpMgr>, public std::enable_shared_from_this<TcpMgr>
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool searchPending READ searchPending NOTIFY searchPendingChanged)
    Q_PROPERTY(bool applyPending READ applyPending NOTIFY applyPendingChanged)
    Q_PROPERTY(bool reviewPending READ reviewPending NOTIFY reviewPendingChanged)
    Q_PROPERTY(QVariantList friendApplySnapshot READ friendApplySnapshot NOTIFY friendApplySnapshotChanged)
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

private:
    friend class Singleton<TcpMgr>;
    TcpMgr();
    void initHandlers();
    void handleMsg(ReqId id, int len, const QByteArray &data);
    QTcpSocket _socket;
    QString _host;
    uint16_t _port;
    QByteArray _buffer;
    bool _b_recv_pending;
    quint16 _message_id;
    quint16 _message_len;
    QMap<ReqId, std::function<void(ReqId id, int len, const QByteArray &data)>> _handlers;
    void sendJson(ReqId id, const QJsonObject &object);
    void resetBusinessPending();
    bool _searchPending = false;
    bool _applyPending = false;
    bool _reviewPending = false;
    QVariantList _friendApplySnapshot;
public slots:
    void slot_tcp_connect(ServerInfo);
    void slot_send_data(ReqId, QString data);
signals:
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
};

#endif // TCPMGR_H
