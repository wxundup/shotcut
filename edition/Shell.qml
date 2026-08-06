/*
 * EdiTogether shell — target UX reference.
 * Run: qml -I <repo>/src/qml/modules Shell.qml
 */
pragma ComponentBehavior: Bound
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

    // Switch workspaces from outside the toolbar (menu, shortcut, host app).
    function openWorkspace(name) {
        if (sessionModel.workspaces.indexOf(name) !== -1)
            sessionModel.workspace = name
    }

    // ---- mock session state -------------------------------------------------
    QtObject {
        id: sessionModel

        property string projectTitle: "Untitled Project"
        property bool playing: false
        property real playhead: 0.23          // 0..1 of timeline
        property real duration: 96.0          // seconds
        readonly property var workspaces: ["Edit", "Color", "Audio", "Deliver"]
        property string workspace: "Edit"
        property bool snap: true
        property string selectedClip: "A007_Take1"
        property string inviteCode: ""
        property int zoomIndex: 0

        // Master levels, only meaningful while transport runs.
        property real masterLeft: 0.0
        property real masterRight: 0.0
        property real masterPeakLeft: 0.0
        property real masterPeakRight: 0.0
        property real masterGain: 0.8

        // ---- grading -------------------------------------------------------
        property var grade: ({
            lift:  { x: 0, y: 0, master: 0 },
            gamma: { x: 0, y: 0, master: 0 },
            gain:  { x: 0, y: 0, master: 0 },
        })
        property var toneCurve: [{ x: 0, y: 0 }, { x: 1, y: 1 }]

        function setGrade(key, x, y, master) {
            const next = Object.assign({}, grade)
            next[key] = { x: x, y: y, master: master }
            grade = next
        }

        function resetGrade() {
            grade = {
                lift:  { x: 0, y: 0, master: 0 },
                gamma: { x: 0, y: 0, master: 0 },
                gain:  { x: 0, y: 0, master: 0 },
            }
            toneCurve = [{ x: 0, y: 0 }, { x: 1, y: 1 }]
        }

        // Samples of the displayed frame for the scopes. Empty until a frame
        // exists; the stand-in below stands for real pixel readback.
        property var frameSamples: []

        function sampleFrame() {
            const out = []
            const seed = Math.floor(playhead * 1000)
            let x = seed * 9301 + 49297
            for (var i = 0; i < 220; i++) {
                x = (x * 9301 + 49297) % 233280
                const n = x / 233280
                const base = 0.25 + 0.5 * Math.abs(Math.sin(i / 24 + playhead * 6))
                out.push({
                    r: Math.min(1, base + n * 0.18 + grade.gain.master * 0.3),
                    g: Math.min(1, base + n * 0.12 + grade.gamma.master * 0.3),
                    b: Math.min(1, base * 0.92 + n * 0.2 + grade.lift.master * 0.3),
                })
            }
            return out
        }

        // ---- delivery ------------------------------------------------------
        property var exportQueue: []

        function queueExport(presetName) {
            const job = {
                name: presetName + " · " + projectTitle,
                progress: 0.0,
            }
            exportQueue = exportQueue.concat([job])
        }

        property var collaborators: [
            { name: "You",      initials: "YJ", hue: "#0a84ff" },
            { name: "Mara K.",  initials: "MK", hue: "#30d158" },
            { name: "Deniz A.", initials: "DA", hue: "#ffd60a" },
        ]

        // Tracks carry their own state so the heads are real controls, not
        // decoration. Audio clips carry peak arrays; a real project would
        // fill these from PCM analysis rather than the stand-in below.
        property var tracks: [
            { name: "V2", audio: false, muted: false, soloed: false, locked: false,
              volume: 1.0, level: 0.0, clips: [
                { label: "Title Intro", start: 0.02, width: 0.12, kind: "title" },
                { label: "Lower Third", start: 0.30, width: 0.10, kind: "title" },
            ]},
            { name: "V1", audio: false, muted: false, soloed: false, locked: false,
              volume: 1.0, level: 0.0, clips: [
                { label: "A003_Take2", start: 0.00, width: 0.22, kind: "video" },
                { label: "A007_Take1", start: 0.24, width: 0.30, kind: "video" },
                { label: "B012_Wide",  start: 0.56, width: 0.26, kind: "video" },
                { label: "Drone_04",   start: 0.84, width: 0.14, kind: "video" },
            ]},
            { name: "A1", audio: true, muted: false, soloed: false, locked: false,
              volume: 0.82, level: 0.0, clips: [
                { label: "VO_Final",   start: 0.04, width: 0.40, kind: "audio", seed: 7 },
                { label: "VO_Final_2", start: 0.48, width: 0.34, kind: "audio", seed: 23 },
            ]},
            { name: "A2", audio: true, muted: false, soloed: false, locked: false,
              volume: 0.55, level: 0.0, clips: [
                { label: "Score_Loop", start: 0.00, width: 0.98, kind: "audio", seed: 41 },
            ]},
        ]

        // Stand-in peaks: stable for a given seed so the drawing never
        // flickers between frames. Replaced by real analysis later.
        function peaksFor(seed, count) {
            const out = []
            let x = seed * 9301 + 49297
            for (var i = 0; i < count; i++) {
                x = (x * 9301 + 49297) % 233280
                const noise = x / 233280
                const envelope = 0.35 + 0.45 * Math.abs(Math.sin(i / 7 + seed))
                out.push(Math.min(1, envelope * (0.55 + 0.75 * noise)))
            }
            return out
        }

        // Stand-in thumbnails until real decode is wired in. Each clip gets a
        // stable set so the strip does not shuffle on every repaint.
        readonly property var thumbnailSets: ({
            "A003_Take2": ["thumbs/take2-a.svg", "thumbs/take2-b.svg", "thumbs/take2-c.svg"],
            "A007_Take1": ["thumbs/take1-a.svg", "thumbs/take1-b.svg", "thumbs/take1-c.svg"],
            "B012_Wide":  ["thumbs/wide-a.svg", "thumbs/wide-b.svg"],
            "Drone_04":   ["thumbs/drone-a.svg", "thumbs/drone-b.svg"],
        })

        function thumbnailsFor(label) {
            const set = thumbnailSets[label]
            if (!set)
                return []
            return set.map(function (p) { return Qt.resolvedUrl(p) })
        }

        function setTrackProperty(index, key, value) {
            const copy = tracks.slice()
            copy[index] = Object.assign({}, copy[index])
            copy[index][key] = value
            tracks = copy
        }

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

    // ponytail: TextEdit.copy() is the clipboard, no extra type needed
    TextEdit {
        id: shellClipboard
        visible: false
        onTextChanged: {
            if (text !== "") {
                selectAll()
                copy()
            }
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

            // Meters follow the playhead's position in the stand-in peaks so
            // they move with the material rather than at random.
            const t = sessionModel.playhead * 240
            const l = 0.45 + 0.35 * Math.abs(Math.sin(t / 3.1))
            const r = 0.42 + 0.38 * Math.abs(Math.sin(t / 2.7 + 0.6))
            sessionModel.masterLeft = l
            sessionModel.masterRight = r
            sessionModel.masterPeakLeft = Math.max(l, sessionModel.masterPeakLeft * 0.97)
            sessionModel.masterPeakRight = Math.max(r, sessionModel.masterPeakRight * 0.97)

            // Audio track meters follow their own fader.
            const next = sessionModel.tracks.map(function (track, i) {
                if (!track.audio)
                    return track
                const wobble = 0.5 + 0.4 * Math.abs(Math.sin(t / (2.3 + i)))
                return Object.assign({}, track, {
                    level: track.muted ? 0 : wobble * track.volume
                })
            })
            sessionModel.tracks = next

            // Scopes read the frame that is on screen.
            if (sessionModel.workspace === "Color")
                sessionModel.frameSamples = sessionModel.sampleFrame()
        }
    }

    // Sample once when entering Color so the scopes are not blank while paused.
    Connections {
        target: sessionModel
        function onWorkspaceChanged() {
            if (sessionModel.workspace === "Color")
                sessionModel.frameSamples = sessionModel.sampleFrame()
        }
    }

    // Export jobs advance while queued.
    Timer {
        running: sessionModel.exportQueue.some(function (j) { return j.progress < 1 })
        interval: 120
        repeat: true
        onTriggered: {
            sessionModel.exportQueue = sessionModel.exportQueue.map(function (job) {
                return job.progress >= 1
                    ? job
                    : Object.assign({}, job, { progress: Math.min(1, job.progress + 0.035) })
            })
        }
    }

    // Silence the meters when transport stops.
    Connections {
        target: sessionModel
        function onPlayingChanged() {
            if (!sessionModel.playing) {
                sessionModel.masterLeft = 0
                sessionModel.masterRight = 0
                sessionModel.masterPeakLeft = 0
                sessionModel.masterPeakRight = 0
                sessionModel.tracks = sessionModel.tracks.map(function (track) {
                    return track.audio ? Object.assign({}, track, { level: 0 }) : track
                })
            }
        }
    }

    Shortcut {
        sequence: "Space"
        onActivated: sessionModel.playing = !sessionModel.playing
    }

    Shortcut {
        sequence: "Esc"
        onActivated: sessionModel.selectedClip = ""
    }

    // Workspace shortcuts, the way editors expect them.
    Repeater {
        model: sessionModel.workspaces

        Item {
            id: workspaceShortcut
            required property var modelData
            required property int index

            Shortcut {
                sequence: "Ctrl+" + (workspaceShortcut.index + 1)
                onActivated: root.openWorkspace(workspaceShortcut.modelData)
            }
        }
    }

    // ---- layout ----------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Toolbar {
            Layout.fillWidth: true
            session: sessionModel
            // In the app this hands off to CollabSession; standalone it
            // stands in for a hosted session.
            onShareRequested: {
                if (sessionModel.inviteCode === "")
                    sessionModel.inviteCode = "K4P2XM"
                else
                    shellClipboard.text = sessionModel.inviteCode
            }
        }

        // The upper region is what the workspace changes; the timeline stays,
        // because every workspace is still editing the same sequence.
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            LibraryPanel {
                Layout.preferredWidth: 264
                Layout.fillHeight: true
                visible: sessionModel.workspace === "Edit"
                session: sessionModel
            }

            PreviewPanel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: sessionModel.workspace === "Edit"
                    || sessionModel.workspace === "Color"
                Layout.maximumWidth: sessionModel.workspace === "Color"
                    ? parent.width * 0.42 : parent.width
                session: sessionModel
            }

            ColorPanel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: sessionModel.workspace === "Color"
                session: sessionModel
            }

            AudioPanel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: sessionModel.workspace === "Audio"
                session: sessionModel
            }

            DeliverPanel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: sessionModel.workspace === "Deliver"
                session: sessionModel
            }

            InspectorPanel {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                visible: sessionModel.workspace === "Edit"
                session: sessionModel
            }
        }

        TimelinePanel {
            Layout.fillWidth: true
            Layout.preferredHeight: sessionModel.workspace === "Deliver" ? 180 : 300
            session: sessionModel

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: Theme.normal }
            }
        }
    }
}
