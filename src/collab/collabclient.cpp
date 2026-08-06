#include "collabclient.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QWebSocket>

CollabClient::CollabClient(QObject *parent)
    : QObject(parent)
{}

QWebSocket *CollabClient::makeSocket(const QUrl &server, const QJsonObject &hello)
{
    auto *socket = new QWebSocket(QString(), QWebSocketProtocol::VersionLatest, this);
    connect(socket, &QWebSocket::connected, this, [socket, hello]() {
        socket->sendTextMessage(
            QString::fromUtf8(QJsonDocument(hello).toJson(QJsonDocument::Compact)));
    });
    connect(socket, &QWebSocket::textMessageReceived, this, &CollabClient::onText);
    connect(socket, &QWebSocket::errorOccurred, this, [this, socket](QAbstractSocket::SocketError) {
        emit connectionError(socket->errorString());
    });
    connect(socket, &QWebSocket::disconnected, this, [this, socket]() {
        if (m_socket == socket) {
            m_socket = nullptr;
            m_peerId = -1;
        }
        socket->deleteLater();
    });
    socket->open(server);
    return socket;
}

void CollabClient::startHost(const QUrl &server, const QString &displayName)
{
    leave(); // one session at a time
    QJsonObject hello{
        {"t", "hello"},
        {"name", displayName},
        {"role", "host"},
    };
    m_socket = makeSocket(server, hello);
}

void CollabClient::join(const QUrl &server, const QString &invite, const QString &displayName)
{
    leave();
    QJsonObject hello{
        {"t", "hello"},
        {"name", displayName},
        {"role", "guest"},
        {"invite", invite},
    };
    m_socket = makeSocket(server, hello);
}

void CollabClient::sendSnapshot(const QString &mltXml)
{
    if (!m_socket || m_peerId < 0)
        return;
    QJsonObject msg{
        {"t", "snapshot"},
        {"from", m_peerId},
        {"mlt_xml", mltXml},
    };
    m_socket->sendTextMessage(QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact)));
}

void CollabClient::sendPresence(double playhead)
{
    if (!m_socket || m_peerId < 0)
        return;
    QJsonObject msg{
        {"t", "presence"},
        {"from", m_peerId},
        {"playhead", playhead},
    };
    m_socket->sendTextMessage(QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact)));
}

void CollabClient::leave()
{
    if (m_socket)
        m_socket->close();
    m_socket = nullptr;
    m_peerId = -1;
}

bool CollabClient::isConnected() const
{
    return m_socket && m_socket->state() == QAbstractSocket::ConnectedState && m_peerId >= 0;
}

void CollabClient::onText(const QString &text)
{
    const QJsonObject msg = QJsonDocument::fromJson(text.toUtf8()).object();
    const QString t = msg.value("t").toString();
    // Nothing but the welcome (or a refusal) is meaningful before we are a peer.
    if (m_peerId < 0 && t != "welcome" && t != "error")
        return;
    if (t == "welcome") {
        m_peerId = qint64(msg.value("peer_id").toDouble());
        emit welcomed(msg.value("room_code").toString(),
                      msg.value("peers").toArray(),
                      qint64(msg.value("host_id").toDouble()));
    } else if (t == "peer-joined") {
        emit peerJoined(msg.value("peer").toObject());
    } else if (t == "peer-left") {
        emit peerLeft(qint64(msg.value("peer_id").toDouble()));
    } else if (t == "snapshot") {
        if (msg.value("from").toDouble() != double(m_peerId))
            emit snapshotReceived(msg.value("mlt_xml").toString());
    } else if (t == "room-closed") {
        emit roomClosed(msg.value("reason").toString());
    } else if (t == "error") {
        emit connectionError(msg.value("reason").toString());
    }
}
