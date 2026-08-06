/*
 * Effects browser: search the catalogue, add to the selected clip.
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EdiTogether.Theme
import EdiTogether.Controls

Rectangle {
    id: effects

    required property var session

    property string query: ""

    readonly property var catalogue: [
        { name: qsTr("Transform"),      group: qsTr("Motion") },
        { name: qsTr("Crop"),           group: qsTr("Motion") },
        { name: qsTr("Corner Pin"),     group: qsTr("Motion") },
        { name: qsTr("Opacity"),        group: qsTr("Motion") },
        { name: qsTr("Colour Balance"), group: qsTr("Colour") },
        { name: qsTr("Curves"),         group: qsTr("Colour") },
        { name: qsTr("Saturation"),     group: qsTr("Colour") },
        { name: qsTr("White Balance"),  group: qsTr("Colour") },
        { name: qsTr("Gaussian Blur"),  group: qsTr("Blur") },
        { name: qsTr("Sharpen"),        group: qsTr("Blur") },
        { name: qsTr("Text"),           group: qsTr("Generate") },
        { name: qsTr("Timer"),          group: qsTr("Generate") },
        { name: qsTr("Gain"),           group: qsTr("Audio") },
        { name: qsTr("Compressor"),     group: qsTr("Audio") },
        { name: qsTr("Parametric EQ"),  group: qsTr("Audio") },
    ]

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

                    Text {
                        text: entry.modelData.group
                        font: Theme.captionFont
                        color: Theme.textTertiary
                        Layout.maximumWidth: 64
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignRight
                    }
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
