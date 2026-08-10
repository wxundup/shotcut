/*
 * Inspector: the effect stack applied to the selected clip, each parameter
 * with a value and a keyframe lane.
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
                text: qsTr("Effect Controls")
                font: Theme.titleFont
                color: Theme.text
                Layout.fillWidth: true
            }

            ToolButton {
                text: qsTr("Reset")
                tip: qsTr("Reset every effect on this clip")
                iconSource: Qt.resolvedUrl("icons/reset.svg")
                enabled: inspector.hasSelection
                onClicked: inspector.session.resetEffects()
            }
        }

        Text {
            text: inspector.hasSelection
                ? inspector.session.selectedClip : qsTr("No selection")
            font: Theme.calloutFont
            color: inspector.hasSelection ? Theme.textSecondary : Theme.textTertiary
            elide: Text.ElideMiddle
            Layout.fillWidth: true
        }

        // Time ruler for the keyframe lanes, so the diamonds have a scale.
        RowLayout {
            Layout.fillWidth: true
            visible: inspector.hasSelection
            spacing: Theme.s

            Text {
                text: qsTr("Parameter")
                font: Theme.captionFont
                color: Theme.textTertiary
                Layout.preferredWidth: 96
            }

            Text {
                text: qsTr("Keyframes")
                font: Theme.captionFont
                color: Theme.textTertiary
                Layout.fillWidth: true
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            enabled: inspector.hasSelection
            opacity: enabled ? 1.0 : 0.4
            clip: true

            ColumnLayout {
                width: inspector.width - Theme.m * 2 - Theme.s
                spacing: Theme.m

                Repeater {
                    model: inspector.session.effects

                    ColumnLayout {
                        id: effectBlock
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: Theme.xs

                        // effect header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.xs

                            Rectangle {
                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 14
                                radius: 3
                                color: effectBlock.modelData.on
                                    ? Theme.accent : "transparent"
                                border.width: effectBlock.modelData.on ? 0 : 1
                                border.color: Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font: Theme.captionFont
                                    color: Theme.textOnAccent
                                    visible: effectBlock.modelData.on
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: inspector.session.toggleEffect(effectBlock.index)
                                }
                            }

                            Text {
                                text: effectBlock.modelData.name
                                font: Theme.bodyFont
                                color: effectBlock.modelData.on
                                    ? Theme.text : Theme.textTertiary
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            ToolButton {
                                implicitWidth: 18
                                implicitHeight: 18
                                text: qsTr("Remove")
                                tip: qsTr("Remove effect")
                                onClicked: inspector.session.removeEffect(effectBlock.index)
                                contentItem: Text {
                                    text: "×"
                                    font: Theme.calloutFont
                                    color: Theme.textTertiary
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        // A file-valued effect — a LUT — chooses its file
                        // before any of its numbers mean anything.
                        RowLayout {
                            Layout.fillWidth: true
                            visible: effectBlock.modelData.file !== undefined
                            spacing: Theme.s

                            Text {
                                text: effectBlock.modelData.file
                                    ? effectBlock.modelData.file.name : ""
                                font: Theme.captionFont
                                color: Theme.textTertiary
                                Layout.preferredWidth: 68
                            }

                            Segmented {
                                Layout.fillWidth: true
                                items: inspector.session.availableLuts.map(
                                    function (l) { return l.label })
                                currentIndex: {
                                    if (!effectBlock.modelData.file)
                                        return 0
                                    const current = effectBlock.modelData.file.value
                                    const list = inspector.session.availableLuts
                                    for (var i = 0; i < list.length; i++) {
                                        if (list[i].path === current)
                                            return i
                                    }
                                    return 0
                                }
                                onActivated: (index) =>
                                    inspector.session.setEffectFile(
                                        effectBlock.index,
                                        inspector.session.availableLuts[index].path)
                            }
                        }

                        // parameters
                        Repeater {
                            model: effectBlock.modelData.params

                            ColumnLayout {
                                id: paramRow
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.leftMargin: Theme.l
                                spacing: 2
                                enabled: effectBlock.modelData.on
                                opacity: enabled ? 1 : 0.5

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: paramRow.modelData.name
                                        font: Theme.bodyFont
                                        color: Theme.textSecondary
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: paramRow.modelData.value.toFixed(2)
                                        font: Theme.timecodeFont
                                        color: Theme.text
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.s

                                    Slider {
                                        Layout.fillWidth: true
                                        from: paramRow.modelData.min
                                        to: paramRow.modelData.max
                                        value: paramRow.modelData.value
                                        onMoved: inspector.session.setParam(
                                            effectBlock.index, paramRow.index, value)
                                    }

                                    ToolButton {
                                        implicitWidth: 20
                                        implicitHeight: 20
                                        text: qsTr("Keyframe")
                                        tip: qsTr("Add a keyframe at the playhead")
                                        onClicked: inspector.session.addKeyframe(
                                            effectBlock.index, paramRow.index)
                                        contentItem: Text {
                                            text: paramRow.modelData.keyframes.length > 0
                                                ? "◆" : "◇"
                                            font: Theme.bodyFont
                                            color: paramRow.modelData.keyframes.length > 0
                                                ? Theme.accent : Theme.textTertiary
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }

                                KeyframeStrip {
                                    Layout.fillWidth: true
                                    visible: paramRow.modelData.keyframes.length > 0
                                    keyframes: paramRow.modelData.keyframes
                                    playhead: inspector.session.playhead
                                    onKeyframesEdited: (keyframes) =>
                                        inspector.session.setKeyframes(
                                            effectBlock.index, paramRow.index, keyframes)
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: inspector.session.effects.length === 0
                    text: qsTr("No effects applied. Add one from the Effects panel.")
                    font: Theme.captionFont
                    color: Theme.textTertiary
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
