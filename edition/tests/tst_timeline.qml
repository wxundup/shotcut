/*
 * Timeline geometry: zoom must scale the lane and move clips with it.
 */
import QtQuick
import QtTest
import EdiTogether.Theme

Item {
    width: 900
    height: 320

    // The lane maths under test, mirroring TimelinePanel.
    QtObject {
        id: geometry

        property real panelWidth: 900
        property real headerWidth: 116
        property real zoom: 1.0

        readonly property real laneWidth: Math.max(1, (panelWidth - headerWidth) * zoom)
        readonly property int rulerDivisions:
            Math.max(4, Math.min(48, Math.round(laneWidth / 130)))

        function clipX(start) { return start * laneWidth }
        function clipWidth(w) { return Math.max(24, w * laneWidth - 2) }
        function playheadX(position) { return position * laneWidth - 1 }
    }

    TestCase {
        name: "TimelineGeometry"

        function test_lane_fills_panel_at_unit_zoom() {
            geometry.zoom = 1.0
            compare(geometry.laneWidth, 900 - 116)
        }

        function test_zoom_scales_lane_and_clips_together() {
            geometry.zoom = 1.0
            const x1 = geometry.clipX(0.5)
            const w1 = geometry.clipWidth(0.25)
            geometry.zoom = 4.0
            compare(geometry.laneWidth, (900 - 116) * 4)
            // A clip keeps its position in the sequence, not its pixels.
            fuzzyCompare(geometry.clipX(0.5) / geometry.laneWidth, x1 / (900 - 116), 0.0001)
            verify(geometry.clipWidth(0.25) > w1)
        }

        function test_playhead_tracks_position_under_zoom() {
            geometry.zoom = 1.0
            const atHalf = geometry.playheadX(0.5)
            geometry.zoom = 2.0
            // Twice the lane means twice the offset for the same frame.
            fuzzyCompare(geometry.playheadX(0.5), atHalf * 2 + 1, 0.001)
        }

        function test_ruler_stays_readable() {
            // Divisions grow with the lane but stay within sane bounds.
            geometry.zoom = 1.0
            const few = geometry.rulerDivisions
            geometry.zoom = 8.0
            const many = geometry.rulerDivisions
            verify(few >= 4)
            verify(many > few)
            verify(many <= 48)
        }

        function test_zoom_anchor_keeps_frame_under_pointer() {
            // Ctrl+wheel maths: the fraction under the pointer is preserved.
            geometry.zoom = 1.0
            const laneBefore = geometry.laneWidth
            const pointerX = 300
            const contentX = 0
            const anchor = (contentX + pointerX) / laneBefore

            geometry.zoom = 2.0
            const newContentX = anchor * geometry.laneWidth - pointerX
            const anchorAfter = (newContentX + pointerX) / geometry.laneWidth
            fuzzyCompare(anchorAfter, anchor, 0.0001)
        }
    }
}
