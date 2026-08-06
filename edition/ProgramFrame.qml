/*
 * The composited program picture.
 *
 * Every video track contributes a layer, stacked bottom-up the way the
 * timeline reads, each decoding its own clip and carrying its effect stack.
 * When no track has a clip under the playhead it falls back to bars and a
 * ramp so the scopes always have a real rendered frame to read.
 */
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: frame

    property real playhead: 0.0
    property var grade: ({ lift: { master: 0 }, gamma: { master: 0 }, gain: { master: 0 } })
    property bool playing: false

    required property var session

    readonly property var tracks: session.tracks

    // Video tracks, bottom of the timeline first so V1 sits under V2.
    readonly property var videoTracks: {
        const out = []
        for (var i = tracks.length - 1; i >= 0; i--) {
            if (!tracks[i].audio)
                out.push(tracks[i])
        }
        return out
    }

    // True while any track has a clip under the playhead. Derived from the
    // session rather than layer callbacks, so it is correct on the first
    // frame instead of waiting for a transition.
    readonly property bool anyClipAtPlayhead: {
        for (var i = 0; i < videoTracks.length; i++) {
            const clips = videoTracks[i].clips
            for (var c = 0; c < clips.length; c++) {
                const clipRecord = clips[c]
                if (playhead >= clipRecord.start
                        && playhead < clipRecord.start + clipRecord.width
                        && session.sourceFor(clipRecord.media) != "")
                    return true
            }
        }
        return false
    }

    readonly property real lift: grade.lift.master
    readonly property real gain: grade.gain.master

    Rectangle {
        anchors.fill: parent
        color: "#0b0b0d"
    }

    // Composited layers.
    Repeater {
        id: layerRepeater
        model: frame.videoTracks

        ProgramLayer {
            id: programLayer
            required property var modelData
            anchors.fill: parent
            track: modelData
            session: frame.session
            playhead: frame.playhead
            playing: frame.playing

        }
    }

    // Grading applied over the composite, so the scopes read graded pixels.
    Rectangle {
        anchors.fill: parent
        visible: frame.lift !== 0
        color: "#ffffff"
        opacity: Math.min(0.5, Math.abs(frame.lift) * 0.25)
    }

    Rectangle {
        anchors.fill: parent
        visible: frame.gain !== 0
        color: frame.gain > 0 ? "#ffffff" : "#000000"
        opacity: Math.min(0.5, Math.abs(frame.gain) * 0.3)
    }

    // Fallback picture when no track has a clip under the playhead.
    Item {
        id: fallback
        anchors.fill: parent
        visible: !frame.anyClipAtPlayhead

        // 75% colour bars
        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.height * 0.68

            Repeater {
                model: [
                    "#bfbfbf", "#bfbf00", "#00bfbf", "#00bf00",
                    "#bf00bf", "#bf0000", "#0000bf",
                ]

                Rectangle {
                    required property var modelData
                    width: frame.width / 7
                    height: parent.height
                    color: modelData
                }
            }
        }

        // luminance ramp
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.68
            height: parent.height * 0.18

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#000000" }
                GradientStop { position: 1.0; color: "#ffffff" }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height * 0.14
            color: "#1a1a1a"
        }

        Rectangle {
            y: parent.height * 0.86
            x: frame.playhead * (parent.width - width)
            width: parent.width * 0.12
            height: parent.height * 0.14
            color: "#f0a030"
            radius: 2
        }
    }
}
