/*
 * Media library: search, kind filter, grid or list.
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EdiTogether.Theme
import EdiTogether.Controls

Rectangle {
    id: library

    required property var session

    property string query: ""
    property int kindIndex: 0
    property bool listView: false

    // Real media, read from media/index.json (durations, codecs, decoded
    // thumbnails and PCM peaks). Empty if the index has not been built.
    readonly property var allItems: session.mediaItems.map(function (m) {
        return {
            label: m.label,
            name: m.name,
            dur: session.timecode(m.duration).substring(3, 8),
            kind: m.kind,
            tint: m.kind === "audio" ? "#33604a" : "#3a5f8a",
            thumb: m.thumbs.length > 0 ? m.thumbs[0] : "",
        }
    })

    readonly property var kinds: ["all", "video", "audio", "title"]

    readonly property var items: allItems.filter(function (item) {
        const kind = library.kinds[library.kindIndex]
        if (kind !== "all" && item.kind !== kind)
            return false
        if (library.query === "")
            return true
        return item.label.toLowerCase().indexOf(library.query.toLowerCase()) !== -1
    })

    function baseName(label) {
        const dot = label.lastIndexOf(".")
        return dot === -1 ? label : label.substring(0, dot)
    }

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
                text: qsTr("Library")
                font: Theme.titleFont
                color: Theme.text
                Layout.fillWidth: true
            }

            ToolButton {
                text: qsTr("View")
                tip: library.listView ? qsTr("Show as grid") : qsTr("Show as list")
                onClicked: library.listView = !library.listView

                contentItem: Column {
                    spacing: 2
                    Repeater {
                        model: library.listView ? 3 : 2
                        Rectangle {
                            width: Theme.iconSize
                            height: library.listView ? 2 : 5
                            radius: 1
                            color: Theme.textSecondary
                        }
                    }
                }
            }

            ToolButton {
                text: qsTr("Import")
                tip: qsTr("Import media  (Ctrl+I)")
                iconSource: Qt.resolvedUrl("icons/plus.svg")
            }
        }

        TextField {
            Layout.fillWidth: true
            placeholderText: qsTr("Search")
            onTextChanged: library.query = text
        }

        Segmented {
            Layout.fillWidth: true
            items: [qsTr("All"), qsTr("Video"), qsTr("Audio"), qsTr("Titles")]
            currentIndex: library.kindIndex
            onActivated: (index) => library.kindIndex = index
        }

        Text {
            text: library.items.length === 0
                ? qsTr("Nothing matches")
                : qsTr("%1 items").arg(library.items.length)
            font: Theme.captionFont
            color: Theme.textTertiary
            Layout.fillWidth: true
        }

        GridView {
            id: grid
            visible: !library.listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: (width - Theme.s) / 2
            cellHeight: cellWidth * 0.62 + 22
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: library.items

            ScrollBar.vertical: ScrollBar {
                policy: grid.contentHeight > grid.height
                    ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                width: Theme.scrollbar
            }

            delegate: Item {
                id: mediaItem
                required property var modelData
                readonly property bool selected:
                    library.session.selectedClip === library.baseName(modelData.label)

                width: grid.cellWidth - Theme.xs
                height: grid.cellHeight

                Column {
                    anchors.fill: parent
                    spacing: Theme.xs

                    Rectangle {
                        width: parent.width
                        height: parent.height - 20
                        radius: Theme.radiusControl
                        clip: true
                        color: thumbMouse.containsMouse
                            ? Qt.lighter(mediaItem.modelData.tint, 1.12)
                            : mediaItem.modelData.tint
                        border.width: 2
                        border.color: mediaItem.selected ? Theme.accent : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.fast } }

                        Image {
                            anchors.fill: parent
                            source: mediaItem.modelData.thumb === ""
                                ? "" : mediaItem.modelData.thumb
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: mediaItem.modelData.thumb !== ""
                        }

                        // audio items get peaks instead of a frame
                        Waveform {
                            anchors.fill: parent
                            anchors.margins: Theme.xs
                            visible: mediaItem.modelData.kind === "audio"
                            peaks: library.session.peaksFor(
                                mediaItem.modelData.name,
                                Math.max(8, Math.floor(width / 3)))
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: Theme.xxs
                            width: durText.width + Theme.xs
                            height: durText.height + 2
                            radius: 2
                            color: Qt.rgba(0, 0, 0, 0.55)

                            Text {
                                id: durText
                                anchors.centerIn: parent
                                text: mediaItem.modelData.dur
                                font: Theme.captionFont
                                color: "#ffffff"
                            }
                        }

                        MouseArea {
                            id: thumbMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: library.session.selectedClip
                                = library.baseName(mediaItem.modelData.label)
                        }
                    }

                    Text {
                        width: parent.width
                        text: mediaItem.modelData.label
                        font: Theme.captionFont
                        color: mediaItem.selected ? Theme.text : Theme.textSecondary
                        elide: Text.ElideMiddle
                    }
                }
            }
        }

        ListView {
            id: list
            visible: library.listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 1
            boundsBehavior: Flickable.StopAtBounds
            model: library.items

            ScrollBar.vertical: ScrollBar {
                policy: list.contentHeight > list.height
                    ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                width: Theme.scrollbar
            }

            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool selected:
                    library.session.selectedClip === library.baseName(modelData.label)

                width: list.width
                height: 30
                radius: Theme.radiusControl
                color: row.selected ? Theme.selected
                     : rowMouse.containsMouse ? Theme.hover
                     : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.xs
                    anchors.rightMargin: Theme.xs
                    spacing: Theme.s

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 18
                        radius: 2
                        clip: true
                        color: row.modelData.tint

                        Image {
                            anchors.fill: parent
                            source: row.modelData.thumb === ""
                                ? "" : row.modelData.thumb
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: row.modelData.thumb !== ""
                        }
                    }

                    Text {
                        text: row.modelData.label
                        font: Theme.bodyFont
                        color: row.selected ? Theme.text : Theme.textSecondary
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }

                    Text {
                        text: row.modelData.dur
                        font: Theme.timecodeFont
                        color: Theme.textTertiary
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: library.session.selectedClip
                        = library.baseName(row.modelData.label)
                }
            }
        }
    }
}
