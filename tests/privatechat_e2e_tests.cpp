#include "privatechat/privatechatengine.h"
#include "privatechat/privatechattransport.h"
#include <QCoreApplication>
#include <QTemporaryDir>
#include <QEventLoop>
#include <QTimer>
#include <QJsonArray>
#include <QUuid>
#include <cstdio>
#include <stdexcept>

static void check(bool ok, const char *message) { if (!ok) throw std::runtime_error(message); }
static QJsonObject local(PrivateChatEngine &engine, QJsonObject command) {
    auto result = engine.execute(command); check(result["ok"].toBool(), "local protocol/storage operation failed"); return result;
}
static QJsonObject remote(PrivateChatTransport &transport, QJsonObject command, QJsonValue identity, bool expectSuccess = true) {
    command["identity"] = identity;
    if (!command.contains("request_id")) command["request_id"] = QUuid::createUuid().toString(QUuid::WithoutBraces);
    QEventLoop loop; QTimer deadline; deadline.setSingleShot(true);
    QJsonObject result;
    auto connection = QObject::connect(&transport, &PrivateChatTransport::finished, &loop, [&](QString, QJsonObject r) { result = r; loop.quit(); });
    QObject::connect(&deadline, &QTimer::timeout, &loop, &QEventLoop::quit);
    check(transport.submit(command), "request rejected locally"); deadline.start(12000); loop.exec();
    QObject::disconnect(connection);
    check(!result.isEmpty(), "request timeout");
    if (expectSuccess && result["error"].toInt(-1) != 0)
        throw std::runtime_error("remote error " + std::to_string(result["error"].toInt(-1)));
    return result;
}
static void deliver(PrivateChatEngine &sender, PrivateChatTransport &tx, QJsonValue senderIdentity,
                    PrivateChatEngine &receiver, PrivateChatTransport &rx, QJsonValue receiverIdentity,
                    int senderUid, int receiverUid, const QString &text) {
    local(sender, {{"op", "send"}, {"peer", receiverUid}, {"text", text}});
    auto envelope = local(sender, {{"op", "pending"}})["outbox"].toArray().first().toObject();
    QByteArray cipher; for (auto byte : envelope["ciphertext"].toArray()) cipher.append(char(byte.toInt()));
    check(!cipher.contains(text.toUtf8()), "ciphertext contains plaintext");
    envelope["ciphertext"] = QString::fromLatin1(cipher.toBase64());
    envelope["peer"] = receiverUid; envelope["op"] = "send";
    remote(tx, envelope, senderIdentity); remote(tx, envelope, senderIdentity);
    const auto incoming = remote(rx, {{"op", "poll"}}, receiverIdentity)["envelope"].toObject();
    check(incoming["id"] == envelope["id"], "relay preserved message id");
    local(receiver, {{"op", "receive"}, {"envelope", incoming}});
    local(receiver, {{"op", "receive"}, {"envelope", incoming}});
    remote(rx, {{"op", "ack"}, {"sequence", incoming["sequence"]}}, receiverIdentity);
    local(sender, {{"op", "ack"}, {"id", envelope["id"]}});
    check(!remote(rx, {{"op", "poll"}}, receiverIdentity).contains("envelope"), "inbox empty after acknowledgement");
    const auto history = local(receiver, {{"op", "history"}, {"peer", senderUid}})["messages"].toArray();
    check(history.last().toObject()["text"] == text, "decrypted text matches");
}
int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    try {
        check(argc == 2 && qEnvironmentVariableIsSet("SAKURA_TEST_ISOLATED_REDIS"), "isolated harness required");
        const QUrl gateway(QString::fromLocal8Bit(argv[1]));
        check(gateway.host() == "127.0.0.1", "loopback fixture required");
        QTemporaryDir directory; check(directory.isValid(), "temporary directory");
        PrivateChatEngine alice(directory.path()), bob(directory.path());
        const QJsonObject openAlice{{"op", "open"}, {"uid", 1}, {"scope", gateway.toString()}};
        const QJsonObject openBob{{"op", "open"}, {"uid", 2}, {"scope", gateway.toString()}};
        const QJsonValue a = local(alice, openAlice)["identity"], b = local(bob, openBob)["identity"];
        PrivateChatTransport tx, rx, invalid;
        check(tx.beginSession(1, QString(64, 'a'), gateway) && rx.beginSession(2, QString(64, 'b'), gateway), "start transport sessions");
        check(invalid.beginSession(1, QString(64, 'b'), gateway), "invalid token transport");
        check(remote(invalid, {{"op", "register"}}, a, false)["error"].toInt() == 1010, "real Redis rejects another account token");
        remote(tx, {{"op", "register"}}, a); remote(rx, {{"op", "register"}}, b);
        const QJsonValue bundle = local(bob, {{"op", "bundle"}})["bundle"];
        remote(rx, {{"op", "publish"}, {"bundle", bundle}}, b); local(bob, {{"op", "published"}});
        const auto safetyA = local(alice, {{"op", "first_trust"}, {"peer", 2}, {"identity", b}});
        check(!safetyA["verified"].toBool(), "first trust does not claim manual verification");
        const auto safetyB = local(bob, {{"op", "safety_number"}, {"peer", 1}, {"identity", a}});
        check(safetyA["safety_number"] == safetyB["safety_number"], "safety numbers match");
        const auto claimed = remote(tx, {{"op", "claim"}, {"peer", 2}}, a);
        local(alice, {{"op", "establish"}, {"peer", 2}, {"bundle", claimed["bundle"]}});
        deliver(alice, tx, a, bob, rx, b, 1, 2, QStringLiteral("Signal encrypted hello / 私密消息"));
        local(bob, {{"op", "close"}}); check(local(bob, openBob)["identity"] == b, "identity survives reopen");
        deliver(bob, rx, b, alice, tx, a, 2, 1, QStringLiteral("Encrypted reply after restart"));
        tx.endSession(); rx.endSession();
        std::puts("Signal clients / GateServer / Redis / MySQL E2E tests passed"); return 0;
    } catch (const std::exception &e) { std::fprintf(stderr, "E2E failed: %s\n", e.what()); return 1; }
}
