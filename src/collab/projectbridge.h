/*
 * Exposes the open project to the EdiTogether interface.
 *
 * The QML shell was built against a fixture so it could be developed and
 * screenshotted on its own. This reads the real MLT document instead —
 * tracks, clips, their positions and lengths — in the same shape the
 * fixture used, so the interface shows the project the application
 * actually has open.
 *
 * Read-only for now. Editing still goes through the existing timeline and
 * its undo stack; a second path into the document would be a way to
 * corrupt it.
 */
#ifndef PROJECTBRIDGE_H
#define PROJECTBRIDGE_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class MultitrackModel;

class ProjectBridge : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList tracks READ tracks NOTIFY projectChanged)
    Q_PROPERTY(double duration READ duration NOTIFY projectChanged)
    Q_PROPERTY(QString projectTitle READ projectTitle NOTIFY projectChanged)
    Q_PROPERTY(bool hasProject READ hasProject NOTIFY projectChanged)

public:
    explicit ProjectBridge(QObject *parent = nullptr);

    QVariantList tracks() const;
    double duration() const;
    QString projectTitle() const;
    bool hasProject() const;

public slots:
    void refresh();

signals:
    void projectChanged();

private:
    QVariantList m_tracks;
    double m_duration = 0.0;
    QString m_title;
};

#endif // PROJECTBRIDGE_H
