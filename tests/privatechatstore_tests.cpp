#include "privatechat/privatechatstore.h"
#include <QCoreApplication>
#include <QTemporaryDir>
#include <QJsonArray>
#include <QFile>
#include <cstdio>

static void check(bool value, const char *message) {
    if (!value) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}
int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    QTemporaryDir directory;
    check(directory.isValid(), "temporary directory");
    const auto path = directory.filePath("private.db");
    PrivateChatStore store;
    check(store.open(path, "1", "test-server"), "open");
    const QJsonObject first{{"private_key", "sensitive-test-key"}, {"step", 1}};
    check(store.commit(first), "initial state");
    PrivateChatStore stale;
    check(stale.open(path, "1", "test-server"), "second writer");
    const QJsonObject next{{"private_key", "sensitive-test-key"}, {"step", 2}};
    const QJsonObject envelope{{"id", "message-1"}, {"peer", "2"}, {"kind", 3}, {"ciphertext", QJsonArray{1, 2, 3}}};
    const QJsonObject sent{{"id", "message-1"}, {"peer", 2}, {"outgoing", true}, {"text", "secret-message-text"}};
    check(store.commit(next, envelope, sent), "atomic send");
    check(store.messages(2).first().toObject()["status"] == "pending", "pending message status");
    check(!stale.commit(first), "reject stale writer"); stale.close();
    check(!store.commit(first, envelope), "duplicate outbox rolls back");
    check(store.state() == next, "rollback preserves ratchet");
    store.close();
    QFile file(path); check(file.open(QIODevice::ReadOnly), "read database");
    const auto disk = file.readAll();
    check(!disk.contains("sensitive-test-key") && !disk.contains("secret-message-text"), "no plaintext key or message at rest"); file.close();
    check(store.open(path, "1", "test-server"), "reopen");
    check(store.state() == next && store.pending().size() == 1, "recovery");
    check(store.acknowledge("message-1") && store.pending().isEmpty(), "acknowledge");
    check(store.messages(2).first().toObject()["status"] == "sent", "server acceptance status");
    const QJsonObject received{{"id", "incoming-1"}, {"peer", 2}, {"outgoing", false}, {"text", "incoming-secret"}};
    check(store.commit(first, {}, received), "atomic receive");
    check(store.received(2, "incoming-1") && !store.received(3, "incoming-1"), "receipt scoped to sender");
    check(!store.commit(next, {}, received) && store.state() == first, "duplicate receive rolls back ratchet");
    store.close();
    check(store.open(path, "1", "test-server") && store.received(2, "incoming-1"), "receipt survives restart");
    check(store.messages(2).size() == 2, "message recovery");
    store.close();
    check(!store.open(path, "2", "test-server"), "wrong account fails closed");
    std::puts("Private state transaction tests passed");
}
