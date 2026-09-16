#include "messagelistmodel.h"
#include <QGuiApplication>
#include <QQuickView>
#include <QQuickItem>
#include <QEventLoop>
#include <QTimer>
#include <cstdio>
#include <cstdlib>

static void check(bool ok, const char *message) {
    if (!ok) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}
static void wait(int ms) { QEventLoop loop; QTimer::singleShot(ms, &loop, &QEventLoop::quit); loop.exec(); }
int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    qmlRegisterType<MessageListModel>("SakuraChat", 1, 0, "MessageListModel");
    qmlRegisterSingletonType(QUrl::fromLocalFile(SOURCE_DIR "/qml/UiTheme.qml"), "SakuraChat", 1, 0, "UiTheme");
    QQuickView view;
    view.setSource(QUrl::fromLocalFile(SOURCE_DIR "/tests/ChatViewHarness.qml"));
    for (const auto &error : view.errors()) std::fprintf(stderr, "%s\n", qPrintable(error.toString()));
    check(view.status() == QQuickView::Ready, "chat view loads");
    view.show();
    auto *root = view.rootObject();
    QVariantMap message{{"senderUid",2}, {"msgid","one"}, {"messageId","1"}, {"messageText","hello"},
                        {"isSentByMe",false}, {"localRead",false}};
    const QVariantList rows{message};
    root->setProperty("messageRows", rows);
    // Refreshes faster than the dwell threshold must not destroy its timer.
    for (int i = 0; i < 6; ++i) { wait(200); root->setProperty("messageRows", rows); }
    check(root->property("readCount").toInt() == 1, "unchanged refresh does not interrupt read dwell");
    message["localRead"] = true;
    root->setProperty("messageRows", QVariantList{message});
    wait(900);
    check(root->property("readCount").toInt() == 1, "already read message not re-emitted");
    root->setProperty("conversationVisible", false);
    message["msgid"] = "two"; message["messageId"] = "2"; message["localRead"] = false;
    root->setProperty("messageRows", QVariantList{message});
    wait(900);
    check(root->property("readCount").toInt() == 1, "hidden conversation does not mark read");
    root->setProperty("conversationVisible", true);
    wait(1000);
    check(root->property("readCount").toInt() == 2, "focus restoration starts read dwell");
    std::puts("Chat view read dwell and focus tests passed");
}
