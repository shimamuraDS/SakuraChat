#include "privatechat/privatechatengine.h"
#include <QCoreApplication>
#include <QTemporaryDir>
#include <QJsonArray>
#include <QUuid>
#include <cstdio>
#include <cstdlib>

static void check(bool value, const char *message) {
    if (!value) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}
static QJsonObject run(PrivateChatEngine &engine, const QJsonObject &command) {
    const auto result = engine.execute(command);
    check(result["ok"].toBool(), "engine operation");
    return result;
}
static QJsonObject wire(PrivateChatEngine &engine, int sender, const QJsonValue &identity) {
    const auto outgoing = run(engine, {{"op", "pending"}})["outbox"].toArray().last().toObject();
    QByteArray cipher;
    for (auto byte : outgoing["ciphertext"].toArray()) cipher.append(char(byte.toInt()));
    return {{"sender", sender}, {"identity", identity}, {"id", outgoing["id"]},
            {"kind", outgoing["kind"]}, {"ciphertext", QString::fromLatin1(cipher.toBase64())}};
}
int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    QTemporaryDir directory;
    check(directory.isValid(), "temporary storage");
    PrivateChatEngine alice(directory.path()), bob(directory.path());
    const QJsonObject openAlice{{"op", "open"}, {"uid", 1}, {"scope", "isolated-test"}};
    const QJsonObject openBob{{"op", "open"}, {"uid", 2}, {"scope", "isolated-test"}};
    const QJsonValue aliceIdentity = run(alice, openAlice)["identity"];
    const QJsonValue bobIdentity = run(bob, openBob)["identity"];
    const QJsonValue bundle = run(bob, {{"op", "bundle"}})["bundle"];
    run(bob, {{"op", "close"}});
    run(bob, openBob);
    check(run(bob, {{"op", "bundle"}})["bundle"] == bundle, "pending public bundle survives restart");
    run(bob, {{"op", "published"}});
    check(!alice.execute({{"op", "establish"}, {"peer", 2}, {"bundle", bundle}})["ok"].toBool(), "unknown identity denied");
    const auto a = run(alice, {{"op", "first_trust"}, {"peer", 2}, {"identity", bobIdentity}});
    check(!a["verified"].toBool(), "first trust is not manual verification");
    const auto b = run(bob, {{"op", "safety_number"}, {"peer", 1}, {"identity", aliceIdentity}});
    check(a["safety_number"] == b["safety_number"], "matching safety numbers");
    run(alice, {{"op", "establish"}, {"peer", 2}, {"bundle", bundle}});
    run(alice, {{"op", "send"}, {"peer", 2}, {"text", "private hello"}});
    const auto first = wire(alice, 1, aliceIdentity);
    auto wrongIdentity = first;
    wrongIdentity["identity"] = bobIdentity;
    check(!bob.execute({{"op", "receive"}, {"envelope", wrongIdentity}})["ok"].toBool(), "unauthenticated identity not pinned");
    auto wrongId = first;
    wrongId["id"] = QUuid::createUuid().toString(QUuid::WithoutBraces);
    check(!bob.execute({{"op", "receive"}, {"envelope", wrongId}})["ok"].toBool(), "authenticated envelope id checked");
    check(run(bob, {{"op", "history"}, {"peer", 1}})["messages"].toArray().isEmpty(), "invalid envelope not saved");
    run(bob, {{"op", "receive"}, {"envelope", first}});
    const auto trust = run(bob, {{"op", "first_trust"}, {"peer", 1}, {"identity", aliceIdentity}});
    check(!trust["verified"].toBool() && !trust["identity_changed"].toBool(), "authenticated incoming message pins without manual verification");
    run(bob, {{"op", "close"}});
    check(run(bob, openBob)["identity"] == bobIdentity, "identity retained across restart");
    run(bob, {{"op", "receive"}, {"envelope", first}});
    const auto history = run(bob, {{"op", "history"}, {"peer", 1}})["messages"].toArray();
    check(history.size() == 1 && history.first().toObject()["text"] == "private hello", "receive retry deduplicated after restart");
    run(bob, {{"op", "send"}, {"peer", 1}, {"text", "private reply"}});
    run(alice, {{"op", "receive"}, {"envelope", wire(bob, 2, bobIdentity)}});
    check(run(alice, {{"op", "history"}, {"peer", 2}})["messages"].toArray().size() == 2, "bidirectional persisted messages");
    run(alice, {{"op", "ack"}, {"id", first["id"]}});
    check(run(alice, {{"op", "pending"}})["outbox"].toArray().isEmpty(), "accepted envelope removed");
    check(run(alice, {{"op", "approve"}, {"peer", 2}, {"identity", bobIdentity}})["has_session"].toBool(), "verified session reusable");
    check(!alice.execute({{"op", "open"}, {"uid", 3}, {"scope", ""}})["ok"].toBool(), "invalid account scope rejected");
    check(!alice.execute({{"op", "send"}, {"peer", 2}, {"text", "must not send"}})["ok"].toBool(), "failed account switch closes previous session");
    std::puts("Private engine two-device persistence tests passed");
}
