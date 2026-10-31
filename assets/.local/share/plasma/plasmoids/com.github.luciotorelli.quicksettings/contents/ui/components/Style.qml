import QtQuick
import org.kde.plasma.plasmoid

// Colours and metrics shared by everything in the popup.
//
// The two theme colours are handed in rather than read here. Kirigami.Theme
// only resolves for an item that is actually shown: read from an invisible
// helper, inside plasmashell it yields the disabled text colour and an
// invalid (black) highlight. So the popup binds them from itself.
QtObject {
    id: style

    // Text colour of the popup this style is for (the Plasma style's).
    required property color text
    // The desktop's accent colour. Deliberately the system one, not the Plasma
    // style's highlight: a style with its own colour table (ChromeOS, say)
    // keeps its stock blue whatever accent is chosen in System Settings.
    required property color systemAccent

    readonly property var config: Plasmoid.configuration

    // Tile washes are the text colour at low alpha rather than white, so they
    // read on a light theme as well as a dark one.
    readonly property color textMuted: Qt.alpha(text, 0.55)
    readonly property color tileIdle: Qt.alpha(text, 0.07)
    readonly property color tileHover: Qt.alpha(text, 0.13)
    readonly property color tilePressed: Qt.alpha(text, 0.18)
    readonly property color track: Qt.alpha(text, 0.12)
    readonly property color rule: Qt.alpha(text, 0.12)
    readonly property color panel: Qt.alpha(text, 0.06)

    readonly property color accent: config.useThemeAccent ? systemAccent : config.customAccent

    // White on a bright orange is glaring, dark text on a deep blue is
    // unreadable, so unless told otherwise this decides from the accent's own
    // perceived brightness (Rec. 601 luma).
    readonly property bool darkAccentText: {
        if (config.textContrast === "dark") {
            return true;
        }
        if (config.textContrast === "light") {
            return false;
        }
        return 0.299 * accent.r + 0.587 * accent.g + 0.114 * accent.b > 0.5;
    }
    readonly property color accentText: darkAccentText ? Qt.rgba(0, 0, 0, 0.85) : "#ffffff"
    readonly property color accentTextMuted: darkAccentText ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(1, 1, 1, 0.8)

    readonly property int pillRadius: config.pillRadius
    readonly property int pillPadding: config.pillPadding
    readonly property int pillIconSize: config.pillIconSize
    readonly property int pillSpacing: config.pillSpacing

    readonly property int hoverDuration: 150
    readonly property int panelDuration: config.animatePanels ? config.animationDuration : 0
}
