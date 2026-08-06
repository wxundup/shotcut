/*
 * EdiTogether shell — target UX reference.
 * Run: qml -I <repo>/src/qml/modules Shell.qml
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EdiTogether.Theme

ApplicationWindow {
    id: root

    width: 1440
    height: 900
    minimumWidth: 1080
    minimumHeight: 700
    visible: true
    title: "Untitled Project — EdiTogether"
    color: Theme.window

    // ---- mock session state -------------------------------------------------
    QtObject {
        id: sessionModel

        property string projectTitle: "Untitled Project"
        property bool playing: false
        property real playhead: 0.23          // 0..1 of timeline
        property real duration: 96.0          // seconds
        property string workspace: "edit"
        property bool snap: true
        property string selectedClip: "A007_Take1"

        property var collaborators: [
            { name: "You",      initials: "YJ", hue: "#0a84ff" },
            { name: "Mara K.",  initials: "MK", hue: "#30d158" },
            { name: "Deniz A.", initials: "DA", hue: "#ffd60a" },
        ]

        property var videoTracks: [
            { name: "V2", clips: [
                { label: "Title Intro", start: 0.02, width: 0.12, hue: "#5e5ce6" },
                { label: "Lower Third", start: 0.30, width: 0.10, hue: "#5e5ce6" },
            ]},
            { name: "V1", clips: [
                { label: "A003_Take2", start: 0.00, width: 0.22, hue: "#0a84ff" },
                { label: "A007_Take1", start: 0.24, width: 0.30, hue: "#0a84ff" },
                { label: "B012_Wide",  start: 0.56, width: 0.26, hue: "#0a84ff" },
                { label: "Drone_04",   start: 0.84, width: 0.14, hue: "#0a84ff" },
            ]},
        ]

        property var audioTracks: [
            { name: "A1", clips: [
                { label: "VO_Final",   start: 0.04, width: 0.40, hue: "#30d158" },
                { label: "VO_Final_2", start: 0.48, width: 0.34, hue: "#30d158" },
            ]},
            { name: "A2", clips: [
                { label: "Score_Loop", start: 0.00, width: 0.98, hue: "#66d4cf" },
            ]},
        ]

        function timecode(t) {
            const total = Math.max(0, t)
            const h = Math.floor(total / 3600)
            const m = Math.floor((total % 3600) / 60)
            const s = Math.floor(total % 60)
            const f = Math.floor((total - Math.floor(total)) * 30)
            function pad(n) { return n < 10 ? "0" + n : "" + n }
            return pad(h) + ":" + pad(m) + ":" + pad(s) + ":" + pad(f)
        }
    }

    // playback advances the playhead at 1x
    Timer {
        running: sessionModel.playing
        interval: 33
        repeat: true
        onTriggered: {
            sessionModel.playhead =
                (sessionModel.playhead + 0.033 / sessionModel.duration) % 1.0
        }
    }

    Shortcut {
        sequence: "Space"
        onActivated: sessionModel.playing = !sessionModel.playing
    }

    // ---- layout ----------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Toolbar {
            Layout.fillWidth: true
            session: sessionModel
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            LibraryPanel {
                Layout.preferredWidth: 264
                Layout.fillHeight: true
                session: sessionModel
            }

            PreviewPanel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                session: sessionModel
            }

            InspectorPanel {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                session: sessionModel
            }
        }

        TimelinePanel {
            Layout.fillWidth: true
            Layout.preferredHeight: 300
            session: sessionModel
        }
    }
}
