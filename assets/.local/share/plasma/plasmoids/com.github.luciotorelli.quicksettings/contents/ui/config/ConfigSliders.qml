import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_showVolume: showVolume.checked
    property alias cfg_showBrightness: showBrightness.checked
    property alias cfg_showMonitorContrast: showMonitorContrast.checked
    property alias cfg_panelShowBatteryIcon: panelShowBatteryIcon.checked
    property alias cfg_panelShowPercentage: panelShowPercentage.checked

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: showVolume
            Kirigami.FormData.label: i18n("Sliders in the popup:")
            text: i18n("Volume")
        }
        QQC2.CheckBox {
            id: showBrightness
            text: i18n("Screen brightness")
        }
        QQC2.Label {
            leftPadding: showBrightness.indicator.width + showBrightness.spacing
            text: i18n("One slider per display Plasma can dim: the laptop panel, and monitors that speak DDC/CI.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }
        QQC2.CheckBox {
            id: showMonitorContrast
            enabled: showBrightness.checked
            text: i18n("External monitor contrast")
        }
        QQC2.Label {
            leftPadding: showMonitorContrast.indicator.width + showMonitorContrast.spacing
            text: i18n("Needs ddcutil installed and a monitor that speaks DDC/CI. Laptop panels do not.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: panelShowBatteryIcon
            Kirigami.FormData.label: i18n("The button in the panel:")
            text: i18n("Show the battery icon")
        }
        QQC2.Label {
            leftPadding: panelShowBatteryIcon.indicator.width + panelShowBatteryIcon.spacing
            text: i18n("Turn off to fall back to a settings cog. Machines with no battery always show the cog.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }
        QQC2.CheckBox {
            id: panelShowPercentage
            text: i18n("Show the battery percentage")
        }
    }
}
