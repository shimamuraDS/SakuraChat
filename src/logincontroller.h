#ifndef LOGINCONTROLLER_H
#define LOGINCONTROLLER_H
#include <QObject>
#include "global.h"
#include <QMap>

class LoginController : public QObject
{
    Q_OBJECT
public:
    explicit LoginController(QObject *parent = nullptr);

    Q_INVOKABLE void loginUser(const QVariantMap &userData);
    Q_INVOKABLE QString xorString(const QString &input);

signals:
    void loginResult(bool success, int error, const QString &message, const QString &user);

private slots:
    void slot_login_mod_finish(ReqId id, QString res, ErrorCodes err);

private:
    void initHttpHandlers();
    QMap<ReqId, std::function<void(const QJsonObject&)>> _handlers;
};

#endif // LOGINCONTROLLER_H
