/*
 * Unified top toolbar: identity, transport, session presence.
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import EdiTogether.Theme
import EdiTogether.Controls

Rectangle {
    id: toolbar

    required property var session

    implicitHeight: 52
    color: Theme.panel

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.separator
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.l
        anchors.rightMargin: Theme.l
        spacing: Theme.m

        // identity
        Text {
            text: "EdiTogether"
            font: Theme.titleFont
            color: Theme.textSecondary
        }

        Rectangle { implicitWidth: 1; Layout.fillHeight: true; Layout.topMargin: Theme.m; Layout.bottomMargin: Theme.m; color: Theme.separator }

        Text {
            text: toolbar.session.projectTitle
            font: Theme.calloutFont
            color: Theme.text
        }
        Text {
            text: "Autosaved"
            font: Theme.captionFont
            color: Theme.textTertiary
        }

        Item { Layout.fillWidth: true }

        // transport
        RowLayout {
            spacing: Theme.xxs

            ToolButton {
                text: "Previous"
                tip: "Previous edit point  (Shift+Tab)"
                contentItem: Text { text: "⏮"; font: Theme.calloutFont; color: Theme.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: toolbar.session.playhead = Math.max(0, toolbar.session.playhead - 0.05)
            }

            Button {
                kind: "primary"
                implicitWidth: 40
                text: toolbar.session.playing ? "❚❚" : "▶"
                tip: toolbar.session.playing ? "Pause  (Space)" : "Play  (Space)"
                onClicked: toolbar.session.playing = !toolbar.session.playing
            }

            ToolButton {
                text: "Next"
                tip: "Next edit point  (Tab)"
                contentItem: Text { text: "⏭"; font: Theme.calloutFont; color: Theme.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: toolbar.session.playhead = Math.min(1, toolbar.session.playhead + 0.05)
            }
        }

        ScrubBar {
            Layout.preferredWidth: 320
            value: toolbar.session.playhead
            onSeek: (pos) => toolbar.session.playhead = pos
        }

        Text {
            text: toolbar.session.timecode(toolbar.session.playhead * toolbar.session.duration)
                  + "  /  " + toolbar.session.timecode(toolbar.session.duration)
            font: Theme.timecodeFont
            color: Theme.textSecondary
        }

        Item { Layout.fillWidth: true }

        // session presence
        Row {
            spacing: -Theme.xs
            Layout.alignment: Qt.AlignVCenter

            Repeater {
                model: toolbar.session.collaborators

                Rectangle {
                    id: avatar
                    required property var modelData
                    width: 26; height: 26; radius: 13
                    color: modelData.hue
                    border.width: 2
                    border.color: Theme.panel

                    Text {
                        anchors.centerIn: parent
                        text: avatar.modelData.initials
                        font: Theme.captionFont
                        color: Theme.textOnAccent
                    }
                }
            }
        }

        Button {
            kind: "primary"
            text: "Share"
            tip: "Copy invite code for this session"
        }

        Segmented {
            items: ["Edit", "Color", "Audio", "Deliver"]
            currentIndex: 0
            Layout.preferredWidth: 260
        }
    }
}
