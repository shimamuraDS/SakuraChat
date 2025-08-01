#ifndef REGISTERCONTROLLER_H
#define REGISTERCONTROLLER_H
#include <QObject>
#include "httpmgr.h"

class RegisterController : public QObject
{
    Q_OBJECT
public:
    explicit RegisterController(QObject *parent = nullptr);

    Q_INVOKABLE void getVerifyCode(const QString& email);
    Q_INVOKABLE void registerUser(const QString& username, const QString& email, const QString& verifyCode, const QString& password);

private:
    void initHttpHandlers();
    QMap<ReqId, std::function<void(const QJsonObject&)>> _handlers;

public slots:
    void slot_reg_mod_finish(ReqId id, QString res, ErrorCodes err);

signals:
    void verifyCodeResult(bool success, const QString& message);
    void registerResult(bool success, const QString& message);
};

#endif // REGISTERCONTROLLER_H
