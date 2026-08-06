/*
 * Media library: search, kind filter, clip grid.
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import EdiTogether.Theme
import EdiTogether.Controls

Rectangle {
    id: library

    required property var session

    color: Theme.panel

    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 1
        color: Theme.separator
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.m
        spacing: Theme.s

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s

            Text {
                text: "Library"
                font: Theme.titleFont
                color: Theme.text
                Layout.fillWidth: true
            }

            ToolButton {
                text: "Import"
                tip: "Import media  (Ctrl+I)"
                iconSource: Qt.resolvedUrl("icons/plus.svg")
            }
        }

        TextField {
            Layout.fillWidth: true
            placeholderText: "Search"
        }

        Segmented {
            Layout.fillWidth: true
            items: ["Media", "Audio", "Titles"]
            currentIndex: 0
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: (width - Theme.s) / 2
            cellHeight: cellWidth * 0.62 + 22
            clip: true

            model: ListModel {
                ListElement { label: "A003_Take2.mp4"; dur: "00:42"; tint: "#3a5f8a" }
                ListElement { label: "A007_Take1.mp4"; dur: "01:07"; tint: "#3a5f8a" }
                ListElement { label: "B012_Wide.mp4";  dur: "00:18"; tint: "#41546e" }
                ListElement { label: "Drone_04.mp4";   dur: "00:33"; tint: "#2f5d50" }
                ListElement { label: "VO_Final.wav";   dur: "02:14"; tint: "#33604a" }
                ListElement { label: "Score_Loop.wav"; dur: "03:01"; tint: "#2e6a68" }
            }

            delegate: Item {
                id: mediaItem
                required property string label
                required property string dur
                required property color tint
                width: grid.cellWidth - Theme.xs
                height: grid.cellHeight

                Column {
                    anchors.fill: parent
                    spacing: Theme.xs

                    Rectangle {
                        width: parent.width
                        height: parent.height - 20
                        radius: Theme.radiusControl
                        color: thumbMouse.containsMouse
                            ? Qt.lighter(mediaItem.tint, 1.12) : mediaItem.tint
                        border.width: 2
                        border.color: library.session.selectedClip
                            === mediaItem.label.split(".")[0]
                            ? Theme.accent : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.fast } }

                        Text {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: Theme.xs
                            text: mediaItem.dur
                            font: Theme.captionFont
                            color: Theme.textOnAccent
                        }

                        MouseArea {
                            id: thumbMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: library.session.selectedClip
                                = mediaItem.label.split(".")[0]
                        }
                    }

                    Text {
                        width: parent.width
                        text: mediaItem.label
                        font: Theme.captionFont
                        color: Theme.textSecondary
                        elide: Text.ElideMiddle
                    }
                }
            }
        }
    }
}
