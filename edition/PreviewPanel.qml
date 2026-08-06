/*
 * Program monitor + safe chrome.
 */
import QtQuick
import QtQuick.Layouts
import EdiTogether.Theme
import EdiTogether.Controls

Rectangle {
    id: preview

    required property var session
    property bool safeMargins: false

    color: Theme.window

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.l
        spacing: Theme.s

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#000000"
            radius: Theme.radiusCard

            // 16:9 letterbox
            Rectangle {
                id: frame
                anchors.centerIn: parent
                width: {
                    const w = parent.width - Theme.xl * 2
                    const h = parent.height - Theme.xl * 2
                    return w / 16 * 9 <= h ? w : h / 9 * 16
                }
                height: width / 16 * 9
                color: "#0b0b0d"

                Text {
                    anchors.centerIn: parent
                    text: preview.session.playing ? "" : "Program"
                    font: Theme.headlineFont
                    color: Theme.textTertiary
                }

                // playhead flash while playing
                Rectangle {
                    anchors.fill: parent
                    color: Theme.accent
                    opacity: preview.session.playing ? 0.02 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                }

                // Action-safe 90% and title-safe 80%, the broadcast defaults.
                Item {
                    anchors.fill: parent
                    visible: preview.safeMargins

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.9
                        height: parent.height * 0.9
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.35)
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.8
                        height: parent.height * 0.8
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.22)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.m

            Text {
                text: "1920 × 1080 · 29.97 fps"
                font: Theme.captionFont
                color: Theme.textTertiary
            }

            // Master levels. Silent when paused rather than showing motion
            // there is no audio for.
            RowLayout {
                spacing: Theme.xxs
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: qsTr("L R")
                    font: Theme.captionFont
                    color: Theme.textTertiary
                }

                ColumnLayout {
                    spacing: 2

                    LevelMeter {
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: 4
                        level: preview.session.masterLeft
                        peak: preview.session.masterPeakLeft
                    }

                    LevelMeter {
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: 4
                        level: preview.session.masterRight
                        peak: preview.session.masterPeakRight
                    }
                }
            }

            Item { Layout.fillWidth: true }

            ToolButton {
                text: qsTr("Safe margins")
                tip: qsTr("Action and title safe margins")
                onClicked: preview.safeMargins = !preview.safeMargins

                contentItem: Rectangle {
                    implicitWidth: Theme.iconSize
                    implicitHeight: Theme.iconSize
                    color: "transparent"
                    border.width: 1
                    border.color: preview.safeMargins ? Theme.accent : Theme.textTertiary

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.6
                        height: parent.height * 0.6
                        color: "transparent"
                        border.width: 1
                        border.color: parent.border.color
                    }
                }
            }

            Segmented {
                items: ["Fit", "50%", "100%", "200%"]
                currentIndex: preview.session.zoomIndex
                onActivated: (index) => preview.session.zoomIndex = index
                Layout.preferredWidth: 210
            }

            ToolButton {
                text: "Scopes"
                tip: "Toggle scopes"
                iconSource: Qt.resolvedUrl("icons/scopes.svg")
            }
        }
    }
}
