#include "tcpmgr.h"
#include "usermgr.h"
#include <QJsonDocument>
#include <QJsonObject>

TcpMgr::TcpMgr() : _host(""), _port(0), _b_recv_pending(false), _message_id(0), _message_len(0) {
    QObject::connect(&_socket, &QTcpSocket::connected, [&]() {
        emit sig_con_success(true);
    });

    QObject::connect(&_socket, &QTcpSocket::readyRead, [&]() {
        // 读取数据并追加到缓冲区
        _buffer.append(_socket.readAll());
        QDataStream stream(&_buffer, QIODevice::ReadOnly);
        stream.setVersion(QDataStream::Qt_6_8);

        forever {
            // 先解析头部
            if (!_b_recv_pending) {
                // 检查缓冲区
                if (_buffer.size() < static_cast<int>(sizeof(quint16) * 2)) {
                    return;
                }
                // 预读取
                stream >> _message_id >> _message_len;
                // 移除前四个字节
                _buffer = _buffer.mid(sizeof(quint16) * 2);
                qDebug() << "Message ID: " << _message_id << ", Length: " << _message_len;
            }

            // 检查剩余长度
            if (_buffer.size() < _message_len) {
                _b_recv_pending = true;
                return;
            }

            _b_recv_pending = false;
            QByteArray messageBody = _buffer.mid(0, _message_len);

            _buffer = _buffer.mid(_message_len);
            handleMsg(ReqId(_message_id), _message_len, messageBody);
        }
    });

    QObject::connect(&_socket, QOverload<QAbstractSocket::SocketError>::of(&QTcpSocket::errorOccurred), [&](QAbstractSocket::SocketError socketError) {
        Q_UNUSED(socketError)
        qDebug() << "Error: " << _socket.errorString();
    });

    // 处理连接断开
    QObject::connect(&_socket, &QTcpSocket::disconnected, [&] {
        qDebug() << "Disconnected from server.";
    });

    // 连接发送信号用来发送数据
    QObject::connect(this, &TcpMgr::sig_send_data, this, &TcpMgr::slot_send_data);

    // 注册消息
    initHandlers();
}

TcpMgr::~TcpMgr() {

}

void TcpMgr::initHandlers() {
    _handlers.insert(ID_CHAT_LOGIN_RSP, [this](ReqId id, int len, QByteArray data) {
        Q_UNUSED(len);
        qDebug() << "handle id is " << id << "data is " << data;
        QJsonDocument jsonDoc = QJsonDocument::fromJson(data);
        if (jsonDoc.isNull()) {
            qDebug() << "Failed to create QJsonDocument.";
            return;
        }
        QJsonObject jsonObj = jsonDoc.object();
        if (!jsonObj.contains("error")) {
            int err = ErrorCodes::ERR_JSON;
            qDebug() << "Login Failed, err is Json Parse Err" << err;
            emit sig_login_failed(err);
            return;
        }
        int err = jsonObj["error"].toInt();
        if (err != ErrorCodes::SUCCESS) {
            qDebug() << "Login Failed, err is " << err;
            emit sig_login_failed(err);
            return;
        }

        UserMgr::GetInstance()->SetName(jsonObj["name"].toString());
        UserMgr::GetInstance()->SetUid(jsonObj["uid"].toInt());
        UserMgr::GetInstance()->SetToken(jsonObj["token"].toString());

        emit sig_switch_chatlg();
    });
}

void TcpMgr::handleMsg(ReqId id, int len, QByteArray data) {
    auto find_iter = _handlers.find(id);
    if (find_iter == _handlers.end()) {
        qDebug() << "not found id [" << id << "] to handle";
        return;
    }

    find_iter.value()(id, len, data);
}

void TcpMgr::slot_tcp_connect(ServerInfo si) {
    qDebug() << "receive tcp connect signal";
    qDebug() << "connecting to server...";

    // 如果当前socket已经连接或者正在连接，先关闭并重置
    if (_socket.state() != QAbstractSocket::UnconnectedState) {
        _socket.close();
    }

    _host = si.Host;
    _port = static_cast<uint16_t>(si.Port.toUInt());
    _socket.connectToHost(si.Host, _port);
}

void TcpMgr::slot_send_data(ReqId reqId, QString data) {
    uint16_t id = reqId;
    QByteArray dataBytes = data.toUtf8();
    quint16 len = static_cast<quint16>(dataBytes.size());
    QByteArray block;
    QDataStream out(&block, QIODevice::WriteOnly);

    out.setByteOrder(QDataStream::BigEndian);
    out << id << len;
    block.append(dataBytes);

    _socket.write(block);
}
