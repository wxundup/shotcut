/*
 * Audio workspace: a mixer channel per track plus the master bus.
 */
pragma ComponentBehavior: Bound
import QtQuick

import QtQuick.Layouts
import EdiTogether.Theme
import EdiTogether.Controls

Rectangle {
    id: audioPanel

    required property var session

    // Indices of the audio tracks, so a strip can address its own track
    // without the mixer having to hold a parallel copy of the model.
    readonly property var audioIndices: {
        const out = []
        for (var i = 0; i < session.tracks.length; i++) {
            if (session.tracks[i].audio)
                out.push(i)
        }
        return out
    }

    // The channel whose processing is on show; the first audio track by
    // default, or whichever strip was clicked.
    property int focusedTrack: {
        for (var i = 0; i < session.tracks.length; i++) {
            if (session.tracks[i].audio)
                return i
        }
        return -1
    }

    color: Theme.window

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.m
        spacing: Theme.m

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.m

            Text {
                text: qsTr("Mixer")
                font: Theme.titleFont
                color: Theme.text
                Layout.fillWidth: true
            }

            Text {
                text: audioPanel.session.playing
                    ? qsTr("metering")
                    : qsTr("stopped — meters read zero")
                font: Theme.captionFont
                color: Theme.textTertiary
            }
        }

        RowLayout {
            Layout.fillHeight: true
            Layout.maximumHeight: 320
            Layout.alignment: Qt.AlignTop
            spacing: Theme.s

            Repeater {
                model: audioPanel.audioIndices

                ChannelFader {
                    id: channel
                    required property var modelData
                    readonly property int index: modelData
                    readonly property var track: audioPanel.session.tracks[modelData]
                    Layout.fillHeight: true

                    name: track.name
                    gain: channel.track.volume
                    pan: channel.track.pan === undefined ? 0 : channel.track.pan
                    level: audioPanel.session.levelFor(channel.index)
                    peak: channel.track.peak === undefined ? 0 : channel.track.peak
                    muted: channel.track.muted
                    soloed: channel.track.soloed

                    onGainRequested: (value) =>
                        audioPanel.session.setTrackProperty(channel.index, "volume", value)
                    onPanRequested: (value) =>
                        audioPanel.session.setTrackProperty(channel.index, "pan", value)
                    onMuteToggled:
                        audioPanel.session.setTrackProperty(
                            channel.index, "muted", !channel.track.muted)
                    onSoloToggled:
                        audioPanel.session.setTrackProperty(
                            channel.index, "soloed", !channel.track.soloed)

                    // Focus follows the strip's own buttons rather than
                    // covering them: an overlay declared here sits above the
                    // fader, mute and solo whatever its z, and swallowed
                    // every click meant for them.
                    onFocusRequested: audioPanel.focusedTrack = channel.index
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.leftMargin: Theme.s
                Layout.rightMargin: Theme.s
                color: Theme.separator
            }

            ChannelFader {
                Layout.fillHeight: true
                name: qsTr("Master")
                gain: audioPanel.session.masterGain
                pan: 0
                level: (audioPanel.session.masterLeft + audioPanel.session.masterRight) / 2
                peak: Math.max(audioPanel.session.masterPeakLeft,
                               audioPanel.session.masterPeakRight)
                onGainRequested: (value) => audioPanel.session.masterGain = value
            }

            // Processing for the channel being worked on.
            DspRack {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 380
                visible: audioPanel.focusedTrack >= 0
                session: audioPanel.session
                trackIndex: audioPanel.focusedTrack
            }
        }

        Item { Layout.fillHeight: true }
    }
}
