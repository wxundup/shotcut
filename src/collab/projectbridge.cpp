#include "projectbridge.h"

#include <QFileInfo>

#include "mainwindow.h"
#include "mltcontroller.h"
#include "models/multitrackmodel.h"

#include <MltPlaylist.h>
#include <MltProducer.h>
#include <MltTractor.h>

ProjectBridge::ProjectBridge(QObject *parent)
    : QObject(parent)
{
    refresh();
}

QVariantList ProjectBridge::tracks() const
{
    return m_tracks;
}

double ProjectBridge::duration() const
{
    return m_duration;
}

QString ProjectBridge::projectTitle() const
{
    return m_title;
}

bool ProjectBridge::hasProject() const
{
    return !m_tracks.isEmpty();
}

void ProjectBridge::refresh()
{
    m_tracks.clear();
    m_duration = 0.0;
    m_title.clear();

    auto &window = MainWindow::singleton();
    const QString file = window.fileName();
    m_title = file.isEmpty() ? tr("Untitled Project") : QFileInfo(file).completeBaseName();

    Mlt::Producer *multitrack = window.multitrack();
    if (!multitrack || !multitrack->is_valid()) {
        emit projectChanged();
        return;
    }

    const double fps = MLT.profile().fps();
    if (fps <= 0) {
        emit projectChanged();
        return;
    }

    // Sequence length in seconds: clip positions are reported as a fraction
    // of it, which is the shape the interface already draws.
    const int totalFrames = multitrack->get_length();
    m_duration = totalFrames / fps;
    if (m_duration <= 0) {
        emit projectChanged();
        return;
    }

    Mlt::Tractor tractor(*multitrack);
    const int trackCount = tractor.count();

    for (int i = 0; i < trackCount; ++i) {
        QScopedPointer<Mlt::Producer> track(tractor.track(i));
        if (!track || !track->is_valid())
            continue;

        // Shotcut marks the tracks it shows; the hidden black and silent
        // ones are machinery, not part of the edit.
        const QString name = QString::fromLatin1(track->get("shotcut:name"));
        if (name.isEmpty())
            continue;

        const bool isAudio = track->get_int("shotcut:audio") != 0;

        QVariantList clips;
        Mlt::Playlist playlist(*track);
        for (int j = 0; j < playlist.count(); ++j) {
            QScopedPointer<Mlt::ClipInfo> info(playlist.clip_info(j));
            if (!info || !info->producer || !info->producer->is_valid())
                continue;
            if (info->producer->is_blank())
                continue;

            QVariantMap clip;
            const QString resource = QString::fromUtf8(info->resource);
            clip["label"] = QFileInfo(resource).completeBaseName();
            clip["media"] = clip["label"];
            clip["start"] = info->start / fps / m_duration;
            clip["width"] = info->frame_count / fps / m_duration;
            clip["kind"] = isAudio ? QStringLiteral("audio") : QStringLiteral("video");
            clips.append(clip);
        }

        QVariantMap entry;
        entry["name"] = name;
        entry["audio"] = isAudio;
        entry["muted"] = track->get_int("hide") & 2;
        entry["locked"] = track->get_int("shotcut:lock") != 0;
        entry["soloed"] = false;
        entry["volume"] = 1.0;
        entry["level"] = 0.0;
        entry["clips"] = clips;
        m_tracks.append(entry);
    }

    emit projectChanged();
}
