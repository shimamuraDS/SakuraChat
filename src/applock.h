#pragma once
#include <QObject>
#include <QByteArray>
#include <QElapsedTimer>
#include <QTimer>

// Account/environment-scoped UI lock. This does not encrypt the chat repository.
class AppLock : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled NOTIFY changed)
    Q_PROPERTY(bool locked READ locked NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString message READ message NOTIFY changed)
public:
    static AppLock &instance();
    bool enabled() const { return !_verifier.isEmpty(); }
    bool locked() const { return _locked; }
    bool busy() const { return _busy; }
    QString message() const { return _message; }
    Q_INVOKABLE void configure(const QString &password, const QString &confirmation);
    Q_INVOKABLE void unlock(const QString &password);
    Q_INVOKABLE void lock();
    Q_INVOKABLE void disable();
    void beginSession(int uid, const QString &environment);
    void endSession();
signals:
    void changed();
protected:
    bool eventFilter(QObject *, QEvent *) override;
private:
    AppLock();
    void derive(QString password, bool configuring);
    bool persist(bool enabled);
    QString _settingsPath;
    QByteArray _settingsContext;
    bool _configurationFailed = false;
    QByteArray _salt, _verifier;
    bool _session = false, _locked = false, _busy = false;
    quint64 _generation = 0;
    int _failures = 0;
    qint64 _lastInput = 0, _retryAt = 0;
    QElapsedTimer _clock;
    QTimer _timer;
    QString _message;
};
