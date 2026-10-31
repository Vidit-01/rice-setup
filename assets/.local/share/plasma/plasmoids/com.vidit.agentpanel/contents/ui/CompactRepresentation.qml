import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

Item {
    id: compact
    required property var app
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property var featured: app.agents.featured

    implicitWidth: vertical ? 0 : Math.max(Kirigami.Units.gridUnit * 9,
        Math.min(Kirigami.Units.gridUnit * 22, textColumn.implicitWidth + Kirigami.Units.gridUnit * 5))
    Layout.minimumWidth: vertical ? 0 : Kirigami.Units.gridUnit * 7
    Layout.preferredWidth: implicitWidth
    Layout.maximumWidth: vertical ? 0 : Kirigami.Units.gridUnit * 22
    Layout.minimumHeight: vertical ? 0 : Kirigami.Units.iconSizes.medium

    MouseArea {
        anchors.fill: parent
        onClicked: compact.app.expanded = !compact.app.expanded

        RowLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Image {
                visible: compact.featured && ["openai", "claude", "cursor", "gemini"].indexOf(compact.featured.provider) >= 0
                source: visible ? Qt.resolvedUrl("../images/" + compact.featured.provider + ".svg") : ""
                sourceSize.width: 40
                sourceSize.height: 40
                fillMode: Image.PreserveAspectFit
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }

            Kirigami.Icon {
                visible: !compact.featured || ["openai", "claude", "cursor", "gemini"].indexOf(compact.featured.provider) < 0
                source: compact.featured && compact.featured.displayStatus === "Running" ? "system-run-symbolic" : "code-context"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                color: compact.app.agents.attention > 0 ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
            }

            ColumnLayout {
                id: textColumn
                Layout.fillWidth: true
                spacing: 0
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: compact.featured
                        ? compact.featured.displayStatus + " · " + compact.featured.project
                        : "No recent agent activity"
                    font.bold: true
                    elide: Text.ElideRight
                }
                PlasmaComponents.Label {
                    visible: compact.featured !== null
                    Layout.fillWidth: true
                    text: compact.featured ? compact.featured.summary : ""
                    opacity: 0.72
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            PlasmaComponents.Label {
                visible: compact.app.agents.running.length + compact.app.agents.waiting.length + compact.app.agents.attention > 0
                text: compact.app.agents.running.length + compact.app.agents.waiting.length + compact.app.agents.attention
                color: compact.app.agents.attention > 0 ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
                font.bold: true
            }
        }
    }
}
