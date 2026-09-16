#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QDateTime>
#include <QTimer>

class UpdateController : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY changed)
    Q_PROPERTY(bool automaticChecks READ automaticChecks WRITE setAutomaticChecks NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY changed)
    Q_PROPERTY(QString notes READ notes NOTIFY changed)
    Q_PROPERTY(QString version READ version CONSTANT)
public:
    explicit UpdateController(QObject *parent = nullptr);
    void initialize();
    Q_INVOKABLE void check();
    Q_INVOKABLE void openReleasePage();
    bool busy() const { return busy_; }
    bool updateAvailable() const { return updateAvailable_; }
    bool automaticChecks() const { return automatic_; }
    void setAutomaticChecks(bool enabled);
    QString status() const { return status_; }
    QString latestVersion() const { return latest_; }
    QString notes() const { return notes_; }
    QString version() const;
signals:
    void changed();
private:
    friend class UpdateControllerTest;
    void processResponse(int code, bool transportOk, const QByteArray &data);
    void automaticCheck();
    QNetworkAccessManager network_;
    QTimer timer_;
    QDateTime retryAt_;
    bool busy_ = false, updateAvailable_ = false, automatic_ = true;
    QString status_, latest_, notes_;
};
