import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// One row inside an expansion panel: icon, name, and a trailing action.
RowLayout {
    id: row

    required property Style style

    property string iconName
    property string fallbackIconName
    property string label
    property string actionText
    property bool current: false        // the active choice: shown, not clickable
    property bool busy: false

    signal activated()

    spacing: 10
    Layout.fillWidth: true

    Kirigami.Icon {
        Layout.preferredWidth: 16
        Layout.preferredHeight: 16
        source: row.iconName
        fallback: row.fallbackIconName
        isMask: true
        color: row.style.text
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        text: row.label
        font.bold: row.current
        elide: Text.ElideRight
        textFormat: Text.PlainText
    }

    // Built on demand: a BusyIndicator is an SVG and an animator, and one in
    // every row of every list made the rows slow to create.
    Loader {
        active: row.busy
        visible: active
        sourceComponent: PlasmaComponents.BusyIndicator {
            implicitWidth: 18
            implicitHeight: 18
            running: true
        }
    }

    T.AbstractButton {
        id: action
        visible: row.actionText !== "" && !row.busy
        enabled: !row.current
        implicitWidth: actionLabel.implicitWidth + 16
        implicitHeight: actionLabel.implicitHeight + 6

        Accessible.name: row.actionText + " " + row.label
        Accessible.role: Accessible.Button
        onClicked: row.activated()

        contentItem: PlasmaComponents.Label {
            id: actionLabel
            text: row.actionText
            color: row.current ? row.style.textMuted : row.style.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
        }

        background: Rectangle {
            radius: 10
            color: action.pressed ? row.style.tilePressed
                 : action.hovered && action.enabled ? row.style.tileHover : "transparent"
            border.width: action.visualFocus ? 2 : 0
            border.color: row.style.accent
        }
    }
}
