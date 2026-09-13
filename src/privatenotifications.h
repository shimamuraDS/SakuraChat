#pragma once
#include <QObject>
#include <QSystemTrayIcon>
#include <QElapsedTimer>

// Never accepts message bodies, sender names or UIDs as notification content.
class PrivateNotifications : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY changed)
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(QString message READ message NOTIFY changed)
public:
    explicit PrivateNotifications(QObject *parent = nullptr);
    bool enabled() const { return _enabled; }
    bool available() const;
    QString message() const { return _message; }
    void beginSession(int uid, const QString &environment);
    void endSession();
    void setEnabled(bool enabled);
    void notifyNewMessage();
signals:
    void changed();
private:
    QSystemTrayIcon _tray;
    QElapsedTimer _clock;
    qint64 _lastShown = -5000;
    bool _enabled = false, _session = false;
    QString _path, _message;
};
