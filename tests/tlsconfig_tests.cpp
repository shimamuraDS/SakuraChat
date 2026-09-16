#include "configmanager.h"
#include "releaseconfig.h"
#include <QCoreApplication>
#include <QFile>
#include <QSslCertificate>
#include <QSslSocket>
#include <QUrl>
#include <QDebug>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QEventLoop>
#include <QTimer>
#include <cstdio>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    auto &config = ConfigManager::instance();
    config.loadConfig();
    const auto tls = config.tlsConfiguration();
    if (tls.peerVerifyMode() != QSslSocket::VerifyPeer ||
        tls.protocol() != QSsl::TlsV1_2OrLater) return 1;
    if (QSslConfiguration::defaultConfiguration().caCertificates() != tls.caCertificates()) return 2;
#if SAKURA_DISTRIBUTION
    if (config.development() || QUrl(config.gateUrlPrefix()).scheme() != "https" ||
        config.gateUrlPrefix() != QStringLiteral(SAKURA_GATEWAY)) return 3;
    if (QFile::exists(":/trust/ca.crt")) {
        const auto bundled = QSslCertificate::fromPath(":/trust/ca.crt");
        if (bundled.isEmpty()) return 4;
        for (const auto &cert : bundled)
            if (!tls.caCertificates().contains(cert)) return 5;
    }
#endif
    std::puts("TLS configuration passed: peer verification, TLS 1.2+, shared CA trust");
    // Opt-in read-only connectivity check against the compiled distribution endpoint.
    if (app.arguments().contains("--probe")) {
        QNetworkAccessManager network;
        QNetworkRequest request(QUrl(config.gateUrlPrefix() + "/healthz"));
        request.setTransferTimeout(10000);
        auto *reply = network.get(request);
        QEventLoop loop;
        QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
        loop.exec();
        if (reply->error() != QNetworkReply::NoError ||
            reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() != 200) {
            std::fprintf(stderr, "HTTPS probe failed: %s\n", qPrintable(reply->errorString()));
            return 6;
        }
        delete reply;
        for (const auto port : {8090, 8091}) {
            QSslSocket socket;
            socket.connectToHostEncrypted(QUrl(config.gateUrlPrefix()).host(), port);
            if (!socket.waitForEncrypted(10000)) {
                std::fprintf(stderr, "Chat TLS probe %d failed: %s\n", port, qPrintable(socket.errorString()));
                return 7;
            }
            socket.abort();
        }
        std::puts("HTTPS and both chat TLS endpoints verified with bundled CA");
    }
}
