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

    onClipPositionChanged: {
        if (!layer.playing && player.seekable) {
            const target = layer.clipPosition * player.duration
            if (Math.abs(player.position - target) > 40)
                player.position = target
        }
    }

    onPlayingChanged: {
        if (layer.playing)
            player.play()
        else
            player.pause()
    }

    // A paused player shows nothing until it has decoded a frame, so start
    // it briefly and park it at the playhead once media is loaded.
    Connections {
        target: player
        function onMediaStatusChanged() {
            if (player.mediaStatus === MediaPlayer.LoadedMedia
                    || player.mediaStatus === MediaPlayer.BufferedMedia) {
                if (layer.playing) {
                    player.play()
                } else {
                    player.play()
                    player.pause()
                    if (player.seekable)
                        player.position = layer.clipPosition * player.duration
                }
            }
        }
    }

    VideoOutput {
        id: videoOut
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit

        // The effect stack drives real geometry, not a label.
        opacity: Math.max(0, Math.min(1, layer.effects.opacity))
        scale: Math.max(0.01, layer.effects.scale)
        rotation: layer.effects.rotation
        transformOrigin: Item.Center
        x: (layer.effects.positionX - 0.5) * layer.width
        y: (layer.effects.positionY - 0.5) * layer.height
    }
}
