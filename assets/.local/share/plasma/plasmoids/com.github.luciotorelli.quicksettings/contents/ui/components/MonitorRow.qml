import QtQuick
import QtQuick.Layouts

// One display's controls on a single line: brightness, and - for a DDC/CI
// monitor ddcutil can reach - contrast beside it.
RowLayout {
    id: row

    required property Style style
    required property var display       // a Brightness display object
    property var monitor: null          // the matching Contrast entry, if any

    signal contrastCommitted(real fraction)

    spacing: 8

    IconButton {
        style: row.style
        iconName: row.display.isInternal ? "display-brightness-symbolic" : "video-display-symbolic"
        fallbackIconName: row.display.isInternal ? "brightness-high" : "monitor"
        iconSize: 18
        tooltip: row.display.label !== "" ? i18n("Brightness: %1", row.display.label) : i18n("Screen brightness")
        hoverEnabled: false
    }

    QsSlider {
        id: brightnessSlider
        style: row.style
        Layout.fillWidth: true
        Accessible.name: i18n("Brightness")
        onMoved: row.display.setValue(value)

        Binding on value {
            value: row.display.value
            when: !brightnessSlider.pressed
            restoreMode: Binding.RestoreNone
        }
    }

    IconButton {
        visible: row.monitor !== null
        style: row.style
        iconName: "contrast"
        fallbackIconName: "preferences-color-symbolic"
        iconSize: 18
        tooltip: i18n("Contrast: %1", row.display.label)
        hoverEnabled: false
    }

    QsSlider {
        id: contrastSlider
        visible: row.monitor !== null
        style: row.style
        Layout.fillWidth: true
        Accessible.name: i18n("Contrast")

        // Each write is a ddcutil process and a slow I2C transaction, so
        // commit when the drag ends (or the wheel stops), not on every move.
        onMoved: commit.restart()
        onPressedChanged: {
            if (!pressed) {
                commit.stop();
                row.contrastCommitted(value);
            }
        }

        Binding on value {
            value: row.monitor ? row.monitor.value / row.monitor.max : 0
            when: !contrastSlider.pressed && !commit.running
            restoreMode: Binding.RestoreNone
        }

        Timer {
            id: commit
            interval: 400
            onTriggered: {
                if (!contrastSlider.pressed) {
                    row.contrastCommitted(contrastSlider.value);
                }
            }
        }
    }
}
