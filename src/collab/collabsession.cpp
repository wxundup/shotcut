#include "collabsession.h"

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
            [this](const QString &code, const QJsonArray &, qint64) { m_roomCode = code; });
    connect(&m_client, &CollabClient::snapshotReceived, this, [this](const QString &xml) {
        if (m_applying)
            return;
        QTemporaryFile tmp(QDir::temp().filePath("editogether-XXXXXX.mlt"));
        tmp.setAutoRemove(false);
        if (!tmp.open())
            return;
        tmp.write(xml.toUtf8());
        tmp.close();
        m_applying = true;
        m_win->open(tmp.fileName());
        m_applying = false;
        QFile::remove(tmp.fileName());
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
    if (!m_applying && m_client.isConnected())
        m_debounce->start();
}

void CollabSession::broadcastSnapshot()
{
    QTemporaryFile tmp(QDir::temp().filePath("editogether-XXXXXX.mlt"));
    if (!tmp.open())
        return;
    tmp.close();
    if (m_win->saveXML(tmp.fileName(), false)) {
        QFile f(tmp.fileName());
        if (f.open(QIODevice::ReadOnly))
            m_client.sendSnapshot(QString::fromUtf8(f.readAll()));
    }
    tmp.remove();
}
