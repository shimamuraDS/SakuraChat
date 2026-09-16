#include "configmanager.h"
#include <QCoreApplication>
#include <QSettings>
#include <QFile>
#include <QDebug>
#include <QUrl>
#include <QSslCertificate>
#include <QSslSocket>
#include "releaseconfig.h"

void ConfigManager::loadConfig()
{
    QString config_path = QCoreApplication::applicationDirPath() + "/config.ini";
    QSettings settings(config_path, QSettings::IniFormat);
#if SAKURA_DISTRIBUTION
    m_development = false;
    m_gateUrlPrefix = QStringLiteral(SAKURA_GATEWAY);
    m_tls = QSslConfiguration::defaultConfiguration();
    m_tls.setProtocol(QSsl::TlsV1_2OrLater);
    m_tls.setPeerVerifyMode(QSslSocket::VerifyPeer);
    if (QFile::exists(":/trust/ca.crt")) {
        const auto certs = QSslCertificate::fromPath(":/trust/ca.crt");
        if (certs.isEmpty()) qFatal("Cannot load bundled TLS CA");
        m_tls.addCaCertificates(certs);
    }
    QSslConfiguration::setDefaultConfiguration(m_tls);
    return;
#endif
    const auto mode = settings.value("Security/Mode", "development").toString();
    m_development = mode == "development";
    if (mode != "development" && mode != "production") qFatal("Invalid Security/Mode");
    m_tls = QSslConfiguration::defaultConfiguration();
    m_tls.setProtocol(QSsl::TlsV1_2OrLater);
    m_tls.setPeerVerifyMode(QSslSocket::VerifyPeer);
    const auto caPath = settings.value("Security/CaFile").toString();
    if (!caPath.isEmpty()) {
        auto certs = QSslCertificate::fromPath(caPath);
        if (certs.isEmpty()) qFatal("Cannot load configured TLS CA");
        m_tls.addCaCertificates(certs);
    }
    QSslConfiguration::setDefaultConfiguration(m_tls);

    QString gate_host = settings.value("GateServer/host").toString();
    QString gate_port = settings.value("GateServer/port").toString();

    m_gateUrlPrefix = settings.value("GateServer/url").toString();
    if (m_gateUrlPrefix.isEmpty() && (gate_host.isEmpty() || gate_port.isEmpty())) {
        qWarning() << "GateServer host/port not found in config.ini!";
        m_gateUrlPrefix = "";
    } else {
        if (m_gateUrlPrefix.isEmpty())
            m_gateUrlPrefix = QString("%1://%2:%3").arg(m_development ? "http" : "https", gate_host, gate_port);
        const QUrl url(m_gateUrlPrefix);
        const bool local = url.host() == "127.0.0.1" || url.host() == "localhost" || url.host() == "::1";
        if (!url.isValid() || url.host().isEmpty() || !url.userInfo().isEmpty() || url.hasQuery() || url.hasFragment() ||
            (m_development ? (!local || url.scheme() != "http") : url.scheme() != "https"))
            qFatal("Unsafe gateway URL for selected security mode");
        qDebug() << "Gate URL Loaded:" << m_gateUrlPrefix;
    }
}
