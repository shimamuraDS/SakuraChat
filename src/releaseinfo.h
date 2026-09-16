#pragma once
#include <QJsonObject>
#include <QRegularExpression>
#include <QVersionNumber>

namespace ReleaseInfo {
inline QVersionNumber version(QString tag) {
    static const QRegularExpression pattern("^v?((0|[1-9][0-9]{0,8})[.](0|[1-9][0-9]{0,8})[.](0|[1-9][0-9]{0,8}))$");
    const auto match = pattern.match(tag);
    return match.hasMatch() ? QVersionNumber::fromString(match.captured(1)) : QVersionNumber();
}
inline bool stable(const QJsonObject &release) {
    return release["draft"].isBool() && !release["draft"].toBool() &&
        release["prerelease"].isBool() && !release["prerelease"].toBool() &&
        !version(release["tag_name"].toString()).isNull();
}
}
