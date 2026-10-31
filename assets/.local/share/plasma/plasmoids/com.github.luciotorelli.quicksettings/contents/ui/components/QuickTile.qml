import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// A GNOME-style quick settings pill.
//
// Two segments in one rounded tile: the body and, where there is a panel to
// open, a chevron with its own wash behind a hairline divider. Which half
// toggles and which half opens the panel is the `bodyToggles` setting.
Item {
    id: tile

    required property Style style

    property string title
    property string subtitle
    property string iconName
    property string fallbackIconName
    property bool active: false

    // A pill without a toggle is a multi-choice one (Power Mode, Fan Curve):
    // there is nothing binary to flip, so both halves open the panel.
    property bool toggleable: true
    property bool expandable: false
    property bool expanded: false       // its panel is open: the chevron points down
    property bool bodyToggles: true

    signal toggled()
    signal expandRequested()

    readonly property color foreground: active ? style.accentText : style.text
    readonly property color foregroundMuted: active ? style.accentTextMuted : style.textMuted

    function _bodyAction() {
        if (toggleable && (bodyToggles || !expandable)) {
            toggled();
        } else if (expandable) {
            expandRequested();
        }
    }

    function _chevronAction() {
        if (toggleable && !bodyToggles) {
            toggled();
        } else {
            expandRequested();
        }
    }

    // Always room for two lines, so a pill does not change height when its
    // subtitle arrives and every row of the grid is the same height.
    implicitHeight: 2 * style.pillPadding + titleMetrics.height + subtitleMetrics.height
    implicitWidth: 160
    Layout.fillWidth: true

    FontMetrics {
        id: titleMetrics
        font: titleLabel.font
    }
    FontMetrics {
        id: subtitleMetrics
        font: subtitleLabel.font
    }

    HoverHandler {
        id: hover
    }

    Rectangle {
        anchors.fill: parent
        radius: tile.style.pillRadius
        color: tile.active ? tile.style.accent
             : body.pressed ? tile.style.tilePressed
             : hover.hovered ? tile.style.tileHover : tile.style.tileIdle
        Behavior on color {
            ColorAnimation { duration: tile.style.hoverDuration }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        T.AbstractButton {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            leftPadding: 14
            rightPadding: tile.expandable ? 8 : 14

            Accessible.name: tile.subtitle ? tile.title + ", " + tile.subtitle : tile.title
            Accessible.role: tile.toggleable ? Accessible.CheckBox : Accessible.Button
            Accessible.checkable: tile.toggleable
            Accessible.checked: tile.active

            onClicked: tile._bodyAction()
            Keys.onRightPressed: if (tile.expandable) tile.expandRequested()

            contentItem: RowLayout {
                spacing: 10

                Kirigami.Icon {
                    Layout.preferredWidth: tile.style.pillIconSize
                    Layout.preferredHeight: tile.style.pillIconSize
                    Layout.alignment: Qt.AlignVCenter
                    source: tile.iconName
                    fallback: tile.fallbackIconName
                    isMask: true
                    color: tile.foreground
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    PlasmaComponents.Label {
                        id: titleLabel
                        Layout.fillWidth: true
                        text: tile.title
                        font.bold: true
                        color: tile.foreground
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    PlasmaComponents.Label {
                        id: subtitleLabel
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: tile.subtitle
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        color: tile.foregroundMuted
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                }
            }

            background: Rectangle {
                radius: tile.style.pillRadius
                color: "transparent"
                border.width: body.visualFocus ? 2 : 0
                border.color: tile.active ? tile.style.accentText : tile.style.accent
            }
        }

        T.AbstractButton {
            id: chevron
            visible: tile.expandable
            Layout.fillHeight: true
            implicitWidth: 40

            Accessible.name: i18nc("@action:button %1 is a quick setting such as Wi-Fi", "Open %1 panel", tile.title)
            Accessible.role: Accessible.Button

            onClicked: tile._chevronAction()

            contentItem: Item {
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    source: "go-next-symbolic"
                    isMask: true
                    color: tile.foreground
                    rotation: tile.expanded ? 90 : 0
                    Behavior on rotation {
                        NumberAnimation { duration: tile.style.panelDuration; easing.type: Easing.OutCubic }
                    }
                }
            }

            // Darken over the accent, lighten over the idle grey: either way
            // the segment separates from the body without inventing a colour.
            background: Rectangle {
                topLeftRadius: 0
                bottomLeftRadius: 0
                topRightRadius: tile.style.pillRadius
                bottomRightRadius: tile.style.pillRadius
                color: tile.active ? Qt.rgba(0, 0, 0, chevron.hovered ? 0.28 : 0.20)
                                   : Qt.alpha(tile.style.text, chevron.hovered ? 0.14 : 0.07)
                border.width: chevron.visualFocus ? 2 : 0
                border.color: tile.active ? tile.style.accentText : tile.style.accent

                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 1
                    color: !tile.active ? Qt.alpha(tile.style.text, 0.14)
                         : tile.style.darkAccentText ? Qt.rgba(0, 0, 0, 0.28) : Qt.rgba(1, 1, 1, 0.30)
                }
            }
        }
    }
}
