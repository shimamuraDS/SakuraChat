#include "updatecontroller.h"
#include "releaseinfo.h"
#include <QCoreApplication>
#include <QJsonDocument>
#include <cstdio>
#include <cstdlib>
static void check(bool ok, const char *message) {
    if (!ok) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}
class UpdateControllerTest {
public:
    static void run() {
        check(ReleaseInfo::version("v1.10.0") > ReleaseInfo::version("1.9.9"), "numeric comparison");
        for (const auto &tag : {"v1.2.3-beta", "1.2", "1.2.3/evil", "01.2.3", "999999999999.2.3"})
            check(ReleaseInfo::version(tag).isNull(), "malformed or prerelease tag rejected");
        UpdateController controller;
        const auto current = ReleaseInfo::version(controller.version());
        QJsonObject release{{"tag_name", QString::number(current.majorVersion() + 1) + ".0.0"}, {"draft", false}, {"prerelease", false}, {"body", "Release notes"}, {"html_url", "https://evil.invalid/"}};
        controller.processResponse(200, true, QJsonDocument(release).toJson());
        check(controller.updateAvailable() && controller.notes() == "Release notes", "stable newer release detected");
        release["prerelease"] = true;
        check(!ReleaseInfo::stable(release), "prerelease ignored");
        release["prerelease"] = false; release["draft"] = true;
        check(!ReleaseInfo::stable(release), "draft ignored");
        release["draft"] = false; release["tag_name"] = "v" + controller.version();
        controller.processResponse(200, true, QJsonDocument(release).toJson());
        check(!controller.updateAvailable(), "same version not an update");
        controller.processResponse(404, false, {});
        check(!controller.status().isEmpty() && !controller.updateAvailable(), "no public release handled");
        controller.processResponse(0, false, {});
        check(!controller.status().isEmpty(), "offline failure handled");
        controller.processResponse(403, false, {});
        check(controller.retryAt_ > QDateTime::currentDateTimeUtc(), "rate limit cooldown");
        controller.processResponse(200, true, QByteArray("invalid json"));
        check(!controller.updateAvailable(), "bad response not accepted as update");
    }
};
int main(int argc, char **argv) {
    QCoreApplication app(argc, argv); UpdateControllerTest::run();
    std::puts("GitHub release comparison and response tests passed");
}
