#ifndef REGISTERCONTROLLER_H
#define REGISTERCONTROLLER_H
#include <QObject>
#include "global.h"
#include <QMap>
#include <QtQml/qqml.h>

class RegisterController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
public:
    explicit RegisterController(QObject *parent = nullptr);

    Q_INVOKABLE void getVerifyCode(const QString& email);
    Q_INVOKABLE void registerUser(const QString& username, const QString& email, const QString& varifyCode, const QString& password, const QString& confirm);

signals:
    void verifyCodeResult(bool success, const QString& message);
    void registerResult(bool success, const QString& message);
private:
    void initHttpHandlers();
    QMap<ReqId, std::function<void(const QJsonObject&)>> _handlers;

public slots:
    void slot_reg_mod_finish(ReqId id, QString res, ErrorCodes err);
};

#endif // REGISTERCONTROLLER_H
