/*
 * Deliver workspace: pick a preset, review what it will write, queue it.
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EdiTogether.Theme
import EdiTogether.Controls

Rectangle {
    id: deliver

    required property var session

    property int presetIndex: 0

    readonly property var presets: [
        { name: "H.264 · 1080p",  container: "MP4",  vcodec: "H.264 High",  acodec: "AAC 320 kb/s",
          rate: "29.97", size: "1920 × 1080", bitrate: "24 Mb/s" },
        { name: "H.264 · 2160p",  container: "MP4",  vcodec: "H.264 High",  acodec: "AAC 320 kb/s",
          rate: "29.97", size: "3840 × 2160", bitrate: "60 Mb/s" },
        { name: "ProRes 422 HQ",  container: "MOV",  vcodec: "ProRes 422 HQ", acodec: "PCM 24-bit",
          rate: "29.97", size: "1920 × 1080", bitrate: "220 Mb/s" },
        { name: "Vertical · 1080×1920", container: "MP4", vcodec: "H.264 High", acodec: "AAC 256 kb/s",
          rate: "30", size: "1080 × 1920", bitrate: "18 Mb/s" },
    ]

    readonly property var preset: presets[presetIndex]

    color: Theme.window

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.m
        spacing: Theme.m

        Text {
            text: qsTr("Deliver")
            font: Theme.titleFont
            color: Theme.text
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.l

            // presets
            ColumnLayout {
                Layout.preferredWidth: 240
                Layout.fillHeight: true
                spacing: Theme.xs

                Text {
                    text: qsTr("Preset")
                    font: Theme.captionFont
                    color: Theme.textSecondary
                }

                ListView {
                    id: presetList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 1
                    model: deliver.presets
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: presetRow
                        required property var modelData
                        required property int index
                        width: presetList.width
                        height: 34
                        radius: Theme.radiusControl
                        color: deliver.presetIndex === index ? Theme.selected
                             : rowArea.containsMouse ? Theme.hover
                             : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.s
                            anchors.rightMargin: Theme.s

                            Text {
                                text: presetRow.modelData.name
                                font: Theme.bodyFont
                                color: deliver.presetIndex === presetRow.index
                                    ? Theme.text : Theme.textSecondary
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: presetRow.modelData.container
                                font: Theme.captionFont
                                color: Theme.textTertiary
                            }
                        }

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: deliver.presetIndex = presetRow.index
                        }
                    }
                }
            }

            // summary
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.s

                Text {
                    text: qsTr("Output")
                    font: Theme.captionFont
                    color: Theme.textSecondary
                }

                GridLayout {
                    columns: 2
                    columnSpacing: Theme.l
                    rowSpacing: Theme.xs
                    Layout.fillWidth: true

                    Repeater {
                        model: [
                            { k: qsTr("Container"), v: deliver.preset.container },
                            { k: qsTr("Video"),     v: deliver.preset.vcodec },
                            { k: qsTr("Audio"),     v: deliver.preset.acodec },
                            { k: qsTr("Frame size"), v: deliver.preset.size },
                            { k: qsTr("Frame rate"), v: deliver.preset.rate + " fps" },
                            { k: qsTr("Target rate"), v: deliver.preset.bitrate },
                            { k: qsTr("Range"), v: qsTr("Whole sequence") },
                            { k: qsTr("Duration"), v: deliver.session.timecode(
                                deliver.session.duration) },
                        ]

                        RowLayout {
                            id: summaryRow
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: Theme.s

                            Text {
                                text: summaryRow.modelData.k
                                font: Theme.bodyFont
                                color: Theme.textTertiary
                                Layout.preferredWidth: 96
                            }

                            Text {
                                text: summaryRow.modelData.v
                                font: Theme.bodyFont
                                color: Theme.text
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.m
                    spacing: Theme.s

                    Button {
                        text: qsTr("Add to queue")
                        onClicked: deliver.session.queueExport(deliver.preset.name)
                    }

                    Button {
                        kind: "primary"
                        text: qsTr("Export")
                        onClicked: deliver.session.queueExport(deliver.preset.name)
                    }

                    Item { Layout.fillWidth: true }
                }

                Item { Layout.fillHeight: true }
            }

            // queue
            ColumnLayout {
                Layout.preferredWidth: 260
                Layout.fillHeight: true
                spacing: Theme.xs

                Text {
                    text: qsTr("Queue")
                    font: Theme.captionFont
                    color: Theme.textSecondary
                }

                ListView {
                    id: queueList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: Theme.xxs
                    model: deliver.session.exportQueue
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: job
                        required property var modelData
                        width: queueList.width
                        height: 42
                        radius: Theme.radiusControl
                        color: Theme.panel
                        border.width: 1
                        border.color: Theme.separator

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.xs
                            spacing: 2

                            Text {
                                text: job.modelData.name
                                font: Theme.captionFont
                                color: Theme.text
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 3
                                radius: 1.5
                                color: Theme.sunken

                                Rectangle {
                                    width: parent.width * job.modelData.progress
                                    height: parent.height
                                    radius: parent.radius
                                    color: job.modelData.progress >= 1
                                        ? Theme.success : Theme.accent
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: deliver.session.exportQueue.length === 0
                    text: qsTr("Nothing queued")
                    font: Theme.captionFont
                    color: Theme.textTertiary
                }
            }
        }
    }
}
