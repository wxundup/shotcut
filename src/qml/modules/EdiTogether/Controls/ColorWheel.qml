/*
 * Lift/gamma/gain colour wheel.
 *
 * The puck's offset from centre is the colour balance: angle picks hue,
 * distance picks strength. `red`/`green`/`blue` are the resulting offsets
 * in -1..1, which is what a grading node consumes.
 */
import QtQuick
import EdiTogether.Theme

Item {
    id: wheel

    property string label: ""
    property real balanceX: 0.0     // -1..1
    property real balanceY: 0.0     // -1..1
    property real master: 0.0       // -1..1, the slider under the wheel

    readonly property real strength: Math.min(1, Math.hypot(balanceX, balanceY))
    readonly property real hue: {
        const a = Math.atan2(-balanceY, balanceX)
        return ((a / (2 * Math.PI)) + 1) % 1
    }

    signal balanceRequested(real x, real y)
    signal masterRequested(real value)
    signal resetRequested()

    implicitWidth: 118
    // disc + label + master slider + readout, with the column's spacing
    implicitHeight: 118 + 16 + 14 + 16 + Theme.xs * 3

    Column {
        anchors.fill: parent
        spacing: Theme.xs

        Text {
            text: wheel.label
            font: Theme.captionFont
            color: Theme.textSecondary
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Item {
            id: disc
            width: parent.width
            height: width

            Canvas {
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const r = Math.min(width, height) / 2 - 1
                    const cx = width / 2
                    const cy = height / 2

                    // Hue ring painted in wedges; saturation falls off to
                    // neutral at the centre.
                    for (var i = 0; i < 360; i += 2) {
                        const a0 = (i - 1) * Math.PI / 180
                        const a1 = (i + 2) * Math.PI / 180
                        const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
                        grad.addColorStop(0, Theme.dark ? "#4a4a4d" : "#d8d8dc")
                        grad.addColorStop(1, Qt.hsva(i / 360, 0.85, 0.95, 1))
                        ctx.fillStyle = grad
                        ctx.beginPath()
                        ctx.moveTo(cx, cy)
                        ctx.arc(cx, cy, r, a0, a1)
                        ctx.closePath()
                        ctx.fill()
                    }

                    ctx.strokeStyle = Theme.border
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                    ctx.stroke()
                }
            }

            // crosshair at neutral
            Rectangle {
                anchors.centerIn: parent
                width: 7
                height: 1
                color: Qt.rgba(0, 0, 0, 0.4)
            }
            Rectangle {
                anchors.centerIn: parent
                width: 1
                height: 7
                color: Qt.rgba(0, 0, 0, 0.4)
            }

            Rectangle {
                id: puck
                readonly property real radius_: Math.min(disc.width, disc.height) / 2 - 1
                x: disc.width / 2 + wheel.balanceX * radius_ - width / 2
                y: disc.height / 2 + wheel.balanceY * radius_ - height / 2
                width: 11
                height: 11
                radius: width / 2
                color: wheel.strength < 0.02
                    ? Theme.raised
                    : Qt.hsva(wheel.hue, 0.8 * wheel.strength, 0.95, 1)
                border.width: 2
                border.color: Theme.text
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                function apply(mx, my) {
                    const r = Math.min(width, height) / 2 - 1
                    let dx = (mx - width / 2) / r
                    let dy = (my - height / 2) / r
                    const len = Math.hypot(dx, dy)
                    if (len > 1) {          // clamp to the disc
                        dx /= len
                        dy /= len
                    }
                    wheel.balanceRequested(dx, dy)
                }

                onPressed: (mouse) => {
                    if (mouse.button === Qt.RightButton)
                        wheel.resetRequested()
                    else
                        apply(mouse.x, mouse.y)
                }
                onPositionChanged: (mouse) => {
                    if (pressed && !(mouse.buttons & Qt.RightButton))
                        apply(mouse.x, mouse.y)
                }
                onDoubleClicked: wheel.resetRequested()
            }
        }

        // master level for this range
        Item {
            width: parent.width
            height: 14

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 3
                radius: 1.5
                color: Theme.sunken

                Rectangle {
                    x: parent.width / 2
                    width: Math.abs(wheel.master) * parent.width / 2
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                    transformOrigin: Item.Left
                    // negative values grow to the left of centre
                    transform: Scale { xScale: wheel.master < 0 ? -1 : 1 }
                }
            }

            Rectangle {
                x: (wheel.master + 1) / 2 * (parent.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: masterArea.containsMouse || masterArea.pressed ? 10 : 7
                height: width
                radius: width / 2
                color: Theme.text
                border.width: 1
                border.color: Theme.border

                Behavior on width { NumberAnimation { duration: Theme.fast } }
            }

            MouseArea {
                id: masterArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                function apply(mx) {
                    wheel.masterRequested(Math.max(-1, Math.min(1, mx / width * 2 - 1)))
                }
                onPressed: (mouse) => {
                    if (mouse.button === Qt.RightButton)
                        wheel.masterRequested(0)
                    else
                        apply(mouse.x)
                }
                onPositionChanged: (mouse) => {
                    if (pressed && !(mouse.buttons & Qt.RightButton))
                        apply(mouse.x)
                }
            }
        }

        Text {
            text: wheel.master === 0 && wheel.strength < 0.02
                ? qsTr("neutral")
                : wheel.master.toFixed(2)
            font: Theme.timecodeFont
            color: Theme.textTertiary
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
