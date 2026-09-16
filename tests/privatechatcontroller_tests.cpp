#include "privatechat/privatechatcontroller.h"
#include <QCoreApplication>
#include <cstdio>
#include <cstdlib>

class PrivateChatControllerTest {
    static void check(bool ok, const char *message) {
        if (!ok) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
    }
public:
    static void run() {
        PrivateChatController controller;
        int messageChanges = 0;
        QObject::connect(&controller, &PrivateChatController::messagesChanged, [&] { ++messageChanges; });
        const QVariantList rows{QVariantMap{{"id", "message"}, {"text", "hello"}}};
        controller.setMessages(rows);
        controller.setMessages(rows);
        controller.status("connection changed");
        check(messageChanges == 1, "unchanged history and connection status do not refresh messages");
        controller.active_ = true; controller.ready_ = true;
        controller.notice_ = "Compare safety numbers"; controller.safety_ = "verified-display-number";
        const QJsonObject request{{"op", "send"}, {"request_id", "d987030a-e41c-4fde-bca9-71c2ce109111"}, {"ciphertext", "AQID"}};
        int completions = 0;
        controller.pendingNetwork_ = request;
        controller.networkDone_ = [&](QJsonObject) { ++completions; };
        controller.busy_ = true;
        controller.transport_.finished("", {{"error", 1204}, {"retry_after", 17}});
        check(controller.notice_ == "Compare safety numbers" && controller.safety_ == "verified-display-number", "background failure preserves safety prompt");
        check(!controller.connectionNotice_.isEmpty(), "connection failure shown separately");
        check(!controller.canRetry() && controller.retryTimer_.isActive(), "cooldown disables immediate retry");
        check(controller.retryDeadline_.remainingTime() > 16000, "server cooldown respected");
        controller.retry();
        check(completions == 0 && controller.failedNetwork_ == request, "cooldown preserves original request and ciphertext");
        controller.setActive(false);
        check(!controller.retryTimer_.isActive() && !controller.canRetry(), "hidden mode stops retry timer");
        controller.setActive(true);
        check(controller.retryTimer_.isActive() && !controller.canRetry(), "mode switching cannot bypass cooldown");
        controller.networkDone_ = controller.failedDone_;
        controller.transport_.finished("", {{"error", 0}});
        check(completions == 1 && controller.failedNetwork_.isEmpty() && controller.connectionNotice_.isEmpty(), "success clears only connection failure");
        check(controller.notice_ == "Compare safety numbers" && controller.canRetry(), "success retains safety prompt");
        controller.pendingNetwork_ = request;
        controller.transport_.finished("", {{"error", 1207}});
        const auto firstDelay = controller.retryDeadline_.remainingTime();
        controller.transport_.finished("", {{"error", 1207}});
        check(controller.retryDeadline_.remainingTime() > firstDelay, "unavailable service retries with backoff");
        controller.endSession();
        check(messageChanges == 2 && controller.messages().isEmpty(), "logout clears messages with notification");
        check(!controller.retryTimer_.isActive() && controller.failedNetwork_.isEmpty(), "logout cancels queued retry");
        controller.active_ = true; controller.pendingNetwork_ = request;
        controller.transport_.finished("", {{"error", 1208}});
        check(!controller.retryTimer_.isActive(), "capacity errors do not auto-retry");
    }
};
int main(int argc, char **argv) {
    QCoreApplication app(argc, argv); PrivateChatControllerTest::run();
    std::puts("Private controller cooldown and status tests passed");
}
