#include "updatecontroller.h"
#include "releaseinfo.h"
#include "releaseconfig.h"
#include <QDesktopServices>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QSettings>
#include <memory>

namespace {
QString settingsPath() { return "HKEY_CURRENT_USER\\Software\\SakuraChat\\ReleaseChecks"; }
}
UpdateController::UpdateController(QObject *parent) : QObject(parent), status_(tr("检查 GitHub 上的新版本。")) {
    QSettings settings(settingsPath(), QSettings::NativeFormat);
    automatic_ = settings.value("automatic", true).toBool();
    timer_.setInterval(3600000);
    connect(&timer_, &QTimer::timeout, this, &UpdateController::automaticCheck);
}
QString UpdateController::version() const { return QStringLiteral(SAKURA_RELEASE_VERSION); }
void UpdateController::initialize() { timer_.start(); automaticCheck(); }
void UpdateController::setAutomaticChecks(bool enabled) {
    automatic_ = enabled;
    QSettings(settingsPath(), QSettings::NativeFormat).setValue("automatic", enabled);
    emit changed();
}
void UpdateController::automaticCheck() {
    if (!automatic_) return;
    QSettings settings(settingsPath(), QSettings::NativeFormat);
    const auto last = settings.value("lastCheck").toDateTime();
    if (!last.isValid() || last.secsTo(QDateTime::currentDateTimeUtc()) >= 86400) check();
}
void UpdateController::check() {
    if (busy_) return;
    if (retryAt_ > QDateTime::currentDateTimeUtc()) {
        status_ = tr("检查稍频繁，请稍后再试。你仍可前往 GitHub 查看版本。"); emit changed(); return;
    }
    busy_ = true; status_ = tr("正在检查新版本…"); emit changed();
    retryAt_ = QDateTime::currentDateTimeUtc().addSecs(60);
    QSettings(settingsPath(), QSettings::NativeFormat).setValue("lastCheck", QDateTime::currentDateTimeUtc());
    QNetworkRequest request(QUrl("https://api.github.com/repos/" SAKURA_GITHUB_REPOSITORY "/releases/latest"));
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setRawHeader("X-GitHub-Api-Version", "2022-11-28");
    request.setRawHeader("User-Agent", "SakuraChat/" SAKURA_RELEASE_VERSION);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    request.setTransferTimeout(10000);
    auto *reply = network_.get(request);
    reply->setReadBufferSize(1024 * 1024 + 1);
    auto data = std::make_shared<QByteArray>();
    connect(reply, &QIODevice::readyRead, this, [reply, data] {
        data->append(reply->readAll()); if (data->size() > 1024 * 1024) reply->abort();
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, data] {
        data->append(reply->readAll()); reply->deleteLater(); busy_ = false;
        const auto code = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        processResponse(code, reply->error() == QNetworkReply::NoError, *data);
    });
}
void UpdateController::processResponse(int code, bool transportOk, const QByteArray &data) {
        if (code == 404) status_ = tr("暂未找到公开的正式版本，可前往 GitHub 查看。");
        else if (code == 403 || code == 429) {
            retryAt_ = QDateTime::currentDateTimeUtc().addSecs(3600);
            status_ = tr("GitHub 暂时限制了检查频率，请稍后再试。");
        } else if (!transportOk || code != 200 || data.size() > 1024 * 1024) {
            status_ = tr("暂时连不上 GitHub，不影响聊天。你可以稍后重试。");
        } else {
            const auto release = QJsonDocument::fromJson(data).object();
            if (!ReleaseInfo::stable(release)) status_ = tr("暂时无法识别发布版本，请前往 GitHub 查看。");
            else {
                latest_ = release["tag_name"].toString(); notes_ = release["body"].toString().left(16000);
                updateAvailable_ = ReleaseInfo::version(latest_) > ReleaseInfo::version(version());
                status_ = updateAvailable_ ? tr("新版本 %1 已发布。你可以自行选择下载时间。").arg(latest_)
                                          : tr("你已在使用最新正式版本或更新的构建。");
            }
        }
        emit changed();
}
void UpdateController::openReleasePage() {
    // Construct an allowlisted browser URL; do not follow a URL supplied in release metadata.
    const auto path = ReleaseInfo::version(latest_).isNull() ? QString() : "/tag/" + latest_;
    if (!QDesktopServices::openUrl(QUrl("https://github.com/" SAKURA_GITHUB_REPOSITORY "/releases" + path))) {
        status_ = tr("无法打开浏览器，请手动访问 GitHub 项目的 Releases 页面。"); emit changed();
    }
}
