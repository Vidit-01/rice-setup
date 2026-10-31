import QtQuick
import org.kde.bluezqt as BluezQt
import org.kde.kitemmodels as KItemModels

// Bluetooth through BluezQt, KDE's public Bluetooth library. State is live, so
// the connected device shows up on the pill as soon as it attaches.
Item {
    id: bluetooth
    visible: false

    readonly property bool available: BluezQt.Manager.adapters.length > 0
    readonly property bool powered: BluezQt.Manager.bluetoothOperational
    readonly property var connectedDevices: BluezQt.Manager.connectedDevices

    // The connected device belongs on the pill, the same way the SSID sits
    // under Wi-Fi.
    readonly property string summary: {
        const count = connectedDevices.length;
        if (count > 1) {
            return i18np("%1 device", "%1 devices", count);
        }
        return count === 1 ? connectedDevices[0].name : "";
    }

    readonly property alias pairedDevices: paired

    function setEnabled(on) {
        // Unblock rfkill as well as powering the adapters, or switching on
        // does nothing after airplane mode has soft-blocked the radio.
        BluezQt.Manager.bluetoothBlocked = !on;
        for (let i = 0; i < BluezQt.Manager.adapters.length; ++i) {
            BluezQt.Manager.adapters[i].powered = on;
        }
    }

    function setConnected(device, on) {
        if (on) {
            device.connectToDevice();
        } else {
            device.disconnectFromDevice();
        }
    }

    BluezQt.DevicesModel { id: devices }

    KItemModels.KSortFilterProxyModel {
        id: paired
        sourceModel: devices
        filterRowCallback: (sourceRow, sourceParent) => {
            const index = sourceModel.index(sourceRow, 0, sourceParent);
            return sourceModel.data(index, sourceModel.KItemModels.KRoleNames.role("Paired")) === true;
        }
    }
}
