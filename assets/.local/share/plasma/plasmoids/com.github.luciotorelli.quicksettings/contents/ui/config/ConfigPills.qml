import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_showWired: showWired.checked
    property alias cfg_showBluetooth: showBluetooth.checked
    property alias cfg_showWifi: showWifi.checked
    property alias cfg_showVpn: showVpn.checked
    property alias cfg_showPower: showPower.checked
    property alias cfg_showFan: showFan.checked
    property alias cfg_showNightLight: showNightLight.checked
    property alias cfg_showAwake: showAwake.checked
    property alias cfg_showAirplane: showAirplane.checked
    property alias cfg_showKdeConnect: showKdeConnect.checked
    property alias cfg_bodyToggles: bodyToggles.checked

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: showWired
            Kirigami.FormData.label: i18n("Which pills to show:")
            text: i18n("Wired")
        }
        QQC2.CheckBox {
            id: showBluetooth
            text: i18n("Bluetooth")
        }
        QQC2.CheckBox {
            id: showWifi
            text: i18n("Wi-Fi")
        }
        QQC2.CheckBox {
            id: showVpn
            text: i18n("VPN")
        }
        QQC2.CheckBox {
            id: showPower
            text: i18n("Power Mode")
        }
        QQC2.CheckBox {
            id: showFan
            text: i18n("Fan Curve")
        }
        QQC2.Label {
            leftPadding: showFan.indicator.width + showFan.spacing
            text: i18n("Only appears on a Framework laptop with fw-fanctrl installed.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
        QQC2.CheckBox {
            id: showNightLight
            text: i18n("Night Light")
        }
        QQC2.CheckBox {
            id: showAwake
            text: i18n("Keep Awake")
        }
        QQC2.CheckBox {
            id: showAirplane
            text: i18n("Airplane Mode")
        }
        QQC2.CheckBox {
            id: showKdeConnect
            text: i18n("KDE Connect")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: bodyToggles
            Kirigami.FormData.label: i18n("What clicking does:")
            text: i18n("Clicking a pill toggles it, the arrow opens its panel")
        }
        QQC2.Label {
            leftPadding: bodyToggles.indicator.width + bodyToggles.spacing
            text: i18n("This is how GNOME's Quick Settings behave. Turn it off to swap the two halves round.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }
    }
}
