/*
 * EdiTogether collaboration session glue.
 * Snapshot-level sync v1: debounced MLT XML broadcast, remote open on receive.
 */
#ifndef COLLABSESSION_H
#define COLLABSESSION_H

#include <QByteArray>
#include <QObject>
#include <QString>
#include <QUrl>

#include "collabclient.h"

class MainWindow;
class QTimer;

class CollabSession : public QObject
{
    Q_OBJECT
public:
    explicit CollabSession(MainWindow *win);

    void startHost();
    void join(const QString &invite, const QString &displayName);
    void leave();
    QString roomCode() const { return m_roomCode; }

public slots:
    void localChanged();

private:
    void broadcastSnapshot();

    MainWindow *m_win;
    CollabClient m_client;
    QTimer *m_debounce;
    QString m_roomCode;
    QByteArray m_lastAppliedDigest;
};

#endif // COLLABSESSION_H
