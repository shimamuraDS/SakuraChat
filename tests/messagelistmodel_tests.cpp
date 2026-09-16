#include "messagelistmodel.h"
#include <QCoreApplication>
#include <QPersistentModelIndex>
#include <cstdio>
#include <cstdlib>

static void check(bool ok, const char *message) {
    if (!ok) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}
static QVariant row(const char *id, bool read = false) {
    return QVariantMap{{"senderUid", 2}, {"msgid", id}, {"localRead", read}};
}
int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    MessageListModel model;
    int resets = 0, changes = 0, notifications = 0;
    QObject::connect(&model, &QAbstractItemModel::modelReset, [&] { ++resets; });
    QObject::connect(&model, &QAbstractItemModel::dataChanged, [&] { ++changes; });
    QObject::connect(&model, &MessageListModel::rowsChanged, [&] { ++notifications; });
    model.setRows({row("a"), row("b")});
    QPersistentModelIndex a(model.index(0)), b(model.index(1));
    for (int i = 0; i < 20; ++i) model.setRows({row("a"), row("b")});
    check(changes == 0 && notifications == 1, "unchanged refresh is silent");
    model.setRows({row("a", true), row("b")});
    check(changes == 1 && a.isValid() && b.isValid(), "read status preserves message items");
    model.setRows({row("older"), row("a", true), row("b"), row("new")});
    check(a.row() == 1 && b.row() == 2, "paging and append preserve existing items");
    model.setRows({row("b"), row("a", true)});
    check(a.row() == 1 && b.row() == 0 && model.rowCount() == 2, "move and removal preserve retained identities");
    model.setRows({});
    check(!a.isValid() && !b.isValid() && resets == 0, "clear removes data without resetting model");
    std::puts("Message list incremental update tests passed");
}
