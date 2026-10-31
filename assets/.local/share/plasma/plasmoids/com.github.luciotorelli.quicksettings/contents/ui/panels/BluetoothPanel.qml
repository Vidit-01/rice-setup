import QtQuick
import "../components"

// Paired devices, with connect and disconnect.
PanelBody {
    id: body

    title: i18n("Bluetooth")
    iconName: "bluetooth-symbolic"
    fallbackIconName: "network-bluetooth"
    footerText: i18n("Bluetooth Settings")
    settingsModule: "kcm_bluetooth"

    Repeater {
        id: list
        model: body.app.bluetooth.pairedDevices
        delegate: PanelRow {
            id: row

            required property var model
            readonly property var device: model.Device
            property bool pending: false

            style: body.style
            iconName: "bluetooth-symbolic"
            fallbackIconName: "network-bluetooth"
            label: device ? device.name : ""
            busy: pending
            actionText: device && device.connected ? i18n("Disconnect") : i18n("Connect")
            onActivated: {
                pending = true;
                body.app.bluetooth.setConnected(device, !device.connected);
                pendingTimeout.restart();
            }

            // The call has no completion signal reachable from here; the
            // device's own state change is what ends the wait, with a timeout
            // for a connection attempt that simply fails.
            Connections {
                target: row.device
                function onConnectedChanged() {
                    row.pending = false;
                }
            }
            Timer {
                id: pendingTimeout
                interval: 12000
                onTriggered: row.pending = false
            }
        }
    }

    PanelNote {
        style: body.style
        visible: list.count === 0
        text: !body.app.bluetooth.available ? i18n("No Bluetooth adapter")
            : !body.app.bluetooth.powered ? i18n("Bluetooth is switched off")
            : i18n("No paired devices")
    }
}
