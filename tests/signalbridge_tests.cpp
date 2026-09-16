#include "privatechat/signalbridge.h"
#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <cstdio>

static void check(bool ok, const char *message) {
    if (!ok) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}
int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    SignalBridge bridge;
    check(bridge.available(), "load Signal bridge ABI");
    auto call = [&bridge](const QJsonObject &input) {
        return QJsonDocument::fromJson(bridge.execute(QJsonDocument(input).toJson(QJsonDocument::Compact))).object();
    };
    auto alice = call({{"op", "create"}, {"account", "alice"}});
    auto bob = call({{"op", "create"}, {"account", "bob"}});
    const QJsonValue aIdentity = alice["identity"], bIdentity = bob["identity"];
    check(!aIdentity.toArray().isEmpty() && !bIdentity.toArray().isEmpty(), "create identities");
    alice = call({{"op", "approve"}, {"state", alice["state"]}, {"peer", "bob"}, {"identity", bIdentity}});
    bob = call({{"op", "approve"}, {"state", bob["state"]}, {"peer", "alice"}, {"identity", aIdentity}});
    check(alice["safety_number"].toString().size() == 60 && alice["safety_number"] == bob["safety_number"], "safety numbers");
    bob = call({{"op", "bundle"}, {"state", bob["state"]}});
    alice = call({{"op", "establish"}, {"state", alice["state"]}, {"peer", "bob"}, {"bundle", bob["bundle"]}});
    alice = call({{"op", "encrypt"}, {"state", alice["state"]}, {"peer", "bob"}, {"plaintext", QJsonArray{104, 105}}});
    check(!alice["ciphertext"].toArray().isEmpty(), "encrypted output");
    bob = call({{"op", "decrypt"}, {"state", bob["state"]}, {"peer", "alice"}, {"kind", alice["kind"]}, {"ciphertext", alice["ciphertext"]}});
    check(bob["plaintext"].toArray() == QJsonArray{104, 105}, "Qt to Rust decryption");
    check(bridge.execute("invalid").isEmpty(), "invalid ABI request");
    std::puts("Qt C++ / Rust Signal bridge tests passed");
}
