/*
 * Timeline: tools bar, ruler, tracks, playhead.
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import EdiTogether.Theme
import EdiTogether.Controls

Rectangle {
    id: timeline

    required property var session

    color: Theme.panel

    readonly property int headerWidth: 116
    readonly property int trackHeight: Theme.trackHeight
    readonly property int rulerHeight: 24

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: Theme.separator
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- tools bar ----
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.s
            spacing: Theme.s

            Row {
                spacing: Theme.xxs

                Repeater {
                    model: [
                        { icon: Qt.resolvedUrl("icons/select.svg"), tip: "Select  (V)" },
                        { icon: Qt.resolvedUrl("icons/razor.svg"), tip: "Razor  (C)" },
                        { icon: Qt.resolvedUrl("icons/slip.svg"), tip: "Slip  (T)" },
                    ]

                    ToolButton {
                        id: toolBtn
                        required property var modelData
                        text: modelData.tip
                        tip: modelData.tip
                        iconSource: modelData.icon
                    }
                }
            }

            Switch {
                id: snapSwitch
                text: "Snap"
                checked: timeline.session.snap
                onToggled: timeline.session.snap = snapSwitch.checked
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Zoom"
                font: Theme.captionFont
                color: Theme.textTertiary
            }

            Slider {
                Layout.preferredWidth: 140
                from: 0; to: 1
                value: 0.35
            }
        }

        // ---- ruler + tracks ----
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // ruler
            Row {
                x: timeline.headerWidth
                y: 0
                spacing: 0

                Repeater {
                    model: 12

                    Item {
                        id: rulerItem
                        required property int index
                        width: (timeline.width - timeline.headerWidth) / 12
                        height: timeline.rulerHeight

                        Rectangle { width: 1; height: 6; color: Theme.textTertiary; anchors.bottom: parent.bottom }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.xs
                            anchors.verticalCenter: parent.verticalCenter
                            text: timeline.session.timecode(rulerItem.index * timeline.session.duration / 12)
                            font: Theme.captionFont
                            color: Theme.textTertiary
                        }
                    }
                }
            }

            // track stack
            Column {
                x: 0
                y: timeline.rulerHeight
                width: parent.width
                spacing: Theme.xxs

                Repeater {
                    model: timeline.session.tracks

                    Rectangle {
                        id: track
                        required property var modelData
                        required property int index
                        width: timeline.width
                        height: timeline.trackHeight
                        radius: Theme.premiere ? 0 : Theme.xs
                        color: index % 2 === 0 ? Theme.trackEven : Theme.trackOdd

                        TrackHead {
                            width: timeline.headerWidth - Theme.xs
                            height: parent.height
                            name: track.modelData.name
                            audio: track.modelData.audio
                            muted: track.modelData.muted
                            soloed: track.modelData.soloed
                            locked: track.modelData.locked
                            volume: track.modelData.volume
                            level: track.modelData.level
                            onMuteToggled: timeline.session.setTrackProperty(
                                track.index, "muted", !track.modelData.muted)
                            onSoloToggled: timeline.session.setTrackProperty(
                                track.index, "soloed", !track.modelData.soloed)
                            onLockToggled: timeline.session.setTrackProperty(
                                track.index, "locked", !track.modelData.locked)
                            onVolumeRequested: (value) => timeline.session.setTrackProperty(
                                track.index, "volume", value)
                        }

                        // clips
                        Repeater {
                            model: track.modelData.clips

                            Rectangle {
                                id: clip
                                required property var modelData
                                readonly property bool selected:
                                    timeline.session.selectedClip === modelData.label
                                readonly property color base:
                                    modelData.kind === "audio" ? Theme.clipAudio
                                    : modelData.kind === "title" ? Theme.clipTitle
                                    : Theme.clipVideo

                                x: timeline.headerWidth
                                   + modelData.start * (timeline.width - timeline.headerWidth)
                                y: Theme.xxs
                                width: Math.max(24, modelData.width
                                       * (timeline.width - timeline.headerWidth) - Theme.xxs)
                                height: parent.height - Theme.xs
                                radius: Theme.radiusControl
                                clip: true
                                color: clipMouse.containsMouse ? Qt.lighter(base, 1.12) : base
                                opacity: track.modelData.locked ? 0.55
                                    : clip.selected ? 1.0 : 0.92
                                border.width: clip.selected ? 2 : 1
                                border.color: clip.selected ? Theme.text : Qt.lighter(base, 1.25)

                                Behavior on color { ColorAnimation { duration: Theme.fast } }

                                // Video clips show sampled frames; audio clips
                                // show their peaks. Neither invents content.
                                Filmstrip {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.topMargin: 14
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 1
                                    visible: clip.modelData.kind === "video"
                                    frames: timeline.session.thumbnailsFor(clip.modelData.label)
                                }

                                Waveform {
                                    anchors.fill: parent
                                    anchors.topMargin: 12
                                    anchors.margins: 2
                                    visible: clip.modelData.kind === "audio"
                                    gain: track.modelData.muted ? 0.25 : track.modelData.volume
                                    peaks: clip.modelData.kind === "audio"
                                        ? timeline.session.peaksFor(
                                            clip.modelData.seed,
                                            Math.max(8, Math.floor(clip.width / 3)))
                                        : []
                                }

                                // label sits above the content with a scrim
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: 14
                                    color: Qt.darker(clip.base, 1.35)
                                    opacity: 0.85
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.leftMargin: Theme.xs
                                    height: 14
                                    verticalAlignment: Text.AlignVCenter
                                    text: clip.modelData.label
                                    font: Theme.captionFont
                                    color: Theme.textOnAccent
                                    elide: Text.ElideRight
                                    width: parent.width - Theme.s
                                }

                                MouseArea {
                                    id: clipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !track.modelData.locked
                                    onClicked: timeline.session.selectedClip = clip.modelData.label
                                }
                            }
                        }
                    }
                }
            }

            // playhead
            Rectangle {
                x: timeline.headerWidth
                   + timeline.session.playhead * (timeline.width - timeline.headerWidth) - 1
                y: 0
                width: 2
                height: parent.height
                color: Theme.playhead

                Rectangle {
                    x: -4
                    y: 0
                    width: 10
                    height: 10
                    radius: 2
                    rotation: 45
                    color: Theme.playhead
                }
            }

            // scrub over tracks
            MouseArea {
                anchors.fill: parent
                onPressed: (mouse) => {
                    const usable = timeline.width - timeline.headerWidth
                    timeline.session.playhead = Math.min(1, Math.max(0,
                        (mouse.x - timeline.headerWidth) / usable))
                }
            }
        }
    }
}
