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

            Item { Layout.fillWidth: true }

            Segmented {
                items: ["Fit", "100%"]
                currentIndex: 0
                Layout.preferredWidth: 110
            }

            ToolButton {
                text: "Scopes"
                tip: "Toggle scopes"
                iconSource: Qt.resolvedUrl("icons/scopes.svg")
            }
        }
    }
}
