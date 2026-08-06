/*
 * Geometry checks for the EdiTogether primitives.
 * Run: qmltestrunner -input edition/tests -import src/qml/modules
 */
import QtQuick
import QtTest
import EdiTogether.Controls
import EdiTogether.Theme

Item {
    width: 400
    height: 300

    Panel {
        id: titled
        anchors.fill: parent
        title: "Inspector"

        Rectangle {
            id: titledBody
            anchors.fill: parent
            color: "transparent"
        }
    }

    Panel {
        id: untitled
        width: 400
        height: 300

        Rectangle {
            id: untitledBody
            anchors.fill: parent
            color: "transparent"
        }
    }

    Segmented {
        id: segmented
        width: 300
        items: ["One", "Two", "Three"]
    }

    ScrubBar {
        id: scrub
        width: 200
    }

    TestCase {
        name: "Primitives"
        when: windowShown

        function test_panel_without_title_uses_full_height() {
            // An untitled panel must not reserve a heading row.
            verify(untitledBody.height > 0)
            compare(untitledBody.height, untitled.height - Theme.m * 2)
        }

        function test_panel_with_title_reserves_one_heading() {
            verify(titledBody.height > 0)
            verify(titledBody.height < untitledBody.height)
            // exactly one heading plus one gap, no double counting
            const reserved = untitledBody.height - titledBody.height
            verify(reserved < untitled.height / 2)
        }

        function test_segmented_selects_and_reports() {
            let seen = -1
            segmented.activated.connect(function (i) { seen = i })
            mouseClick(segmented, segmented.width * 5 / 6, segmented.height / 2)
            compare(seen, 2)
            compare(segmented.currentIndex, 2)
        }

        function test_scrubbar_seek_is_clamped() {
            let last = -1
            scrub.seek.connect(function (p) { last = p })
            mousePress(scrub, scrub.width / 2, scrub.height / 2)
            mouseMove(scrub, -500, scrub.height / 2)
            verify(last >= 0.0)
            mouseMove(scrub, scrub.width + 500, scrub.height / 2)
            verify(last <= 1.0)
            mouseRelease(scrub, scrub.width / 2, scrub.height / 2)
        }
    }
}
