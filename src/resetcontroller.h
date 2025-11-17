#ifndef RESETCONTROLLER_H
#define RESETCONTROLLER_H

#include <QObject>
#include <QJsonObject>
#include "global.h"

class ResetController : public QObject
{
    Q_OBJECT
public:
    explicit ResetController(QObject *parent = nullptr);

    Q_INVOKABLE void getVerifyCode(const QString& email);
    Q_INVOKABLE void resetPassword(const QString& user, const QString& email,
                                   const QString& password, const QString& verifyCode);

signals:
    void verifyCodeResult(bool success, const QString& message);
    void resetResult(bool success, const QString& message);

private slots:
    void slot_reset_mod_finish(ReqId id, QString res, ErrorCodes err);

private:
    void initHttpHandlers();
    QMap<ReqId, std::function<void(const QJsonObject&)>> _handlers;
};

#endif // RESETCONTROLLER_H
