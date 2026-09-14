#pragma once
#include <QObject>
#include <QTcpServer>
#include <QTcpSocket>
#include <QVariantList>
#include <QHash>
#include <QTimer>
#include <QSslSocket>
#include <QSslCertificate>
#include <QSslKey>
#include <functional>

class LanTlsServer : public QTcpServer {
public:
    std::function<void(qintptr)> accept;
protected:
    void incomingConnection(qintptr descriptor) override { accept(descriptor); }
};

class LanChat : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)
    Q_PROPERTY(QVariantList messages READ messages NOTIFY messagesChanged)
    Q_PROPERTY(QString fingerprint READ fingerprint NOTIFY changed)
    Q_PROPERTY(QString invitation READ invitation NOTIFY changed)
public:
    explicit LanChat(QObject *parent = nullptr);
    ~LanChat() override;
    QString state() const { return m_state; }
    QString notice() const { return m_notice; }
    QVariantList messages() const { return m_messages; }
    QString fingerprint() const { return m_fingerprint; }
    QString invitation() const { return m_invitation; }
    Q_INVOKABLE void host(const QString &name, int port);
    Q_INVOKABLE void join(const QString &name, const QString &address, int port,
                         const QString &fingerprint, const QString &invitation);
    Q_INVOKABLE void leave();
    Q_INVOKABLE bool send(const QString &text);
signals:
    void changed();
    void messagesChanged();
private:
    void watch(QTcpSocket *socket);
    void receive(QTcpSocket *socket);
    void publish(const QString &name, const QString &text);
    bool write(QTcpSocket *socket, const QByteArray &frame);
    void status(const QString &state, const QString &notice);
    LanTlsServer m_server;
    QSslCertificate m_certificate;
    QSslKey m_key;
    QString m_fingerprint, m_invitation;
    QHash<QString, int> m_attempts;
    QHash<QTcpSocket *, QPair<qint64, int>> m_rates;
    QTcpSocket *m_client = nullptr;
    QHash<QTcpSocket *, QByteArray> m_buffers;
    QHash<QTcpSocket *, QString> m_names;
    QTimer m_timeout;
    QVariantList m_messages;
    QString m_state = "idle", m_notice, m_name;
};
