#include "privatechat/privatechattransport.h"
#include <QCoreApplication>
#include <QTcpServer>
#include <QTcpSocket>
#include <QElapsedTimer>
#include <QThread>
#include <QJsonArray>
#include <cstdio>

static void check(bool ok, const char *message) { if (!ok) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); } }
int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    PrivateChatTransport transport;
    check(!transport.beginSession(1, QString(64, 'a'), QUrl("http://192.168.1.1:8081")), "reject remote plaintext");
    check(!transport.beginSession(1, QString(64, 'a'), QUrl("https://user:secret@example.com")), "reject URL credentials");
    QTcpServer server; check(server.listen(QHostAddress::LocalHost), "test listener");
    check(transport.beginSession(1, QString(64, 'a'), QUrl("http://127.0.0.1:" + QString::number(server.serverPort()))), "loopback development transport");
    QJsonArray identity; for (int i = 0; i < 33; ++i) identity.append(5);
    const QString id = "d987030a-e41c-4fde-bca9-71c2ce109111";
    QJsonObject request{{"op", "register"}, {"request_id", id}, {"identity", identity}};
    auto privateData = request; privateData["state"] = "private key";
    check(!transport.submit(privateData), "reject protocol state at network boundary");
    bool complete = false;
    QObject::connect(&transport, &PrivateChatTransport::finished, &app, [&](QString received, QJsonObject response) {
        check(received == id && response["error"].toInt() == 0, "correlated response"); complete = true;
    });
    QObject::connect(&server, &QTcpServer::newConnection, &app, [&] {
        auto *socket = server.nextPendingConnection();
        QObject::connect(socket, &QTcpSocket::readyRead, socket, [socket, id] {
            auto buffer = socket->property("received").toByteArray() + socket->readAll(); socket->setProperty("received", buffer);
            if (!buffer.contains("\r\n\r\n") || !buffer.contains("\"uid\":1")) return;
            check(!buffer.contains("private key"), "no private state uploaded");
            const auto body = QByteArray("{\"error\":0,\"request_id\":\"") + id.toUtf8() + "\"}";
            socket->write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: " + QByteArray::number(body.size()) + "\r\nConnection: close\r\n\r\n" + body);
            socket->disconnectFromHost();
        });
        QObject::connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
    });
    check(transport.submit(request), "submit");
    check(!transport.submit(request), "one request in flight");
    QElapsedTimer timer; timer.start();
    while (!complete && timer.elapsed() < 3000) { QCoreApplication::processEvents(); QThread::msleep(1); }
    check(complete, "transport completes");
    transport.endSession(); check(!transport.submit(request), "logout stops requests");
    std::puts("Private ciphertext transport tests passed");
}
