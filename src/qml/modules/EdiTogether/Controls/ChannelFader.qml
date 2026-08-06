/*
 * Mixer channel strip: vertical fader, meter, pan, and mute/solo.
 */
import QtQuick
import EdiTogether.Theme

Rectangle {
    id: strip

    property string name: ""
    property real gain: 0.8        // 0..1 of the fader travel
    property real pan: 0.0         // -1 left, +1 right
    property real level: 0.0
    property real peak: 0.0
    property bool muted: false
    property bool soloed: false

    signal gainRequested(real value)
    signal panRequested(real value)
    signal muteToggled()
    signal soloToggled()

    // Fader travel maps to dB the way a console does: unity at 0.8,
    // finer resolution near unity than at the bottom.
    readonly property real decibels: gain <= 0.001
        ? -Infinity
        : 20 * Math.log((gain / 0.8)) / Math.LN10 * 1.0

    implicitWidth: 62
    implicitHeight: 220
    radius: Theme.radiusControl
    color: Theme.raised
    border.width: 1
    border.color: Theme.separator

    Column {
        anchors.fill: parent
        anchors.margins: Theme.xs
        spacing: Theme.xs

        Text {
            text: strip.name
            font: Theme.captionFont
            color: strip.muted ? Theme.textTertiary : Theme.text
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        // pan
        Item {
            width: parent.width
            height: 12

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 3
                radius: 1.5
                color: Theme.sunken
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width / 2 - 1
                width: 2
                height: 7
                color: Theme.textTertiary
            }

            Rectangle {
                x: (strip.pan + 1) / 2 * (parent.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                radius: 3.5
                color: Theme.text
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: (mouse) => {
                    if (mouse.button === Qt.RightButton)
                        strip.panRequested(0)
                    else
                        strip.panRequested(Math.max(-1, Math.min(1, mouse.x / width * 2 - 1)))
                }
                onPositionChanged: (mouse) => {
                    if (pressed && !(mouse.buttons & Qt.RightButton))
                        strip.panRequested(Math.max(-1, Math.min(1, mouse.x / width * 2 - 1)))
                }
            }
        }

        // fader + meter
        Item {
            width: parent.width
            height: parent.height - 92

            Rectangle {
                id: track
                x: 12
                width: 4
                height: parent.height
                radius: 2
                color: Theme.sunken

                // unity mark
                Rectangle {
                    y: parent.height * (1 - 0.8)
                    width: 10
                    x: -3
                    height: 1
                    color: Theme.textTertiary
                }
            }

            Rectangle {
                x: track.x - 7
                y: (1 - strip.gain) * (parent.height - height)
                width: 18
                height: 12
                radius: 2
                color: faderArea.pressed || faderArea.containsMouse
                    ? Qt.lighter(Theme.overlay, 1.2) : Theme.overlay
                border.width: 1
                border.color: Theme.border

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 6
                    height: 1
                    color: strip.muted ? Theme.textTertiary : Theme.accent
                }
            }

            MouseArea {
                id: faderArea
                x: 0
                width: 30
                height: parent.height
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: (mouse) => {
                    if (mouse.button === Qt.RightButton)
                        strip.gainRequested(0.8)   // back to unity
                    else
                        strip.gainRequested(Math.max(0, Math.min(1, 1 - mouse.y / height)))
                }
                onPositionChanged: (mouse) => {
                    if (pressed && !(mouse.buttons & Qt.RightButton))
                        strip.gainRequested(Math.max(0, Math.min(1, 1 - mouse.y / height)))
                }
            }

            LevelMeter {
                x: 36
                width: 6
                height: parent.height
                vertical: true
                level: strip.muted ? 0 : strip.level
                peak: strip.muted ? 0 : strip.peak
            }
        }

        Text {
            text: strip.gain <= 0.001 ? "-∞"
                : (strip.decibels >= 0 ? "+" : "") + strip.decibels.toFixed(1)
            font: Theme.captionFont
            color: Theme.textTertiary
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
        }

        Row {
            spacing: Theme.xxs
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                width: 20; height: 16; radius: 2
                color: strip.muted ? Theme.warning : "transparent"
                border.width: strip.muted ? 0 : 1
                border.color: Theme.border
                Text {
                    anchors.centerIn: parent
                    text: "M"
                    font: Theme.captionFont
                    color: strip.muted ? Theme.textOnAccent : Theme.textTertiary
                }
                MouseArea { anchors.fill: parent; onClicked: strip.muteToggled() }
            }

            Rectangle {
                width: 20; height: 16; radius: 2
                color: strip.soloed ? Theme.accent : "transparent"
                border.width: strip.soloed ? 0 : 1
                border.color: Theme.border
                Text {
                    anchors.centerIn: parent
                    text: "S"
                    font: Theme.captionFont
                    color: strip.soloed ? Theme.textOnAccent : Theme.textTertiary
                }
                MouseArea { anchors.fill: parent; onClicked: strip.soloToggled() }
            }
        }
    }
}
