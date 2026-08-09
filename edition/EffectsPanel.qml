/*
 * Effects browser: search the catalogue, add to the selected clip.
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EdiTogether.Theme
import EdiTogether.Controls
import "EffectCatalogue.js" as Catalogue

Rectangle {
    id: effects

    required property var session

    property string query: ""

    // Only what applies to the selection: offering Rotation for an audio
    // clip is a control that cannot do anything.
    readonly property var catalogue: Catalogue.names().filter(function (e) {
        const kind = effects.session.selectedKind
        if (kind === "")
            return true
        const audioEffect = e.group === "Audio"
        return kind === "audio" ? audioEffect : !audioEffect
    })

    readonly property var matches: catalogue.filter(function (e) {
        if (effects.query === "")
            return true
        const q = effects.query.toLowerCase()
        return e.name.toLowerCase().indexOf(q) !== -1
            || e.group.toLowerCase().indexOf(q) !== -1
    })

    color: Theme.panel

    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: 1
        color: Theme.separator
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.m
        spacing: Theme.s

        Text {
            text: qsTr("Effects")
            font: Theme.titleFont
            color: Theme.text
            Layout.fillWidth: true
        }

        TextField {
            Layout.fillWidth: true
            placeholderText: qsTr("Search effects")
            onTextChanged: effects.query = text
        }

        Text {
            text: effects.session.selectedClip === ""
                ? qsTr("Select a clip to add effects")
                : qsTr("Double-click to add to %1").arg(effects.session.selectedClip)
            font: Theme.captionFont
            color: Theme.textTertiary
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        ListView {
            id: catalogueList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 1
            model: effects.matches
            boundsBehavior: Flickable.StopAtBounds
            enabled: effects.session.selectedClip !== ""
            opacity: enabled ? 1 : 0.45

            ScrollBar.vertical: ScrollBar {
                policy: catalogueList.contentHeight > catalogueList.height
                    ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                width: Theme.scrollbar
            }

            delegate: Rectangle {
                id: entry
                required property var modelData
                width: catalogueList.width
                height: 28
                radius: Theme.radiusControl
                color: entryArea.containsMouse ? Theme.hover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s
                    anchors.rightMargin: Theme.s
                    spacing: Theme.s

                    Text {
                        text: entry.modelData.name
                        font: Theme.bodyFont
                        color: Theme.text
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    // The group used to be repeated on every row. It never
                    // fit the column and read as clipped text, and the list
                    // is already ordered by group — so the label was saying
                    // something the arrangement already said. Removed rather
                    // than shrunk.

                }

                MouseArea {
                    id: entryArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onDoubleClicked: effects.session.addEffect(entry.modelData.name)
                }
            }
        }
    }
}
