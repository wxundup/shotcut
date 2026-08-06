/*
 * Color workspace: grading wheels, tone curve, and scopes on the
 * displayed frame.
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EdiTogether.Theme
import EdiTogether.Controls

Rectangle {
    id: colorPanel

    required property var session

    color: Theme.window

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.m
        spacing: Theme.m

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.m

            Text {
                text: colorPanel.session.selectedClip !== ""
                    ? qsTr("Grading %1").arg(colorPanel.session.selectedClip)
                    : qsTr("No clip selected")
                font: Theme.titleFont
                color: colorPanel.session.selectedClip !== ""
                    ? Theme.text : Theme.textTertiary
                Layout.fillWidth: true
            }

            Button {
                text: qsTr("Reset grade")
                enabled: colorPanel.session.selectedClip !== ""
                onClicked: colorPanel.session.resetGrade()
            }
        }

        // wheels
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.l
            enabled: colorPanel.session.selectedClip !== ""
            opacity: enabled ? 1 : 0.4

            Repeater {
                model: [
                    { key: "lift",  label: qsTr("Lift") },
                    { key: "gamma", label: qsTr("Gamma") },
                    { key: "gain",  label: qsTr("Gain") },
                ]

                ColorWheel {
                    id: gradeWheel
                    required property var modelData
                    Layout.preferredHeight: implicitHeight
                    label: modelData.label
                    balanceX: colorPanel.session.grade[modelData.key].x
                    balanceY: colorPanel.session.grade[modelData.key].y
                    master: colorPanel.session.grade[modelData.key].master
                    onBalanceRequested: (x, y) =>
                        colorPanel.session.setGrade(gradeWheel.modelData.key, x, y,
                                                    gradeWheel.master)
                    onMasterRequested: (value) =>
                        colorPanel.session.setGrade(gradeWheel.modelData.key,
                                                    gradeWheel.balanceX,
                                                    gradeWheel.balanceY, value)
                    onResetRequested:
                        colorPanel.session.setGrade(gradeWheel.modelData.key, 0, 0, 0)
                }
            }

            Item { Layout.fillWidth: true }

            ColumnLayout {
                spacing: Theme.xs

                Text {
                    text: qsTr("Curve")
                    font: Theme.captionFont
                    color: Theme.textSecondary
                }

                CurveEditor {
                    Layout.preferredWidth: 152
                    Layout.preferredHeight: 118
                    points: colorPanel.session.toneCurve
                    onCurveEdited: (points) => colorPanel.session.toneCurve = points
                }

                Text {
                    text: qsTr("drag · double-click adds · right-click removes")
                    font: Theme.captionFont
                    color: Theme.textTertiary
                    Layout.preferredWidth: 152
                    wrapMode: Text.WordWrap
                }
            }
        }

        // scopes on the displayed frame
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.m

            Scope {
                Layout.fillWidth: true
                Layout.fillHeight: true
                mode: "parade"
                samples: colorPanel.session.frameSamples
            }

            Scope {
                Layout.fillWidth: true
                Layout.fillHeight: true
                mode: "luma"
                samples: colorPanel.session.frameSamples
            }

            Scope {
                Layout.preferredWidth: height
                Layout.fillHeight: true
                mode: "vector"
                samples: colorPanel.session.frameSamples
            }
        }
    }
}
