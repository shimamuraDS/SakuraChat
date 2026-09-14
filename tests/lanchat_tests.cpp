#include "lanchat.h"
#include <QCoreApplication>
#include <QElapsedTimer>
#include <QThread>
#include <functional>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSslError>
#include <cstdio>

static void check(bool value, const char *message) { if (!value) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); } }
static bool waitFor(const std::function<bool()> &predicate) {
    QElapsedTimer timer; timer.start();
    while (!predicate() && timer.elapsed() < 3000) {
        QCoreApplication::processEvents(); QThread::msleep(1);
    }
    return predicate();
}
int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    QTcpServer reserve;
    check(reserve.listen(QHostAddress::LocalHost), "reserve port");
    const auto port = reserve.serverPort(); reserve.close();
    LanChat host, first, second;
    host.host("host", port);
    if (host.state() != "hosting") std::fprintf(stderr, "%s\n", host.notice().toUtf8().constData());
    check(host.state() == "hosting", "host room");
    first.join("first", "127.0.0.1", port, host.fingerprint(), host.invitation());
    second.join("second", "127.0.0.1", port, host.fingerprint(), host.invitation());
    check(waitFor([&] { return first.state() == "joined" && second.state() == "joined"; }), "join room");
    check(first.send("hello\nworld"), "send message");
    check(waitFor([&] { return host.messages().size() == 1 && second.messages().size() == 1 && first.messages().size() == 1; }), "broadcast echo");
    check(second.messages().first().toMap()["text"] == "hello\nworld", "preserve multiline");
    check(!first.send(QString(2001, 'x')), "reject oversized text");
    QSslSocket raw;
    QObject::connect(&raw, &QSslSocket::sslErrors, &raw, [&](const QList<QSslError> &errors) {
        check(raw.peerCertificate().digest(QCryptographicHash::Sha256).toHex() == host.fingerprint().toLatin1(), "raw pin");
        raw.ignoreSslErrors(errors);
    });
    raw.connectToHostEncrypted("127.0.0.1", port);
    check(waitFor([&] { return raw.isEncrypted(); }), "encrypted connection");
    raw.write("{\"type\":\"hello\",\"version\":2,"); raw.flush();
    QCoreApplication::processEvents();
    raw.write("\"name\":\"raw\",\"invitation\":\"" + host.invitation().toLatin1() + "\"}\n{\"type\":\"send\",\"text\":\"split\"}\n");
    check(waitFor([&] { return host.messages().size() == 2; }), "split and coalesced frames");
    raw.write("invalid\n");
    check(waitFor([&] { return raw.state() == QAbstractSocket::UnconnectedState; }), "reject malformed protocol");
    LanChat wrongPin, wrongToken;
    wrongPin.join("bad", "127.0.0.1", port, QString(64, '0'), host.invitation());
    check(waitFor([&] { return wrongPin.state() == "idle"; }), "reject wrong certificate");
    wrongToken.join("bad", "127.0.0.1", port, host.fingerprint(), QString(32, '0'));
    check(waitFor([&] { return wrongToken.state() == "idle"; }), "reject wrong invitation");
    check(!wrongToken.send("not authenticated"), "no unauthenticated send");
    QTcpSocket plaintext;
    plaintext.connectToHost(QHostAddress::LocalHost, port);
    check(waitFor([&] { return plaintext.state() == QAbstractSocket::ConnectedState; }), "plain TCP connected");
    plaintext.write("{\"type\":\"hello\",\"version\":2,\"name\":\"bad\"}\n");
    check(waitFor([&] { return plaintext.state() == QAbstractSocket::UnconnectedState; }), "reject plaintext");
    host.leave();
    check(waitFor([&] { return first.state() == "idle" && second.state() == "idle"; }), "host shutdown");
    first.leave(); check(first.messages().isEmpty(), "clear on leave");
    first.join("user", "8.8.8.8", port, QString(64, '0'), QString(32, '0')); check(first.state() == "idle", "reject public address");
    std::puts("TLS LAN checks passed");
}
