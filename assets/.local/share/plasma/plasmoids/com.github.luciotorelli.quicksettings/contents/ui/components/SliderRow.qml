import QtQuick
import QtQuick.Layouts

// One full-width slider with a leading icon and, optionally, a trailing
// chevron that opens a panel.
RowLayout {
    id: row

    required property Style style

    property string iconName
    property string fallbackIconName
    property string label               // tooltip and accessible name
    property real value: 0
    property bool iconClickable: false
    property bool expandable: false
    property bool expanded: false

    signal moved(real value)
    signal iconClicked()
    signal expandRequested()

    spacing: 8

    IconButton {
        style: row.style
        iconName: row.iconName
        fallbackIconName: row.fallbackIconName
        iconSize: 18
        tooltip: row.label
        // Stays a button either way so every row's icon sits at the same
        // offset; it just does nothing where there is nothing to toggle.
        hoverEnabled: row.iconClickable
        onClicked: if (row.iconClickable) row.iconClicked()
    }

    QsSlider {
        id: slider
        style: row.style
        Layout.fillWidth: true
        Accessible.name: row.label
        onMoved: row.moved(value)

        // Follow the system, except while being dragged: a late echo of an
        // earlier position would otherwise yank the handle back mid-drag.
        Binding on value {
            value: row.value
            when: !slider.pressed
            restoreMode: Binding.RestoreNone
        }
    }

    IconButton {
        visible: row.expandable
        style: row.style
        iconName: "go-next-symbolic"
        iconSize: 14
        iconRotation: row.expanded ? 90 : 0
        tooltip: i18nc("@action:button %1 is a slider such as Volume", "Open %1 panel", row.label)
        onClicked: row.expandRequested()
    }
}
