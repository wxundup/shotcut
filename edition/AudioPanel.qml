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

    readonly property var audioTracks:
        session.tracks.filter(function (t) { return t.audio })

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
                model: audioPanel.session.tracks

                ChannelFader {
                    id: channel
                    required property var modelData
                    required property int index
                    visible: modelData.audio
                    Layout.preferredWidth: visible ? implicitWidth : 0
                    Layout.fillHeight: true

                    name: modelData.name
                    gain: modelData.volume
                    pan: modelData.pan === undefined ? 0 : modelData.pan
                    level: modelData.level
                    peak: modelData.peak === undefined ? 0 : modelData.peak
                    muted: modelData.muted
                    soloed: modelData.soloed

                    onGainRequested: (value) =>
                        audioPanel.session.setTrackProperty(channel.index, "volume", value)
                    onPanRequested: (value) =>
                        audioPanel.session.setTrackProperty(channel.index, "pan", value)
                    onMuteToggled:
                        audioPanel.session.setTrackProperty(
                            channel.index, "muted", !channel.modelData.muted)
                    onSoloToggled:
                        audioPanel.session.setTrackProperty(
                            channel.index, "soloed", !channel.modelData.soloed)
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

            Item { Layout.fillWidth: true }
        }

        Item { Layout.fillHeight: true }
    }
}
