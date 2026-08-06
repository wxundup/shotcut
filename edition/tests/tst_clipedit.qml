/*
 * Clip move and trim: clamping, snapping, and edge behaviour.
 * Mirrors the arithmetic in Shell's session model.
 */
import QtQuick
import QtTest

Item {
    QtObject {
        id: model

        property bool snap: true
        property real playhead: 0.5
        property var tracks: [
            { clips: [
                { label: "A", start: 0.00, width: 0.20 },
                { label: "B", start: 0.40, width: 0.20 },
            ]},
        ]

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

        function moveClip(trackIndex, clipIndex, newStart, tolerance) {
            const clip = tracks[trackIndex].clips[clipIndex]
            const targets = snapTargets(trackIndex, clipIndex)
            let start = Math.max(0, Math.min(1 - clip.width, newStart))
            const head = nearestSnap(start, targets, tolerance)
            const tail = nearestSnap(start + clip.width, targets, tolerance)
            if (head.distance <= tail.distance)
                start = head.value
            else
                start = tail.value - clip.width
            start = Math.max(0, Math.min(1 - clip.width, start))
            withClip(trackIndex, clipIndex, function (c) { c.start = start })
        }

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

        function clip(i) { return tracks[0].clips[i] }
    }

    TestCase {
        name: "ClipEditing"

        function init() {
            model.snap = true
            model.playhead = 0.5
            model.tracks = [{ clips: [
                { label: "A", start: 0.00, width: 0.20 },
                { label: "B", start: 0.40, width: 0.20 },
            ]}]
        }

        function test_move_keeps_clip_inside_sequence() {
            model.snap = false
            model.moveClip(0, 0, -0.5, 0.01)
            compare(model.clip(0).start, 0)
            model.moveClip(0, 0, 5.0, 0.01)
            fuzzyCompare(model.clip(0).start, 0.8, 0.0001)   // 1 - width
        }

        function test_move_preserves_duration() {
            model.snap = false
            const before = model.clip(0).width
            model.moveClip(0, 0, 0.33, 0.01)
            fuzzyCompare(model.clip(0).width, before, 0.0001)
        }

        function test_head_snaps_to_neighbour_edge() {
            // Dragging A's head near B's tail (0.60) should land exactly on it.
            model.moveClip(0, 0, 0.59, 0.02)
            fuzzyCompare(model.clip(0).start, 0.60, 0.0001)
        }

        function test_tail_snaps_to_neighbour_head() {
            // A's tail near B's head (0.40) snaps, so start becomes 0.20.
            model.moveClip(0, 0, 0.195, 0.02)
            fuzzyCompare(model.clip(0).start, 0.20, 0.0001)
        }

        function test_snap_can_be_turned_off() {
            model.snap = false
            model.moveClip(0, 0, 0.195, 0.02)
            fuzzyCompare(model.clip(0).start, 0.195, 0.0001)
        }

        function test_trim_in_holds_the_tail() {
            const end = model.clip(1).start + model.clip(1).width
            model.snap = false
            model.trimClip(0, 1, "in", 0.45, 0.001)
            fuzzyCompare(model.clip(1).start, 0.45, 0.0001)
            fuzzyCompare(model.clip(1).start + model.clip(1).width, end, 0.0001)
        }

        function test_trim_out_holds_the_head() {
            const start = model.clip(1).start
            model.snap = false
            model.trimClip(0, 1, "out", 0.52, 0.001)
            fuzzyCompare(model.clip(1).start, start, 0.0001)
            fuzzyCompare(model.clip(1).width, 0.12, 0.0001)
        }

        function test_trim_cannot_invert_the_clip() {
            model.snap = false
            // drag the head past the tail
            model.trimClip(0, 1, "in", 0.95, 0.001)
            verify(model.clip(1).width >= 0.01)
            verify(model.clip(1).start < model.clip(1).start + model.clip(1).width)
            // and the tail past the head
            model.trimClip(0, 1, "out", 0.0, 0.001)
            verify(model.clip(1).width >= 0.01)
        }

        function test_trim_stays_within_sequence() {
            model.snap = false
            model.trimClip(0, 1, "out", 5.0, 0.001)
            verify(model.clip(1).start + model.clip(1).width <= 1.0)
            model.trimClip(0, 1, "in", -5.0, 0.001)
            verify(model.clip(1).start >= 0)
        }
    }
}
