#pragma once
#include "releaseconfig.h"
#include <QUrl>
#include <QString>

namespace TestBuildPolicy {
inline constexpr bool enabled = SAKURA_INSECURE_TEST;
inline QString gateway() { return QStringLiteral("https://sakura-gate.viphk.nnhk.cc"); }
inline bool permitsGateway(const QUrl &url) {
    return enabled && url.isValid() && url.scheme() == "https"
        && url.host() == "sakura-gate.viphk.nnhk.cc" && url.port(443) == 443
        && url.userInfo().isEmpty() && !url.hasQuery() && !url.hasFragment();
}
// Preserve node selection; only translate the two known local test listeners.
inline bool resolveChat(QString &host, QString &port) {
    if (!enabled) return false;
    const bool loopback = host == "localhost" || host == "127.0.0.1" || host == "::1";
    if (loopback && port == "8090") { host = "viphk.nnhk.cc"; port = "25890"; }
    else if (loopback && port == "8091") { host = "free.idcfengye.com"; port = "25891"; }
    return (host == "viphk.nnhk.cc" && port == "25890")
        || (host == "free.idcfengye.com" && port == "25891");
}
}
