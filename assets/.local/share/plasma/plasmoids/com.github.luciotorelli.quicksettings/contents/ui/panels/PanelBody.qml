import QtQuick
import QtQuick.Layouts
import "../components"

// What every expansion panel provides: the rows (its children), plus the
// header and footer details ExpansionPanel reads off it.
ColumnLayout {
    id: body

    required property var app
    required property Style style

    property string title
    property string iconName
    property string fallbackIconName
    property string footerText
    property string settingsModule      // KCM the footer opens
    property bool busy: false

    // Called once the panel has finished opening.
    function opened() {
    }

    function footerAction() {
        if (settingsModule !== "") {
            app.openSettings(settingsModule);
        }
    }

    spacing: 1
}
