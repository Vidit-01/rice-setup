import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// An icon-only button with a hover wash. `filled` gives it the resting
// background the round header buttons have; without it the wash only shows
// on hover, as for the chevrons and the slider icons.
T.AbstractButton {
    id: button

    required property Style style

    property string iconName
    property string fallbackIconName
    property int iconSize: 16
    property bool filled: false
    property real iconRotation: 0
    property string tooltip

    implicitWidth: filled ? 32 : iconSize + 10
    implicitHeight: implicitWidth

    Accessible.name: tooltip
    Accessible.role: Accessible.Button

    PlasmaComponents.ToolTip.text: tooltip
    PlasmaComponents.ToolTip.visible: hovered && tooltip !== ""
    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

    contentItem: Item {
        Kirigami.Icon {
            anchors.centerIn: parent
            width: button.iconSize
            height: button.iconSize
            source: button.iconName
            fallback: button.fallbackIconName
            isMask: true
            color: button.style.text
            opacity: button.enabled ? 1 : 0.4
            rotation: button.iconRotation
            Behavior on rotation {
                NumberAnimation { duration: button.style.panelDuration; easing.type: Easing.OutCubic }
            }
        }
    }

    background: Rectangle {
        radius: width / 2
        color: button.pressed ? button.style.tilePressed
             : button.hovered ? button.style.tileHover
             : button.filled ? button.style.tileIdle : "transparent"
        border.width: button.visualFocus ? 2 : 0
        border.color: button.style.accent
        Behavior on color {
            ColorAnimation { duration: button.style.hoverDuration }
        }
    }
}
