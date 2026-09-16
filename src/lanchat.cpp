#include "lanchat.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QDateTime>
#include <QNetworkInterface>
#include <QProcess>
#include <QStandardPaths>
#include <QCoreApplication>
#include <QFileInfo>
#include <QRandomGenerator>
#include <QSslConfiguration>
#include <QSslError>

namespace {
bool localAddress(const QHostAddress &address) {
    bool ok = false;
    const auto ip = address.toIPv4Address(&ok);
    return ok && ((ip >> 24) == 10 || (ip >> 24) == 127
        || (ip >> 16) == 0xc0a8 || (ip >> 20) == 0xac1
        || (ip >> 16) == 0xa9fe);
}
QByteArray frame(const QJsonObject &object) {
    return QJsonDocument(object).toJson(QJsonDocument::Compact) + '\n';
}
}

LanChat::LanChat(QObject *parent) : QObject(parent) {
    m_timeout.setSingleShot(true);
    connect(&m_timeout, &QTimer::timeout, this, [this] {
        leave(); status("idle", tr("连接超时，请检查房主 IP、端口和防火墙。"));
    });
    m_server.accept = [this](qintptr descriptor) {
        auto *socket = new QSslSocket(this);
        if (!socket->setSocketDescriptor(descriptor)) { socket->deleteLater(); return; }
        const auto ip = socket->peerAddress().toString();
        if (m_buffers.size() >= 16 || !localAddress(socket->peerAddress())
            || m_attempts.value(ip) >= 5 || (!m_attempts.contains(ip) && m_attempts.size() >= 256)) {
            socket->abort(); socket->deleteLater(); return;
        }
        ++m_attempts[ip];
        socket->setProtocol(QSsl::TlsV1_2OrLater);
        socket->setLocalCertificate(m_certificate); socket->setPrivateKey(m_key);
        socket->setPeerVerifyMode(QSslSocket::VerifyNone); // Members authenticate with the invitation inside TLS.
        watch(socket);
        QTimer::singleShot(8000, socket, [this, socket] {
            if (!m_names.contains(socket)) socket->abort();
        });
        socket->startServerEncryption();
    };
}

void LanChat::status(const QString &state, const QString &notice) {
    m_state = state; m_notice = notice; emit changed();
}

LanChat::~LanChat() { leave(); }

void LanChat::leave() {
    m_timeout.stop(); m_server.close();
    const auto sockets = m_buffers.keys();
    m_client = nullptr;
    for (auto *socket : sockets) {
        socket->disconnect(this); socket->abort(); socket->deleteLater();
    }
    m_buffers.clear(); m_names.clear(); m_messages.clear(); m_rates.clear(); m_attempts.clear();
    m_key.clear(); m_certificate.clear(); m_fingerprint.clear(); m_invitation.clear();
    emit messagesChanged(); status("idle", tr("已离开房间，内存聊天记录已清除。"));
}

void LanChat::host(const QString &name, int port) {
    leave(); m_name = name.trimmed().left(32);
    if (m_name.isEmpty() || port < 1024 || port > 65535) {
        status("idle", tr("请填写昵称和 1024～65535 的端口。")); return;
    }
    if (!QSslSocket::supportsSsl()) { status("idle", tr("TLS 不可用，请安装 Qt TLS 运行库。")); return; }
    auto openssl = QCoreApplication::applicationDirPath() + "/openssl.exe";
    if (!QFileInfo::exists(openssl)) {
#ifdef SAKURA_PACKAGED
        status("idle", tr("缺少局域网加密组件，请重新安装完整客户端。")); return;
#else
        openssl = QStandardPaths::findExecutable("openssl");
#endif
    }
    QProcess generator;
    generator.start(openssl, {"req", "-config", "-", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:P-256",
                             "-nodes", "-keyout", "-", "-out", "-", "-days", "1", "-subj", "/CN=SakuraChat LAN",
                             "-addext", "basicConstraints=critical,CA:FALSE", "-addext", "keyUsage=critical,digitalSignature",
                             "-addext", "extendedKeyUsage=serverAuth"});
    generator.write("[req]\ndistinguished_name=dn\n[dn]\n");
    generator.closeWriteChannel();
    if (!generator.waitForFinished(10000) || generator.exitCode() != 0) {
        generator.kill(); generator.waitForFinished();
        status("idle", tr("无法生成房间证书，请安装 OpenSSL 3 并加入 PATH。")); return;
    }
    auto pem = generator.readAllStandardOutput();
    m_certificate = QSslCertificate(pem);
    m_key = QSslKey(pem, QSsl::Ec);
    pem.fill('\0');
    if (m_certificate.isNull() || m_key.isNull()) { status("idle", tr("房间证书生成失败。")); return; }
    m_fingerprint = QString::fromLatin1(m_certificate.digest(QCryptographicHash::Sha256).toHex());
    QByteArray token;
    for (int i = 0; i < 4; ++i) token += QByteArray::number(QRandomGenerator::system()->generate(), 16).rightJustified(8, '0');
    m_invitation = QString::fromLatin1(token);
    if (!m_server.listen(QHostAddress::AnyIPv4, quint16(port))) {
        status("idle", tr("无法创建房间，端口可能已被占用。")); return;
    }
    QStringList addresses;
    for (const auto &address : QNetworkInterface::allAddresses())
        if (localAddress(address) && !address.isLoopback()) addresses.append(address.toString());
    status("hosting", tr("房间已创建 · IP：%1 · 端口：%2")
           .arg(addresses.isEmpty() ? tr("无局域网地址") : addresses.join(" / ")).arg(port));
}

void LanChat::join(const QString &name, const QString &address, int port,
                   const QString &fingerprint, const QString &invitation) {
    leave(); m_name = name.trimmed().left(32);
    const QHostAddress hostAddress(address.trimmed());
    if (m_name.isEmpty() || !localAddress(hostAddress) || port < 1024 || port > 65535) {
        status("idle", tr("请填写昵称、局域网 IPv4 地址和有效端口。")); return;
    }
    const auto pin = fingerprint.trimmed().toLower().toLatin1();
    if (pin.size() != 64 || QByteArray::fromHex(pin).toHex() != pin || invitation.trimmed().size() != 32) {
        status("idle", tr("请通过可信渠道获取并填写房主 SHA-256 指纹和邀请口令。")); return;
    }
    auto *tls = new QSslSocket(this); m_client = tls; watch(tls);
    tls->setProtocol(QSsl::TlsV1_2OrLater);
    tls->setPeerVerifyMode(QSslSocket::VerifyPeer);
    connect(tls, &QSslSocket::sslErrors, this, [tls, pin](const QList<QSslError> &errors) {
        if (tls->peerCertificate().digest(QCryptographicHash::Sha256).toHex() != pin) { tls->abort(); return; }
        for (const auto &error : errors)
            if (error.error() != QSslError::SelfSignedCertificate && error.error() != QSslError::HostNameMismatch) {
                tls->abort(); return;
            }
        tls->ignoreSslErrors(errors); // Exact out-of-band certificate pin replaces public CA/hostname trust only.
    });
    connect(tls, &QSslSocket::encrypted, this, [this, tls, pin, invitation] {
        if (tls->peerCertificate().digest(QCryptographicHash::Sha256).toHex() != pin) { tls->abort(); return; }
        write(tls, frame({{"type", "hello"}, {"version", 2}, {"name", m_name}, {"invitation", invitation.trimmed()}}));
    });
    status("connecting", tr("正在连接房间…")); m_timeout.start(5000);
    tls->connectToHostEncrypted(hostAddress.toString(), quint16(port));
}

void LanChat::watch(QTcpSocket *socket) {
    m_buffers.insert(socket, {});
    connect(socket, &QTcpSocket::readyRead, this, [this, socket] { receive(socket); });
    connect(socket, &QTcpSocket::disconnected, this, [this, socket] {
        m_buffers.remove(socket); m_names.remove(socket); m_rates.remove(socket);
        if (socket == m_client) {
            m_client = nullptr; m_timeout.stop();
            status("idle", tr("与房间的连接已断开，聊天记录保留至离开或重新连接。"));
        }
        socket->deleteLater();
    });
    connect(socket, &QTcpSocket::errorOccurred, this, [this, socket](QAbstractSocket::SocketError) {
        if (socket == m_client) {
            m_timeout.stop(); status("idle", tr("连接或安全验证失败，请检查地址、证书指纹、口令及房间状态。"));
        }
    });
    socket->setReadBufferSize(16384);
}

bool LanChat::write(QTcpSocket *socket, const QByteArray &data) {
    auto *tls = qobject_cast<QSslSocket *>(socket);
    if (!tls || !tls->isEncrypted()) return false;
    if (!socket || socket->state() != QAbstractSocket::ConnectedState) return false;
    if (socket->bytesToWrite() + tls->encryptedBytesToWrite() + data.size() > 65536) { socket->abort(); return false; }
    return socket->write(data) == data.size();
}

void LanChat::receive(QTcpSocket *socket) {
    auto buffer = m_buffers.value(socket) + socket->readAll();
    while (buffer.contains('\n')) {
        auto &rate = m_rates[socket];
        const auto now = QDateTime::currentMSecsSinceEpoch() / 1000;
        if (rate.first != now) rate = {now, 0};
        if (++rate.second > 20) { socket->abort(); return; }
        const auto end = buffer.indexOf('\n');
        if (end > 8192) { socket->abort(); return; }
        const auto object = QJsonDocument::fromJson(buffer.left(end)).object();
        buffer.remove(0, end + 1);
        const auto type = object["type"].toString();
        if (m_server.isListening()) {
            if (type == "hello" && !m_names.contains(socket) && object["version"].toInt() == 2) {
                const auto supplied = object["invitation"].toString().toLatin1();
                const auto expected = m_invitation.toLatin1();
                unsigned int difference = supplied.size() ^ expected.size();
                for (int i = 0; i < expected.size(); ++i)
                    difference |= static_cast<unsigned char>(expected[i]) ^ (i < supplied.size() ? static_cast<unsigned char>(supplied[i]) : 0);
                if (difference) { socket->abort(); return; }
                const auto name = object["name"].toString().trimmed();
                if (name.isEmpty() || name.size() > 32) { socket->abort(); return; }
                m_names.insert(socket, name);
                m_attempts[socket->peerAddress().toString()] = 0;
                write(socket, frame({{"type", "welcome"}, {"version", 2}}));
            } else if (type == "send" && m_names.contains(socket)) {
                const auto text = object["text"].toString().trimmed();
                if (text.isEmpty() || text.toUtf8().size() > 2000) { socket->abort(); return; }
                publish(m_names.value(socket), text);
            } else { socket->abort(); return; }
        } else if (socket == m_client) {
            if (type == "welcome" && m_state == "connecting" && object["version"].toInt() == 2) {
                m_timeout.stop(); status("joined", tr("TLS 加密已连接 · 房主身份已核验 · 房主可读取消息"));
            } else if (type == "message" && m_state == "joined") {
                if (object["text"].toString().toUtf8().size() > 2000
                    || object["name"].toString().size() > 32) { socket->abort(); return; }
                m_messages.append(object.toVariantMap());
                if (m_messages.size() > 300) m_messages.removeFirst();
                emit messagesChanged();
            } else { socket->abort(); return; }
        }
        if (!m_buffers.contains(socket)) return;
    }
    if (buffer.size() > 8192) { socket->abort(); return; }
    m_buffers[socket] = buffer;
}

void LanChat::publish(const QString &name, const QString &text) {
    const QJsonObject object{{"type", "message"}, {"name", name}, {"text", text},
                             {"time", QDateTime::currentDateTime().toString("HH:mm:ss")}};
    m_messages.append(object.toVariantMap());
    if (m_messages.size() > 300) m_messages.removeFirst();
    emit messagesChanged();
    const auto sockets = m_names.keys();
    for (auto *socket : sockets) write(socket, frame(object));
}

bool LanChat::send(const QString &text) {
    const auto value = text.trimmed();
    if (value.isEmpty() || value.toUtf8().size() > 2000) {
        status(m_state, tr("消息不能为空，且不能超过 2000 个 UTF-8 字节。")); return false;
    }
    if (m_state == "hosting") { publish(m_name, value); return true; }
    if (m_state == "joined") return write(m_client, frame({{"type", "send"}, {"text", value}}));
    return false;
}
