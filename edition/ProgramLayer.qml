/*
 * One video track's contribution to the composited program.
 *
 * Decodes the clip under the playhead on this track and applies the
 * transform and opacity the effect stack asks for. Tracks with no clip at
 * the playhead render nothing, so lower layers show through.
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtMultimedia

Item {
    id: layer

    // Track record from the session, and where the playhead is.
    required property var track
    required property real playhead
    required property bool playing
    // Session, for source resolution and the effect stack.
    required property var session

    readonly property var clip: {
        const clips = track.clips
        for (var i = 0; i < clips.length; i++) {
            const c = clips[i]
            if (playhead >= c.start && playhead < c.start + c.width)
                return c
        }
        return null
    }

    readonly property url source: clip ? session.sourceFor(clip.media) : ""
    readonly property bool decoding: source != "" && player.hasVideo

    // Where the playhead sits inside the clip, 0..1.
    // Effect values resolved at this playhead position.
    readonly property var effects: clip
        ? session.effectsFor(clip)
        : ({ opacity: 1, scale: 1, positionX: 0.5, positionY: 0.5, rotation: 0 })

    readonly property real clipPosition: clip
        ? Math.max(0, Math.min(1, (playhead - clip.start) / Math.max(0.0001, clip.width)))
        : 0

    visible: decoding

    MediaPlayer {
        id: player
        source: layer.source
        videoOutput: videoOut
        // The mixer owns monitoring; layers are silent.
        audioOutput: AudioOutput { volume: 0.0 }
        loops: MediaPlayer.Infinite
    }

    // Seeking is deferred rather than done inside the change handler. An
    // edit that moves both edges of a clip — a trim — writes start and then
    // width, so a handler running on the first write seeks against a clip
    // that briefly describes a different span, and each seek re-enters the
    // handler. Collapsing the seeks onto a timer means the model has
    // settled before any of them runs.
    Timer {
        id: seekSettle
        interval: 30
        onTriggered: {
            if (layer.playing || !player.seekable || player.duration <= 0)
                return
            const target = layer.clipPosition * player.duration
            if (!isFinite(target) || Math.abs(player.position - target) <= 40)
                return
            player.position = target
        }
    }

    onClipPositionChanged: {
        if (!layer.playing)
            seekSettle.restart()
    }

    onPlayingChanged: {
        if (layer.playing)
            player.play()
        else
            player.pause()
    }

    // A paused player shows nothing until it has decoded a frame, so start
    // it briefly and park it at the playhead once media is loaded.
    //
    // Priming happens once per source. play() and pause() both change the
    // media status, which re-enters this handler, which primes again — the
    // recursion that exhausted the stack on every layer at startup.
    property url primedSource: ""

    Connections {
        target: player
        function onMediaStatusChanged() {
            const ready = player.mediaStatus === MediaPlayer.LoadedMedia
                       || player.mediaStatus === MediaPlayer.BufferedMedia
            if (!ready || layer.primedSource == layer.source)
                return
            layer.primedSource = layer.source

            if (layer.playing) {
                player.play()
                return
            }
            player.play()
            player.pause()
            if (player.seekable && player.duration > 0)
                player.position = layer.clipPosition * player.duration
        }
    }

    // A new clip on this track needs priming again.
    onSourceChanged: layer.primedSource = ""

    VideoOutput {
        id: videoOut
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit

        // The effect stack drives real geometry, not a label.
        opacity: Math.max(0, Math.min(1, layer.effects.opacity))
        scale: Math.max(0.01, layer.effects.scale)
        rotation: layer.effects.rotation
        transformOrigin: Item.Center
        x: 0  // PROBE
        y: 0  // PROBE
    }
}
