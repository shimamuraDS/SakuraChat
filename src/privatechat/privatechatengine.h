#pragma once
#include <QObject>
#include "privatechatstore.h"
#include "signalbridge.h"
#include <memory>

// Invoked only on the private-chat worker; never owns network credentials.
class PrivateChatEngine final : public QObject {
public:
    explicit PrivateChatEngine(QString storageDirectory = {}) : storageDirectory_(std::move(storageDirectory)) {}
    QJsonObject execute(const QJsonObject &command);
private:
    QJsonObject protocol(QJsonObject request);
    PrivateChatStore store_;
    std::unique_ptr<SignalBridge> bridge_;
    int self_ = 0;
    QString storageDirectory_;
};
