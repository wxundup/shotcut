/*
 * EdiTogether shell — target UX reference.
 * Run: qml -I <repo>/src/qml/modules Shell.qml
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EdiTogether.Theme
import "EffectCatalogue.js" as Catalogue

ApplicationWindow {
    id: root

    width: 1440
    height: 900
    minimumWidth: 1080
    minimumHeight: 700
    visible: true
    title: "Untitled Project — EdiTogether"
    color: Theme.window

    // Real media: durations, codecs, decoded thumbnails and PCM peaks read
    // from media/index.json.
    MediaLibrary {
        id: mediaLibrary
    }

    // Move the playhead from outside the transport (menu, shortcut, host app).
    function seek(position) {
        sessionModel.playhead = Math.max(0, Math.min(1, position))
    }

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

        // Scope samples, filled by reading pixels back from the program
        // monitor (see FrameSampler in PreviewPanel). Empty until a frame
        // has been grabbed.
        property var frameSamples: []

        // ---- effects -------------------------------------------------------
        // The stack applied to the selected clip. Parameters carry their own
        // keyframes; an empty list means the value is constant.
        property var effects: [
            { name: qsTr("Transform"), on: true, params: [
                { name: qsTr("Position X"), value: 0.50, min: 0, max: 1, keyframes: [] },
                { name: qsTr("Position Y"), value: 0.50, min: 0, max: 1, keyframes: [] },
                { name: qsTr("Scale"),      value: 1.00, min: 0, max: 4, keyframes: [] },
                { name: qsTr("Rotation"),   value: 0.00, min: -180, max: 180, keyframes: [] },
            ]},
            { name: qsTr("Opacity"), on: true, params: [
                { name: qsTr("Level"), value: 1.00, min: 0, max: 1,
                  keyframes: [{ time: 0.0, value: 0.0 }, { time: 0.12, value: 1.0 }] },
            ]},
        ]

        // Value of a parameter at the playhead: keyframes interpolate
        // linearly, otherwise the constant value stands.
        function paramValue(param, position) {
            const keys = param.keyframes
            if (!keys || keys.length === 0)
                return param.value
            if (position <= keys[0].time)
                return keys[0].value
            if (position >= keys[keys.length - 1].time)
                return keys[keys.length - 1].value
            for (var i = 0; i < keys.length - 1; i++) {
                const a = keys[i]
                const b = keys[i + 1]
                if (position >= a.time && position <= b.time) {
                    const span = b.time - a.time
                    const t = span <= 0 ? 0 : (position - a.time) / span
                    return a.value + (b.value - a.value) * t
                }
            }
            return param.value
        }

        // What kind of clip is selected: an audio clip should not be
        // offered Position or Rotation, and a video clip should not be
        // offered a compressor.
        readonly property string selectedKind: {
            for (var t = 0; t < tracks.length; t++) {
                const clips = tracks[t].clips
                for (var c = 0; c < clips.length; c++) {
                    if (clips[c].label === selectedClip)
                        return clips[c].kind === "audio" ? "audio" : "video"
                }
            }
            return ""
        }

        function findParam(effect, name) {
            for (var i = 0; i < effect.params.length; i++) {
                if (effect.params[i].name === name)
                    return effect.params[i]
            }
            return null
        }

        // Resolve the effect stack into the geometry the compositor applies.
        // Only the selected clip carries the stack in this model; others
        // render untouched.
        function effectsFor(clip) {
            const result = {
                opacity: 1, scale: 1,
                positionX: 0.5, positionY: 0.5, rotation: 0,
            }
            if (!clip || clip.label !== selectedClip)
                return result

            // Position within the clip drives keyframed parameters.
            const local = Math.max(0, Math.min(1,
                (playhead - clip.start) / Math.max(0.0001, clip.width)))

            for (var i = 0; i < effects.length; i++) {
                const effect = effects[i]
                if (!effect.on)
                    continue
                if (effect.name === qsTr("Transform")) {
                    const px = findParam(effect, qsTr("Position X"))
                    const py = findParam(effect, qsTr("Position Y"))
                    const sc = findParam(effect, qsTr("Scale"))
                    const rot = findParam(effect, qsTr("Rotation"))
                    if (px) result.positionX = paramValue(px, local)
                    if (py) result.positionY = paramValue(py, local)
                    if (sc) result.scale = paramValue(sc, local)
                    if (rot) result.rotation = paramValue(rot, local)
                } else if (effect.name === qsTr("Opacity")) {
                    const level = findParam(effect, qsTr("Level"))
                    if (level)
                        result.opacity = paramValue(level, local)
                }
            }
            return result
        }

        function withEffects(fn) {
            const next = effects.map(function (e) {
                return Object.assign({}, e, {
                    params: e.params.map(function (p) { return Object.assign({}, p) })
                })
            })
            fn(next)
            effects = next
        }

        function addEffect(name) {
            if (selectedClip === "")
                return
            // Defaults come from the catalogue, so the browser, the
            // inspector and the renderer cannot disagree about an effect.
            const params = Catalogue.defaultParams(name)
            effects = effects.concat([{ name: name, on: true, params: params }])
        }

        function removeEffect(index) {
            const next = effects.slice()
            next.splice(index, 1)
            effects = next
        }

        function toggleEffect(index) {
            withEffects(function (next) { next[index].on = !next[index].on })
        }

        function setParam(effectIndex, paramIndex, value) {
            withEffects(function (next) { next[effectIndex].params[paramIndex].value = value })
        }

        function addKeyframe(effectIndex, paramIndex) {
            withEffects(function (next) {
                const p = next[effectIndex].params[paramIndex]
                const keys = p.keyframes.slice()
                    .filter(function (k) { return Math.abs(k.time - playhead) > 0.005 })
                keys.push({ time: playhead, value: p.value })
                keys.sort(function (a, b) { return a.time - b.time })
                p.keyframes = keys
            })
        }

        function setKeyframes(effectIndex, paramIndex, keyframes) {
            withEffects(function (next) {
                next[effectIndex].params[paramIndex].keyframes = keyframes
            })
        }

        function resetEffects() {
            withEffects(function (next) {
                for (var i = 0; i < next.length; i++) {
                    next[i].on = true
                    for (var j = 0; j < next[i].params.length; j++)
                        next[i].params[j].keyframes = []
                }
            })
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
                { label: "Title Intro", start: 0.02, width: 0.12, kind: "title",
                  media: "Drone_04" },
                { label: "Lower Third", start: 0.30, width: 0.10, kind: "title",
                  media: "B012_Wide" },
            ]},
            { name: "V1", audio: false, muted: false, soloed: false, locked: false,
              volume: 1.0, level: 0.0, clips: [
                { label: "A003_Take2", start: 0.00, width: 0.22, kind: "video",
                  media: "A003_Take2" },
                { label: "A007_Take1", start: 0.24, width: 0.30, kind: "video",
                  media: "A007_Take1" },
                { label: "B012_Wide",  start: 0.56, width: 0.26, kind: "video",
                  media: "B012_Wide" },
                { label: "Drone_04",   start: 0.84, width: 0.07, kind: "video",
                  media: "Drone_04" },
                { label: "C001_Master", start: 0.92, width: 0.06, kind: "video",
                  media: "C001_Master" },
            ]},
            { name: "A1", audio: true, muted: false, soloed: false, locked: false,
              volume: 0.82, level: 0.0,
              dsp: { eqOn: true,
                     bands: [
                        { type: "lowshelf",  freq: 110,  gain: -4.0, q: 0.7, on: true },
                        { type: "peaking",   freq: 2600, gain:  3.5, q: 1.2, on: true },
                        { type: "highshelf", freq: 9000, gain:  2.0, q: 0.7, on: true },
                     ],
                     compOn: true, threshold: -20, ratio: 3.5, attack: 12, release: 180,
                     limitOn: true, ceiling: -1.0, reduction: 0 },
              clips: [
                { label: "VO_Final",   start: 0.04, width: 0.40, kind: "audio",
                  media: "VO_Final" },
                { label: "VO_Final_2", start: 0.48, width: 0.34, kind: "audio",
                  media: "VO_Final" },
            ]},
            { name: "A2", audio: true, muted: false, soloed: false, locked: false,
              volume: 0.55, level: 0.0,
              dsp: { eqOn: true,
                     bands: [
                        { type: "lowshelf",  freq: 90,    gain:  2.0, q: 0.7, on: true },
                        { type: "peaking",   freq: 500,   gain: -2.5, q: 1.4, on: true },
                        { type: "highshelf", freq: 10000, gain:  1.0, q: 0.7, on: true },
                     ],
                     compOn: false, threshold: -18, ratio: 4, attack: 20, release: 250,
                     limitOn: true, ceiling: -1.5, reduction: 0 },
              clips: [
                { label: "Score_Loop", start: 0.00, width: 0.98, kind: "audio",
                  media: "Score_Loop" },
            ]},
        ]

        // Peaks decoded from the file's PCM, resampled to the requested
        // number of buckets. Empty when the media has no analysis.
        //
        // Peaks are normalised against the file's own loudest sample so a
        // quiet recording is still readable — the shape is the real signal,
        // the scale is relative to that file.
        function peaksFor(name, count) {
            const raw = mediaLibrary.peaksFor(name)
            if (!raw || raw.length === 0)
                return []
            let loudest = 0
            for (var n = 0; n < raw.length; n++)
                loudest = Math.max(loudest, raw[n])
            const scale = loudest > 0.001 ? 1 / loudest : 1
            const source = raw.map(function (p) { return Math.min(1, p * scale) })
            if (count >= source.length)
                return source
            // Downsample by taking the loudest peak in each bucket, so a
            // transient never disappears at low zoom.
            const out = []
            const step = source.length / count
            for (var i = 0; i < count; i++) {
                let peak = 0
                const from = Math.floor(i * step)
                const to = Math.min(source.length, Math.floor((i + 1) * step))
                for (var j = from; j < to; j++)
                    peak = Math.max(peak, source[j])
                out.push(peak)
            }
            return out
        }

        // Everything the media index knows, for panels that list it.
        readonly property var mediaItems: mediaLibrary.items

        // Editing runs on proxies where they exist; delivery renders from
        // the originals regardless, so this is a playback choice only.
        property bool useProxies: mediaLibrary.useProxies
        readonly property int proxyCount: mediaLibrary.proxyCount
        onUseProxiesChanged: mediaLibrary.useProxies = useProxies

        function hasProxy(name) { return mediaLibrary.hasProxy(name) }
        function originalFor(name) { return mediaLibrary.originalFor(name) }

        // Frames decoded from the file at even intervals.
        function thumbnailsFor(name) {
            return mediaLibrary.thumbsFor(name)
        }

        // The clip under the playhead on the topmost video track, which is
        // what the program monitor should be decoding.
        readonly property var programClip: {
            for (var t = 0; t < tracks.length; t++) {
                if (tracks[t].audio)
                    continue
                const clips = tracks[t].clips
                for (var c = 0; c < clips.length; c++) {
                    const clip = clips[c]
                    if (playhead >= clip.start && playhead < clip.start + clip.width)
                        return clip
                }
            }
            return null
        }

        function sourceFor(name) {
            return mediaLibrary.sourceFor(name)
        }

        // ---- channel processing ---------------------------------------------
        // Defaults are a working starting point rather than a bypass: a gentle
        // 4:1 at -18 dB and a ceiling just under full scale.
        function defaultDsp() {
            return {
                eqOn: false,
                bands: [
                    { type: "lowshelf",  freq: 120,   gain: 0, q: 0.7, on: true },
                    { type: "peaking",   freq: 1000,  gain: 0, q: 1.0, on: true },
                    { type: "highshelf", freq: 8000,  gain: 0, q: 0.7, on: true },
                ],
                compOn: false,
                threshold: -18,
                ratio: 4,
                attack: 20,
                release: 250,
                limitOn: false,
                ceiling: -1,
                reduction: 0,
            }
        }

        function setDsp(trackIndex, key, value) {
            const next = tracks.slice()
            const track = Object.assign({}, next[trackIndex])
            track.dsp = Object.assign({}, track.dsp || defaultDsp())
            track.dsp[key] = value
            next[trackIndex] = track
            tracks = next
        }

        function setEqBand(trackIndex, bandIndex, freq, gain) {
            const next = tracks.slice()
            const track = Object.assign({}, next[trackIndex])
            const dsp = Object.assign({}, track.dsp || defaultDsp())
            const bands = dsp.bands.slice()
            bands[bandIndex] = Object.assign({}, bands[bandIndex], {
                freq: Math.round(freq),
                gain: Math.round(gain * 10) / 10,
            })
            dsp.bands = bands
            track.dsp = dsp
            next[trackIndex] = track
            tracks = next
        }

        // ---- clip editing ---------------------------------------------------
        // Edge points a dragged clip can snap to: the playhead, the sequence
        // ends, and every other clip's boundaries on any track.
        function snapTargets(trackIndex, clipIndex) {
            const out = [0, 1, playhead]
            for (var t = 0; t < tracks.length; t++) {
                const clips = tracks[t].clips
                for (var c = 0; c < clips.length; c++) {
                    if (t === trackIndex && c === clipIndex)
                        continue
                    out.push(clips[c].start)
                    out.push(clips[c].start + clips[c].width)
                }
            }
            return out
        }

        // Returns {value, distance}: distance is Infinity when nothing was
        // close enough, so callers can tell a real snap from a no-op.
        function nearestSnap(value, targets, tolerance) {
            if (!snap)
                return { value: value, distance: Infinity }
            let best = value
            let bestDist = Infinity
            for (var i = 0; i < targets.length; i++) {
                const d = Math.abs(targets[i] - value)
                if (d <= tolerance && d < bestDist) {
                    bestDist = d
                    best = targets[i]
                }
            }
            return { value: best, distance: bestDist }
        }

        function snapValue(value, targets, tolerance) {
            return nearestSnap(value, targets, tolerance).value
        }

        function withClip(trackIndex, clipIndex, fn) {
            const nextTracks = tracks.slice()
            const track = Object.assign({}, nextTracks[trackIndex])
            const clips = track.clips.slice()
            const clip = Object.assign({}, clips[clipIndex])
            fn(clip)
            clips[clipIndex] = clip
            track.clips = clips
            nextTracks[trackIndex] = track
            tracks = nextTracks
        }

        // Move a clip along its track. Start is clamped to the sequence and
        // snapped to nearby edges.
        function moveClip(trackIndex, clipIndex, newStart, tolerance) {
            const clip = tracks[trackIndex].clips[clipIndex]
            const targets = snapTargets(trackIndex, clipIndex)
            let start = Math.max(0, Math.min(1 - clip.width, newStart))
            // Either edge may snap; take whichever is genuinely closer.
            const head = nearestSnap(start, targets, tolerance)
            const tail = nearestSnap(start + clip.width, targets, tolerance)
            if (head.distance <= tail.distance)
                start = head.value
            else
                start = tail.value - clip.width
            start = Math.max(0, Math.min(1 - clip.width, start))
            withClip(trackIndex, clipIndex, function (c) { c.start = start })
        }

        // Trim an edge. The opposite edge stays put and the clip keeps a
        // minimum visible length.
        function trimClip(trackIndex, clipIndex, edge, position, tolerance) {
            const clip = tracks[trackIndex].clips[clipIndex]
            const targets = snapTargets(trackIndex, clipIndex)
            const minWidth = 0.01
            const snapped = snapValue(position, targets, tolerance)
            if (edge === "in") {
                const end = clip.start + clip.width
                const start = Math.max(0, Math.min(end - minWidth, snapped))
                withClip(trackIndex, clipIndex, function (c) {
                    c.start = start
                    c.width = end - start
                })
            } else {
                const end = Math.max(clip.start + minWidth, Math.min(1, snapped))
                withClip(trackIndex, clipIndex, function (c) {
                    c.width = end - c.start
                })
            }
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

            EffectsPanel {
                Layout.preferredWidth: 236
                // Without a floor the layout squeezes this below its
                // content and the group labels clip.
                Layout.minimumWidth: 236
                Layout.fillHeight: true
                visible: sessionModel.workspace === "Edit"
                    && root.width >= 1400
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
