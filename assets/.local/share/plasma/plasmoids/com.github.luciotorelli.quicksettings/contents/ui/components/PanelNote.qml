import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// A dim one-line message for an empty panel list, or - with `heading` set -
// the small uppercase label that splits a panel into groups.
PlasmaComponents.Label {
    required property Style style
    property bool heading: false

    Layout.fillWidth: true
    Layout.topMargin: heading ? 6 : 2
    Layout.bottomMargin: heading ? 1 : 2
    color: style.textMuted
    font.bold: heading
    font.capitalization: heading ? Font.AllUppercase : Font.MixedCase
    font.pointSize: heading ? Kirigami.Theme.smallFont.pointSize * 0.9 : Kirigami.Theme.defaultFont.pointSize
    elide: Text.ElideRight
    textFormat: Text.PlainText
}
