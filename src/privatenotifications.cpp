#include "privatenotifications.h"
#include "applock.h"
#include <QGuiApplication>
#include <QStandardPaths>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonObject>

PrivateNotifications::PrivateNotifications(QObject *parent) : QObject(parent) {
    _clock.start();
    _tray.setIcon(QGuiApplication::windowIcon());
    _tray.setToolTip(QStringLiteral("SakuraChat"));
}
bool PrivateNotifications::available() const {
    return QSystemTrayIcon::isSystemTrayAvailable() && QSystemTrayIcon::supportsMessages();
}
void PrivateNotifications::beginSession(int uid, const QString &environment) {
    endSession();
    const auto base = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    if (uid <= 0 || base.isEmpty() || !QDir().mkpath(base + "/security")) {
        _message = tr("无法打开通知设置目录，通知保持关闭"); emit changed(); return;
    }
    const auto key = QCryptographicHash::hash(environment.toUtf8(), QCryptographicHash::Sha256).toHex();
    _path = base + "/security/" + QString::fromLatin1(key) + '-' + QString::number(uid) + ".notifications.json";
    _session = true;
    QFile file(_path);
    if (file.exists()) {
        if (!file.open(QIODevice::ReadOnly) || file.size() > 1024) {
            _message = tr("无法读取通知设置，通知保持关闭"); emit changed(); return;
        }
        const auto object = QJsonDocument::fromJson(file.readAll()).object();
        if (object["version"].toInt() != 1 || !object["enabled"].isBool()) {
            _message = tr("通知设置无效，通知保持关闭"); emit changed(); return;
        }
        _enabled = object["enabled"].toBool();
    }
    if (_enabled && available()) _tray.show();
    emit changed();
}
void PrivateNotifications::endSession() {
    _tray.hide(); _enabled = false; _session = false; _path.clear(); _message.clear();
    _lastShown = -5000; emit changed();
}
void PrivateNotifications::setEnabled(bool enabled) {
    if (!_session || _path.isEmpty() || AppLock::instance().locked()) return;
    QSaveFile file(_path); file.setDirectWriteFallback(false);
    const auto data = QJsonDocument(QJsonObject{{"version",1},{"enabled",enabled}}).toJson(QJsonDocument::Compact);
    if (!file.open(QIODevice::WriteOnly) || file.write(data) != data.size() || !file.commit()) {
        _message = tr("无法保存通知设置，原设置未改变"); emit changed(); return;
    }
    _enabled = enabled;
    if (_enabled && available()) _tray.show(); else _tray.hide();
    _message = enabled ? tr("已开启通用提醒，不包含联系人或消息正文") : tr("已关闭桌面提醒");
    emit changed();
}
void PrivateNotifications::notifyNewMessage() {
    if (!_session || !_enabled || !available()) return;
    if (QGuiApplication::applicationState() == Qt::ApplicationActive && !AppLock::instance().locked()) return;
    const auto now = _clock.elapsed();
    if (now - _lastShown < 5000) return;
    _lastShown = now;
    _tray.showMessage(QStringLiteral("SakuraChat"), tr("你有新的聊天消息，请打开应用查看。"), QSystemTrayIcon::Information, 5000);
}
