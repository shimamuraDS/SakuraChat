#pragma once
#include <QByteArray>
#include <QLibrary>
#include <QString>

// This boundary handles local private state. Its request/response must never be sent over the network.
class SignalBridge final {
public:
    SignalBridge();
    bool available() const;
    QByteArray execute(const QByteArray &request) const;
private:
    struct Buffer { unsigned char *data; size_t len; };
    using Version = unsigned int (*)();
    using Call = int (*)(const unsigned char *, size_t, Buffer *);
    using Free = void (*)(Buffer);
    QLibrary library_;
    Call call_ = nullptr;
    Free free_ = nullptr;
};
