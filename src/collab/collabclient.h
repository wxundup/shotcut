/*
 * EdiTogether collaboration transport.
 * Thin WebSocket client for the local editogether-collab relay.
 */
#ifndef COLLABCLIENT_H
#define COLLABCLIENT_H

#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QUrl>

class QWebSocket;

class CollabClient : public QObject
{
    Q_OBJECT
public:
    explicit CollabClient(QObject *parent = nullptr);

    void startHost(const QUrl &server, const QString &displayName);
    void join(const QUrl &server, const QString &invite, const QString &displayName);
    void sendSnapshot(const QString &mltXml);
    void sendPresence(double playhead);
    void leave();
    bool isConnected() const;

signals:
    void welcomed(const QString &roomCode, const QJsonArray &peers, qint64 hostId);
    void peerJoined(const QJsonObject &peer);
    void peerLeft(qint64 peerId);
    void snapshotReceived(const QString &mltXml);
    void roomClosed(const QString &reason);
    void connectionError(const QString &reason);

private:
    void onText(const QString &text);
    QWebSocket *makeSocket(const QUrl &server, const QJsonObject &hello);

    QWebSocket *m_socket = nullptr;
    qint64 m_peerId = -1;
};

#endif // COLLABCLIENT_H
