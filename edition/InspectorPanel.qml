/*
 * Inspector: properties of the selected clip.
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EdiTogether.Theme
import EdiTogether.Controls

Rectangle {
    id: inspector

    required property var session
    readonly property bool hasSelection: session.selectedClip !== ""
    signal resetRequested()

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

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s

            Text {
                text: "Inspector"
                font: Theme.titleFont
                color: Theme.text
                Layout.fillWidth: true
            }

            ToolButton {
                text: "Reset"
                tip: "Reset all properties"
                iconSource: Qt.resolvedUrl("icons/reset.svg")
                enabled: inspector.hasSelection
                onClicked: inspector.resetRequested()
            }
        }

        Text {
            text: inspector.session.selectedClip !== ""
                ? inspector.session.selectedClip : qsTr("No selection")
            font: Theme.calloutFont
            color: inspector.session.selectedClip !== ""
                ? Theme.textSecondary : Theme.textTertiary
            elide: Text.ElideMiddle
            Layout.fillWidth: true
        }

        Segmented {
            Layout.fillWidth: true
            items: ["Video", "Audio", "Speed"]
            currentIndex: 0
            enabled: inspector.hasSelection
            opacity: enabled ? 1.0 : 0.4
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            enabled: inspector.hasSelection
            opacity: enabled ? 1.0 : 0.4

            ColumnLayout {
                width: parent.width - Theme.s
                spacing: Theme.m

                property var rows: [
                    { label: "Position X", value: 0.5 },
                    { label: "Position Y", value: 0.5 },
                    { label: "Scale",      value: 1.0 },
                    { label: "Rotation",   value: 0.0 },
                    { label: "Opacity",    value: 1.0 },
                ]

                Repeater {
                    model: parent.rows

                    ColumnLayout {
                        id: propRow
                        required property var modelData
                        property bool keyframed: false
                        Layout.fillWidth: true
                        spacing: Theme.xxs

                        // reset returns every row to its default
                        Connections {
                            target: inspector
                            function onResetRequested() {
                                propSlider.value = propRow.modelData.value
                                propRow.keyframed = false
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: propRow.modelData.label
                                font: Theme.bodyFont
                                color: Theme.textSecondary
                                Layout.fillWidth: true
                            }
                            Text {
                                text: propSlider.value.toFixed(2)
                                font: Theme.timecodeFont
                                color: Theme.text
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.s

                            Slider {
                                id: propSlider
                                Layout.fillWidth: true
                                from: 0; to: 2
                                value: propRow.modelData.value
                            }

                            ToolButton {
                                implicitWidth: 20
                                implicitHeight: 20
                                text: "Keyframe"
                                tip: "Toggle keyframe"
                                onClicked: propRow.keyframed = !propRow.keyframed
                                contentItem: Text {
                                    text: propRow.keyframed ? "◆" : "◇"
                                    font: Theme.bodyFont
                                    color: propRow.keyframed ? Theme.accent : Theme.textTertiary
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }

                Switch {
                    text: "Maintain aspect ratio"
                    checked: true
                }
            }
        }
    }
}
