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

    readonly property int headerWidth: 96
    readonly property int trackHeight: 44
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
                    model: timeline.session.videoTracks.concat(timeline.session.audioTracks)

                    Rectangle {
                        id: track
                        required property var modelData
                        required property int index
                        width: timeline.width
                        height: timeline.trackHeight
                        radius: Theme.xs
                        color: index % 2 === 0 ? Theme.trackEven : Theme.trackOdd

                        // track header
                        Text {
                            x: Theme.m
                            anchors.verticalCenter: parent.verticalCenter
                            text: track.modelData.name
                            font: Theme.bodyFont
                            color: Theme.textSecondary
                        }

                        // clips
                        Repeater {
                            model: track.modelData.clips

                            Rectangle {
                                id: clip
                                required property var modelData
                                x: timeline.headerWidth
                                   + modelData.start * (timeline.width - timeline.headerWidth)
                                y: Theme.xxs
                                width: Math.max(24, modelData.width
                                       * (timeline.width - timeline.headerWidth) - Theme.xxs)
                                height: parent.height - Theme.xs
                                radius: Theme.radiusControl
                                color: modelData.hue
                                opacity: 0.9
                                border.width: 1
                                border.color: Qt.lighter(modelData.hue, 1.25)

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Theme.s
                                    text: clip.modelData.label
                                    font: Theme.captionFont
                                    color: Theme.textOnAccent
                                    elide: Text.ElideRight
                                    width: parent.width - Theme.s * 2
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
