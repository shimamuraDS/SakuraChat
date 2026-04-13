#ifndef LOGINCONTROLLER_H
#define LOGINCONTROLLER_H
#include <QObject>
#include "global.h"
#include <QMap>
#include <QtQml/qqml.h>

class LoginController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
public:
    explicit LoginController(QObject *parent = nullptr);

    Q_INVOKABLE void loginUser(const QVariantMap &userData);

private slots:
    void slot_login_mod_finish(ReqId id, QString res, ErrorCodes err);
    void slot_tcp_con_finish(bool bsuccess);
    void slot_login_failed(int);

private:
    void initHttpHandlers();
    QMap<ReqId, std::function<void(const QJsonObject&)>> _handlers;

    int _uid;
    QString _token;

signals:
    void loginResult(bool success, int error, const QString &message, const QString &user);
    void sig_connect_tcp(ServerInfo);
};

#endif // LOGINCONTROLLER_H
