#include "testbuildpolicy.h"
#include <cstdio>
#include <cstdlib>
static void check(bool value) { if (!value) std::abort(); }
int main() {
    check(TestBuildPolicy::permitsGateway(QUrl("https://sakura-gate.viphk.nnhk.cc/user_login")) == TestBuildPolicy::enabled);
    for (const auto *url : {"https://evil.example", "https://sakura-gate.viphk.nnhk.cc:81", "https://a@sakura-gate.viphk.nnhk.cc", "https://sakura-gate.viphk.nnhk.cc?x=1", "http://sakura-gate.viphk.nnhk.cc"})
        check(!TestBuildPolicy::permitsGateway(QUrl(url)));
    QString host = "127.0.0.1", port = "8090";
    check(TestBuildPolicy::resolveChat(host, port) == TestBuildPolicy::enabled);
    if (TestBuildPolicy::enabled) check(host == "viphk.nnhk.cc" && port == "25890");
    host = "localhost"; port = "8091";
    check(TestBuildPolicy::resolveChat(host, port) == TestBuildPolicy::enabled);
    if (TestBuildPolicy::enabled) check(host == "free.idcfengye.com" && port == "25891");
    host = "evil.example"; port = "25890"; check(!TestBuildPolicy::resolveChat(host, port));
    host = "viphk.nnhk.cc"; port = "8090"; check(!TestBuildPolicy::resolveChat(host, port));
    std::puts("Test build endpoint policy passed");
}
