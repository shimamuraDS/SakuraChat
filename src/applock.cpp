#include "applock.h"
#include "localprotection.h"
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QGuiApplication>
#include <QEvent>
#include <QFutureWatcher>
#include <QPasswordDigestor>
#include <QRandomGenerator>
#include <QtConcurrent/QtConcurrentRun>
#include <algorithm>

AppLock &AppLock::instance() { static AppLock lock; return lock; }
AppLock::AppLock() {
    _clock.start();
    qApp->installEventFilter(this);
    connect(qApp, &QGuiApplication::applicationStateChanged, this, [this](Qt::ApplicationState state) {
        if (state != Qt::ApplicationActive) lock();
    });
    _timer.setInterval(1000);
    connect(&_timer, &QTimer::timeout, this, [this] {
        if (_session && enabled() && !_locked && _clock.elapsed() - _lastInput >= 300000) lock();
        if (_retryAt && _clock.elapsed() >= _retryAt) {
            _retryAt = 0; _message = tr("可以重新输入解锁密码"); emit changed();
        }
    });
    _timer.start();
}
bool AppLock::eventFilter(QObject *, QEvent *event) {
    if (_session && !_locked && event->spontaneous()) {
        switch (event->type()) {
        case QEvent::KeyPress: case QEvent::MouseButtonPress: case QEvent::MouseMove:
        case QEvent::Wheel: case QEvent::TouchBegin:
            _lastInput = _clock.elapsed(); break;
        default: break;
        }
    }
    return false;
}
void AppLock::beginSession(int uid, const QString &environment) {
    endSession(); _session = true; _lastInput = _clock.elapsed();
    const auto base = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    const auto account = QCryptographicHash::hash(environment.toUtf8(), QCryptographicHash::Sha256).toHex()
        + '-' + QByteArray::number(uid);
    _settingsContext = "SakuraChat-app-lock-v1:" + account;
    auto failed = [this] {
        _configurationFailed = true; _locked = true;
        _message = tr("无法读取应用锁设置。请保留设置文件并使用原 Windows 用户恢复；退出登录不会清除此锁。");
        emit changed();
    };
    if (base.isEmpty() || uid <= 0 || !QDir().mkpath(base + "/security")) { failed(); return; }
    _settingsPath = base + "/security/" + QString::fromLatin1(account) + ".lock";
    QFile file(_settingsPath);
    if (!file.exists()) { emit changed(); return; }
    if (!file.open(QIODevice::ReadOnly) || file.size() > 16384) { failed(); return; }
    auto plain = LocalProtection::unprotect(file.readAll(), _settingsContext);
    const auto document = QJsonDocument::fromJson(plain); plain.fill(0);
    const auto object = document.object();
    if (!document.isObject() || object["version"].toInt() != 1 || !object["enabled"].isBool()) { failed(); return; }
    if (!object["enabled"].toBool()) { emit changed(); return; }
    const auto salt = QByteArray::fromHex(object["salt"].toString().toLatin1());
    const auto verifier = QByteArray::fromHex(object["verifier"].toString().toLatin1());
    if (object["iterations"].toInt() != 600000 || salt.size() != 32 || verifier.size() != 32) { failed(); return; }
    _salt = salt; _verifier = verifier; _locked = true;
    _message = tr("请输入此账号的应用锁密码"); emit changed();
}

bool AppLock::persist(bool enabled) {
    if (_settingsPath.isEmpty() || _configurationFailed) return false;
    QJsonObject object{{"version",1},{"enabled",enabled}};
    if (enabled) {
        object["salt"] = QString::fromLatin1(_salt.toHex());
        object["verifier"] = QString::fromLatin1(_verifier.toHex());
        object["iterations"] = 600000;
    }
    auto plain = QJsonDocument(object).toJson(QJsonDocument::Compact);
    const auto sealed = LocalProtection::protect(plain, _settingsContext); plain.fill(0);
    if (sealed.isEmpty()) return false;
    QSaveFile file(_settingsPath);
    file.setDirectWriteFallback(false);
    return file.open(QIODevice::WriteOnly) && file.write(sealed) == sealed.size() && file.commit();
}

void AppLock::disable() {
    if (!_session || _locked || _busy || !enabled() || _configurationFailed) return;
    if (!persist(false)) { _message = tr("无法保存设置，应用锁仍然有效"); emit changed(); return; }
    _salt.fill(0); _salt.clear(); _verifier.fill(0); _verifier.clear();
    _message = tr("已关闭此账号在本机的应用锁"); emit changed();
}
void AppLock::endSession() {
    ++_generation;
    _session = false; _locked = false;
    _settingsPath.clear(); _settingsContext.clear(); _configurationFailed = false;
    _salt.fill(0); _salt.clear(); _verifier.fill(0); _verifier.clear();
    _failures = 0; _retryAt = 0; _message.clear();
    // A running KDF stays busy until its result is discarded; do not spawn an unbounded backlog.
    emit changed();
}
void AppLock::lock() {
    if (!_session || !enabled() || _locked) return;
    _locked = true; _message.clear(); emit changed();
}
void AppLock::configure(const QString &password, const QString &confirmation) {
    if (!_session || enabled() || _locked || _busy) return;
    const auto bytes = password.toUtf8();
    if (password != confirmation || bytes.size() < 8 || bytes.size() > 128 || password.contains(QChar(0))) {
        _message = tr("两次密码须一致，长度为 8～128 个 UTF-8 字节"); emit changed(); return;
    }
    _salt.resize(32);
    for (int i = 0; i < _salt.size(); ++i) _salt[i] = char(QRandomGenerator::system()->generate() & 0xff);
    derive(password, true);
}
void AppLock::unlock(const QString &password) {
    if (!_session || !_locked || _busy || _configurationFailed) return;
    if (_clock.elapsed() < _retryAt) {
        _message = tr("尝试过于频繁，请等待冷却结束"); emit changed(); return;
    }
    if (password.toUtf8().size() > 128) { _message = tr("解锁密码不正确"); emit changed(); return; }
    derive(password, false);
}
void AppLock::derive(QString password, bool configuring) {
    _busy = true; _message = tr("正在处理…"); emit changed();
    const auto generation = _generation;
    const auto salt = _salt;
    auto *watcher = new QFutureWatcher<QByteArray>(this);
    connect(watcher, &QFutureWatcher<QByteArray>::finished, this, [this, watcher, generation, configuring] {
        auto key = watcher->result(); watcher->deleteLater(); _busy = false;
        if (generation != _generation || !_session) { key.fill(0); emit changed(); return; }
        if (key.size() != 32) { _message = tr("无法处理解锁密码，请稍后重试"); emit changed(); return; }
        if (configuring) {
            _verifier = key; _lastInput = _clock.elapsed();
            if (!persist(true)) {
                _verifier.fill(0); _verifier.clear(); _salt.fill(0); _salt.clear();
                _message = tr("无法保存应用锁设置，尚未启用；请检查 Windows 用户配置和目录权限");
                key.fill(0); emit changed(); return;
            }
            _message = tr("已保存此账号的应用锁设置，下次登录仍然有效");
            if (QGuiApplication::applicationState() != Qt::ApplicationActive) lock();
        } else {
            unsigned int different = unsigned(key.size() ^ _verifier.size());
            for (int i = 0; i < key.size(); ++i)
                different |= static_cast<unsigned char>(key[i]) ^ static_cast<unsigned char>(i < _verifier.size() ? _verifier[i] : char(0));
            if (!different) {
                // Do not uncover a background window when an asynchronous check finishes.
                _locked = QGuiApplication::applicationState() != Qt::ApplicationActive;
                _failures = 0; _retryAt = 0;
                _lastInput = _clock.elapsed();
                _message = _locked ? tr("请回到应用后重新解锁") : QString();
            } else {
                ++_failures; _message = tr("解锁密码不正确");
                if (_failures >= 5) {
                    const int seconds = std::min(300, 30 * (1 << std::min(4, _failures - 5)));
                    _retryAt = _clock.elapsed() + seconds * 1000;
                    _message = tr("尝试过于频繁，请等待 %1 秒").arg(seconds);
                }
            }
        }
        key.fill(0); emit changed();
    });
    watcher->setFuture(QtConcurrent::run([bytes = password.toUtf8(), salt]() mutable {
        auto key = QPasswordDigestor::deriveKeyPbkdf2(QCryptographicHash::Sha256, bytes, salt, 600000, 32);
        bytes.fill(0);
        return key;
    }));
}
