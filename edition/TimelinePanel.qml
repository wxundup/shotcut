/*
 * Timeline: tools bar, ruler, tracks, playhead.
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
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

    readonly property real zoom: zoomSlider.value
    // Width the whole sequence occupies at the current zoom.
    readonly property real laneWidth:
        Math.max(1, (width - headerWidth) * zoom)

    // Ruler divisions stay readable: more of them as the lane grows.
    readonly property int rulerDivisions:
        Math.max(4, Math.min(48, Math.round(laneWidth / 130)))

    // Snapping is a fixed number of pixels, so it feels the same at any zoom.
    readonly property real snapTolerance: 8 / Math.max(1, laneWidth)

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
                text: qsTr("Zoom")
                font: Theme.captionFont
                color: Theme.textTertiary
            }

            Slider {
                id: zoomSlider
                Layout.preferredWidth: 140
                from: 1.0
                to: 8.0
                value: 1.0
            }

            Text {
                text: Math.round(timeline.zoom * 100) + "%"
                font: Theme.timecodeFont
                color: Theme.textTertiary
            }
        }

        // ---- heads (fixed) + lane (scrolls with zoom) ----
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Track heads stay put while the lane scrolls beneath the ruler.
            Column {
                id: headColumn
                x: 0
                y: timeline.rulerHeight
                width: timeline.headerWidth
                spacing: Theme.xxs

                Repeater {
                    model: timeline.session.tracks

                    Rectangle {
                        id: headRow
                        required property var modelData
                        required property int index
                        width: timeline.headerWidth
                        height: timeline.trackHeight
                        color: index % 2 === 0 ? Theme.trackEven : Theme.trackOdd

                        TrackHead {
                            width: parent.width - Theme.xs
                            height: parent.height
                            name: headRow.modelData.name
                            audio: headRow.modelData.audio
                            muted: headRow.modelData.muted
                            soloed: headRow.modelData.soloed
                            locked: headRow.modelData.locked
                            volume: headRow.modelData.volume
                            level: headRow.modelData.level
                            onMuteToggled: timeline.session.setTrackProperty(
                                headRow.index, "muted", !headRow.modelData.muted)
                            onSoloToggled: timeline.session.setTrackProperty(
                                headRow.index, "soloed", !headRow.modelData.soloed)
                            onLockToggled: timeline.session.setTrackProperty(
                                headRow.index, "locked", !headRow.modelData.locked)
                            onVolumeRequested: (value) => timeline.session.setTrackProperty(
                                headRow.index, "volume", value)
                        }
                    }
                }
            }

            Rectangle {
                x: timeline.headerWidth - 1
                width: 1
                height: parent.height
                color: Theme.separator
            }

            Flickable {
                id: lane
                x: timeline.headerWidth
                width: parent.width - timeline.headerWidth
                height: parent.height
                contentWidth: timeline.laneWidth
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ScrollBar.horizontal: ScrollBar {
                    policy: lane.contentWidth > lane.width
                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    height: Theme.scrollbar
                }

                // ruler
                Row {
                    y: 0
                    spacing: 0

                    Repeater {
                        model: timeline.rulerDivisions

                        Item {
                            id: rulerItem
                            required property int index
                            width: timeline.laneWidth / timeline.rulerDivisions
                            height: timeline.rulerHeight

                            Rectangle {
                                width: 1
                                height: 6
                                color: Theme.textTertiary
                                anchors.bottom: parent.bottom
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.xs
                                anchors.verticalCenter: parent.verticalCenter
                                text: timeline.session.timecode(
                                    rulerItem.index * timeline.session.duration
                                    / timeline.rulerDivisions)
                                font: Theme.captionFont
                                color: Theme.textTertiary
                            }
                        }
                    }
                }

                // track lanes
                Column {
                    y: timeline.rulerHeight
                    width: timeline.laneWidth
                    spacing: Theme.xxs

                    Repeater {
                        model: timeline.session.tracks

                        Rectangle {
                            id: track
                            required property var modelData
                            required property int index
                            width: timeline.laneWidth
                            height: timeline.trackHeight
                            color: index % 2 === 0 ? Theme.trackEven : Theme.trackOdd

                            Repeater {
                                model: track.modelData.clips

                                Rectangle {
                                    id: clip
                                    required property var modelData
                                    required property int index
                                    readonly property bool selected:
                                        timeline.session.selectedClip === modelData.label
                                    readonly property color base:
                                        modelData.kind === "audio" ? Theme.clipAudio
                                        : modelData.kind === "title" ? Theme.clipTitle
                                        : Theme.clipVideo

                                    x: modelData.start * timeline.laneWidth
                                    y: Theme.xxs
                                    width: Math.max(24, modelData.width * timeline.laneWidth
                                                        - Theme.xxs)
                                    height: parent.height - Theme.xs
                                    radius: Theme.radiusControl
                                    clip: true
                                    color: clipMouse.containsMouse ? Qt.lighter(base, 1.12) : base
                                    opacity: track.modelData.locked ? 0.55
                                        : clip.selected ? 1.0 : 0.92
                                    border.width: clip.selected ? 2 : 1
                                    border.color: clip.selected
                                        ? Theme.text : Qt.lighter(base, 1.25)

                                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                                    // Video clips show sampled frames; audio
                                    // clips show their peaks. Neither invents
                                    // content it was not given.
                                    Filmstrip {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.topMargin: 14
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 1
                                        visible: clip.modelData.kind === "video"
                                        frames: timeline.session.thumbnailsFor(
                                            clip.modelData.label)
                                    }

                                    Waveform {
                                        anchors.fill: parent
                                        anchors.topMargin: 12
                                        anchors.margins: 2
                                        visible: clip.modelData.kind === "audio"
                                        gain: track.modelData.muted
                                            ? 0.25 : track.modelData.volume
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

                                    // Trim handles appear on hover at either
                                    // edge; the body drags the whole clip.
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 6
                                        color: Theme.text
                                        opacity: inHandle.containsMouse || inHandle.pressed
                                            ? 0.75 : (clipMouse.containsMouse ? 0.3 : 0)
                                        visible: !track.modelData.locked
                                        Behavior on opacity {
                                            NumberAnimation { duration: Theme.fast }
                                        }
                                    }

                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 6
                                        color: Theme.text
                                        opacity: outHandle.containsMouse || outHandle.pressed
                                            ? 0.75 : (clipMouse.containsMouse ? 0.3 : 0)
                                        visible: !track.modelData.locked
                                        Behavior on opacity {
                                            NumberAnimation { duration: Theme.fast }
                                        }
                                    }

                                    MouseArea {
                                        id: clipMouse
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        hoverEnabled: true
                                        enabled: !track.modelData.locked
                                        cursorShape: pressed
                                            ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                        // where in the clip the grab started
                                        property real grabOffset: 0

                                        onPressed: (mouse) => {
                                            timeline.session.selectedClip = clip.modelData.label
                                            grabOffset = (mouse.x + 6) / timeline.laneWidth
                                        }
                                        onPositionChanged: (mouse) => {
                                            if (!pressed)
                                                return
                                            const pointer = (clip.x + mouse.x + 6)
                                                / timeline.laneWidth
                                            timeline.session.moveClip(
                                                track.index, clip.index,
                                                pointer - grabOffset,
                                                timeline.snapTolerance)
                                        }
                                    }

                                    MouseArea {
                                        id: inHandle
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 6
                                        hoverEnabled: true
                                        enabled: !track.modelData.locked
                                        cursorShape: Qt.SizeHorCursor
                                        onPressed: timeline.session.selectedClip
                                            = clip.modelData.label
                                        onPositionChanged: (mouse) => {
                                            if (!pressed)
                                                return
                                            timeline.session.trimClip(
                                                track.index, clip.index, "in",
                                                (clip.x + mouse.x) / timeline.laneWidth,
                                                timeline.snapTolerance)
                                        }
                                    }

                                    MouseArea {
                                        id: outHandle
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 6
                                        hoverEnabled: true
                                        enabled: !track.modelData.locked
                                        cursorShape: Qt.SizeHorCursor
                                        onPressed: timeline.session.selectedClip
                                            = clip.modelData.label
                                        onPositionChanged: (mouse) => {
                                            if (!pressed)
                                                return
                                            timeline.session.trimClip(
                                                track.index, clip.index, "out",
                                                (clip.x + clip.width + mouse.x)
                                                    / timeline.laneWidth,
                                                timeline.snapTolerance)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // playhead rides the lane so it stays on its frame when zoomed
                Rectangle {
                    x: timeline.session.playhead * timeline.laneWidth - 1
                    y: 0
                    width: 2
                    height: lane.height
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

                // scrub anywhere in the lane; Ctrl+wheel zooms about the pointer
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onPressed: (mouse) => {
                        timeline.session.playhead = Math.min(1, Math.max(0,
                            mouse.x / timeline.laneWidth))
                    }
                    onWheel: (wheel) => {
                        if (!(wheel.modifiers & Qt.ControlModifier)) {
                            wheel.accepted = false
                            return
                        }
                        // Keep the frame under the pointer fixed while scaling.
                        const anchor = (lane.contentX + wheel.x) / timeline.laneWidth
                        const step = wheel.angleDelta.y > 0 ? 1.25 : 1 / 1.25
                        zoomSlider.value = Math.max(zoomSlider.from,
                            Math.min(zoomSlider.to, zoomSlider.value * step))
                        lane.contentX = Math.max(0, Math.min(
                            Math.max(0, timeline.laneWidth - lane.width),
                            anchor * timeline.laneWidth - wheel.x))
                    }
                }
            }
        }
    }
}
