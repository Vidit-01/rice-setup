import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami

// A slider drawn to match the pills: thick rounded track, accent fill, round
// handle. Plasma's own slider is themed from SVGs and cannot take the accent.
T.Slider {
    id: control

    required property Style style

    readonly property real trackHeight: Math.round(Kirigami.Units.gridUnit * 0.4)
    readonly property real handleSize: Math.round(Kirigami.Units.gridUnit * 0.95)

    implicitWidth: Kirigami.Units.gridUnit * 8
    implicitHeight: handleSize + 4

    from: 0
    to: 1
    stepSize: 0.05      // keyboard and wheel; dragging stays continuous
    snapMode: T.Slider.NoSnap
    wheelEnabled: true
    live: true

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        width: control.availableWidth
        height: control.trackHeight
        radius: height / 2
        color: control.style.track

        Rectangle {
            width: control.handle.x - control.leftPadding + control.handle.width / 2
            height: parent.height
            radius: height / 2
            color: control.enabled ? control.style.accent : control.style.textMuted
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + (control.availableHeight - height) / 2
        width: control.handleSize
        height: control.handleSize
        radius: width / 2
        color: "#ffffff"
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? control.style.accent : Qt.rgba(0, 0, 0, 0.18)
        scale: control.pressed ? 1.12 : 1
        Behavior on scale {
            NumberAnimation { duration: 80 }
        }
    }
}
