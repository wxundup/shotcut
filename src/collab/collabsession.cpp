#include "collabsession.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QTemporaryFile>
#include <QTimer>

#include "mainwindow.h"

static QUrl defaultServer()
{
    return QUrl("ws://127.0.0.1:7788");
}

CollabSession::CollabSession(MainWindow *win)
    : QObject(win)
    , m_win(win)
{
    m_debounce = new QTimer(this);
    m_debounce->setSingleShot(true);
    m_debounce->setInterval(400);
    connect(m_debounce, &QTimer::timeout, this, &CollabSession::broadcastSnapshot);
    connect(&m_client,
            &CollabClient::welcomed,
            this,
            [this](const QString &code, const QJsonArray &, qint64) {
                m_roomCode = code;
                m_win->showStatusMessage(tr("Invite code: %1").arg(code), 30);
            });
    connect(&m_client, &CollabClient::snapshotReceived, this, [this](const QString &xml) {
        const QByteArray utf8 = xml.toUtf8();
        // Remember what we were handed: when opening it churns the undo stack,
        // the resulting broadcast would echo the same document back to the peer
        // that sent it, and ping-pong from there.
        m_lastAppliedDigest = QCryptographicHash::hash(utf8, QCryptographicHash::Sha1);

        QTemporaryFile tmp(QDir::temp().filePath("editogether-XXXXXX.mlt"));
        tmp.setAutoRemove(false);
        if (!tmp.open())
            return;
        const QString path = tmp.fileName();
        const bool written = tmp.write(utf8) == utf8.size();
        tmp.close();
        if (written)
            m_win->open(path);
        QFile::remove(path);
    });
}

void CollabSession::startHost()
{
    m_client.startHost(defaultServer(), "Host");
}

void CollabSession::join(const QString &invite, const QString &displayName)
{
    m_client.join(defaultServer(), invite, displayName);
}

void CollabSession::leave()
{
    m_roomCode.clear();
    m_client.leave();
}

void CollabSession::localChanged()
{
    if (m_client.isConnected())
        m_debounce->start();
}

void CollabSession::broadcastSnapshot()
{
    QTemporaryFile tmp(QDir::temp().filePath("editogether-XXXXXX.mlt"));
    if (!tmp.open())
        return;
    const QString path = tmp.fileName();
    tmp.close(); // saveXML reopens the path itself

    QByteArray xml;
    if (m_win->saveXML(path, false)) {
        QFile f(path);
        if (f.open(QIODevice::ReadOnly))
            xml = f.readAll();
    }
    QFile::remove(path);
    if (xml.isEmpty())
        return;

    // Don't echo a document we just applied from a peer.
    const QByteArray digest = QCryptographicHash::hash(xml, QCryptographicHash::Sha1);
    if (digest == m_lastAppliedDigest)
        return;
    m_lastAppliedDigest = digest;
    m_client.sendSnapshot(QString::fromUtf8(xml));
}
