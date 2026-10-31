import QtQuick
import "../components"

PanelBody {
    id: body

    title: i18n("KDE Connect")
    iconName: "kdeconnect"
    fallbackIconName: "phone"
    footerText: i18n("Open KDE Connect")

    function footerAction() {
        app.kdeConnect.openApp();
    }

    Repeater {
        model: body.app.kdeConnect.devices
        delegate: PanelRow {
            required property var modelData
            style: body.style
            iconName: "kdeconnect"
            fallbackIconName: "phone"
            label: modelData.name + " · " + (modelData.reachable ? i18n("Connected") : i18n("Not connected"))
            actionText: modelData.reachable ? i18n("Ring") : ""
            busy: body.app.kdeConnect.loading
            onActivated: body.app.kdeConnect.ring(modelData)
        }
    }

    Repeater {
        model: body.app.kdeConnect.wirelessDevices
        delegate: PanelRow {
            required property var modelData
            style: body.style
            iconName: "phone"
            label: modelData.name + " · " + modelData.state
            actionText: modelData.state === "device" && body.app.kdeConnect.scrcpyAvailable
                ? i18n("View") : ""
            onActivated: body.app.kdeConnect.mirror(modelData.serial)
        }
    }

    PanelNote {
        style: body.style
        visible: !body.app.kdeConnect.adbAvailable || !body.app.kdeConnect.scrcpyAvailable
        text: !body.app.kdeConnect.adbAvailable ? i18n("Install Android platform-tools (adb) to connect over Wi-Fi.")
            : i18n("Install scrcpy to view and control your phone.")
    }
    PanelNote {
        style: body.style
        visible: body.app.kdeConnect.adbAvailable && body.app.kdeConnect.scrcpyAvailable
            && body.app.kdeConnect.wirelessDevices.length === 0
        text: i18n("Check adb devices -l: the phone should appear with state device.")
    }

    PanelNote {
        style: body.style
        visible: body.app.kdeConnect.devices.length === 0
        text: body.app.kdeConnect.message || body.app.kdeConnect.summary
    }
    PanelNote {
        style: body.style
        visible: body.app.kdeConnect.message !== "" && body.app.kdeConnect.devices.length > 0
        text: body.app.kdeConnect.message
    }
}
