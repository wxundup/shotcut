/*
 * Channel processing: parametric EQ and dynamics for one track.
 *
 * The values here are the ones the renderer applies — the EQ curve is the
 * biquad response that will be encoded, and the dynamics figures map onto
 * the compressor and limiter in the export graph.
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EdiTogether.Theme
import EdiTogether.Controls

Rectangle {
    id: rack

    required property var session
    required property int trackIndex

    readonly property var track: session.tracks[trackIndex]
    readonly property var dsp: track && track.dsp ? track.dsp : null

    color: Theme.panel
    radius: Theme.radiusCard
    border.width: 1
    border.color: Theme.separator

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.m
        spacing: Theme.s

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: rack.track ? qsTr("%1 processing").arg(rack.track.name) : ""
                font: Theme.titleFont
                color: Theme.text
                Layout.fillWidth: true
            }

            Text {
                text: rack.session.playing ? "" : qsTr("stopped")
                font: Theme.captionFont
                color: Theme.textTertiary
            }
        }

        // ---- EQ ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s

            Rectangle {
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                radius: 3
                color: rack.dsp && rack.dsp.eqOn ? Theme.accent : "transparent"
                border.width: rack.dsp && rack.dsp.eqOn ? 0 : 1
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    font: Theme.captionFont
                    color: Theme.textOnAccent
                    visible: rack.dsp && rack.dsp.eqOn
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: rack.session.setDsp(rack.trackIndex, "eqOn",
                                                   !rack.dsp.eqOn)
                }
            }

            Text {
                text: qsTr("Equaliser")
                font: Theme.bodyFont
                color: Theme.textSecondary
                Layout.fillWidth: true
            }
        }

        EqCurve {
            Layout.fillWidth: true
            Layout.preferredHeight: 110
            bands: rack.dsp ? rack.dsp.bands : []
            enabled: rack.dsp && rack.dsp.eqOn
            opacity: enabled ? 1 : 0.4
            onBandMoved: (index, freq, gain) =>
                rack.session.setEqBand(rack.trackIndex, index, freq, gain)
        }

        // ---- dynamics ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s

            Rectangle {
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                radius: 3
                color: rack.dsp && rack.dsp.compOn ? Theme.accent : "transparent"
                border.width: rack.dsp && rack.dsp.compOn ? 0 : 1
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    font: Theme.captionFont
                    color: Theme.textOnAccent
                    visible: rack.dsp && rack.dsp.compOn
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: rack.session.setDsp(rack.trackIndex, "compOn",
                                                   !rack.dsp.compOn)
                }
            }

            Text {
                text: qsTr("Compressor")
                font: Theme.bodyFont
                color: Theme.textSecondary
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.m
            enabled: rack.dsp && rack.dsp.compOn
            opacity: enabled ? 1 : 0.4

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.xs

                Repeater {
                    model: rack.dsp ? [
                        { key: "threshold", label: qsTr("Threshold"), unit: " dB",
                          from: -48, to: 0, value: rack.dsp.threshold },
                        { key: "ratio", label: qsTr("Ratio"), unit: ":1",
                          from: 1, to: 20, value: rack.dsp.ratio },
                        { key: "attack", label: qsTr("Attack"), unit: " ms",
                          from: 1, to: 200, value: rack.dsp.attack },
                        { key: "release", label: qsTr("Release"), unit: " ms",
                          from: 20, to: 1000, value: rack.dsp.release },
                    ] : []

                    RowLayout {
                        id: control
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.s

                        Text {
                            text: control.modelData.label
                            font: Theme.captionFont
                            color: Theme.textTertiary
                            Layout.preferredWidth: 68
                        }

                        Slider {
                            Layout.fillWidth: true
                            from: control.modelData.from
                            to: control.modelData.to
                            value: control.modelData.value
                            onMoved: rack.session.setDsp(rack.trackIndex,
                                                         control.modelData.key, value)
                        }

                        Text {
                            text: control.modelData.value.toFixed(
                                control.modelData.key === "ratio" ? 1 : 0)
                                + control.modelData.unit
                            font: Theme.timecodeFont
                            color: Theme.text
                            Layout.preferredWidth: 60
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            ColumnLayout {
                spacing: Theme.xxs
                Layout.alignment: Qt.AlignTop

                Text {
                    text: qsTr("GR")
                    font: Theme.captionFont
                    color: Theme.textTertiary
                    Layout.alignment: Qt.AlignHCenter
                }

                GainReduction {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 74
                    reduction: rack.dsp ? rack.dsp.reduction : 0
                }
            }
        }

        // ---- limiter ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s

            Rectangle {
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                radius: 3
                color: rack.dsp && rack.dsp.limitOn ? Theme.accent : "transparent"
                border.width: rack.dsp && rack.dsp.limitOn ? 0 : 1
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    font: Theme.captionFont
                    color: Theme.textOnAccent
                    visible: rack.dsp && rack.dsp.limitOn
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: rack.session.setDsp(rack.trackIndex, "limitOn",
                                                   !rack.dsp.limitOn)
                }
            }

            Text {
                text: qsTr("Limiter")
                font: Theme.bodyFont
                color: Theme.textSecondary
            }

            Item { Layout.fillWidth: true }

            Text {
                text: qsTr("ceiling")
                font: Theme.captionFont
                color: Theme.textTertiary
            }

            Slider {
                Layout.preferredWidth: 110
                from: -12
                to: 0
                value: rack.dsp ? rack.dsp.ceiling : 0
                enabled: rack.dsp && rack.dsp.limitOn
                onMoved: rack.session.setDsp(rack.trackIndex, "ceiling", value)
            }

            Text {
                text: (rack.dsp ? rack.dsp.ceiling.toFixed(1) : "0.0") + " dB"
                font: Theme.timecodeFont
                color: Theme.text
                Layout.preferredWidth: 56
                horizontalAlignment: Text.AlignRight
            }
        }

        Item { Layout.fillHeight: true }
    }
}
