import QtQuick
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.networkmanagement as PlasmaNM

// Wi-Fi, wired, VPN and airplane mode, on the same live models Plasma's own
// network applet uses. Nothing here polls: the connection list updates itself,
// and the pill readouts below are recomputed whenever a row changes.
Item {
    id: net
    visible: false

    // NetworkManagerQt's ConnectionType. PlasmaNM.Enums mirrors it only as far
    // as Wireless, and NetworkManager files WireGuard tunnels under their own
    // type rather than as VPNs, so a filter on Vpn alone misses them.
    readonly property int typeWireGuard: 19

    readonly property bool wifiAvailable: devices.wirelessDeviceAvailable
    readonly property bool wifiEnabled: enabled.wirelessEnabled
    readonly property bool wiredAvailable: devices.wiredDeviceAvailable
    readonly property bool airplaneMode: PlasmaNM.Configuration.airplaneModeEnabled
    readonly property bool scanning: handler.scanning

    // Pill readouts, filled in by _recompute().
    property string wifiName: ""
    property bool wifiConnecting: false
    property bool wiredActive: false
    property string wiredName: ""
    property bool vpnActive: false
    property string vpnName: ""
    property int vpnCount: 0

    // Rows for the panels: the applet's own sorting (active first, then by
    // signal), narrowed to one kind of connection.
    readonly property alias wifiConnections: wifiRows
    readonly property alias wiredConnections: wiredRows
    readonly property alias vpnConnections: vpnRows

    function isVpnType(type) {
        return type === PlasmaNM.Enums.Vpn || type === net.typeWireGuard;
    }

    function setWifi(on) {
        handler.enableWireless(on);
    }

    function setAirplane(on) {
        // Both halves, as the stock applet does it: the handler switches the
        // radios, the configuration remembers that it was airplane mode that
        // did so, so switching it off restores what was on before.
        handler.enableAirplaneMode(on);
        PlasmaNM.Configuration.airplaneModeEnabled = on;
    }

    function setWired(on) {
        const row = net._wiredRow;
        if (row) {
            net.setConnection(row, on);
        }
    }

    /**
     * Turning the VPN off drops whatever is active; turning it on brings back
     * the last tunnel that was up this session, or the first one configured.
     */
    function setVpn(on) {
        const row = on ? (net._vpnDefaultRow || net._vpnFirstRow) : net._vpnActiveRow;
        if (row) {
            net.setConnection(row, on);
        }
    }

    /**
     * Connects or disconnects one row of the connection list.
     *
     * @param {object} row - A delegate's `model`, or one of the cached rows.
     * @param {bool} on - True to connect.
     */
    function setConnection(row, on) {
        if (!on) {
            handler.deactivateConnection(row.ConnectionPath, row.DevicePath);
        } else if (row.Uuid) {
            handler.activateConnection(row.ConnectionPath, row.DevicePath, row.SpecificPath);
        } else {
            // A network with no saved profile yet. Plasma's secret agent asks
            // for the password itself if the network needs one.
            handler.addAndActivateConnection(row.DevicePath, row.SpecificPath, "");
        }
    }

    function requestScan() {
        handler.requestScan("");
    }

    property var _wiredRow: null
    property var _vpnActiveRow: null
    property var _vpnDefaultRow: null
    property var _vpnFirstRow: null

    function _recompute() {
        let wifiName = "", wifiConnecting = false;
        let wired = null, wiredUp = false;
        let vpnActive = null, vpnFirst = null, vpnCount = 0;

        for (let i = 0; i < rows.count; ++i) {
            const row = rows.objectAt(i);
            if (!row) {
                continue;
            }
            const up = row.connectionState === PlasmaNM.Enums.Activated;
            if (row.type === PlasmaNM.Enums.Wireless) {
                if (up && !wifiName) {
                    wifiName = row.ssid || row.name;
                } else if (row.connectionState === PlasmaNM.Enums.Activating) {
                    wifiConnecting = true;
                }
            } else if (row.type === PlasmaNM.Enums.Wired) {
                // Prefer a connected adapter if there is more than one.
                if (!wired || (up && !wiredUp)) {
                    wired = row;
                    wiredUp = up;
                }
            } else if (net.isVpnType(row.type)) {
                vpnCount += 1;
                vpnFirst = vpnFirst || row;
                if (up) {
                    vpnActive = row;
                }
            }
        }

        net.wifiName = wifiName;
        net.wifiConnecting = wifiConnecting;
        net._wiredRow = wired ? wired.snapshot() : null;
        net.wiredActive = wiredUp;
        net.wiredName = wired ? wired.name : "";
        net._vpnActiveRow = vpnActive ? vpnActive.snapshot() : null;
        net._vpnFirstRow = vpnFirst ? vpnFirst.snapshot() : null;
        if (vpnActive) {
            net._vpnDefaultRow = net._vpnActiveRow;
        }
        net.vpnActive = vpnActive !== null;
        net.vpnName = vpnActive ? vpnActive.name : "";
        net.vpnCount = vpnCount;
    }

    PlasmaNM.Handler { id: handler }
    PlasmaNM.EnabledConnections { id: enabled }
    PlasmaNM.AvailableDevices { id: devices }
    PlasmaNM.NetworkModel { id: connectionModel }
    PlasmaNM.AppletProxyModel {
        id: appletModel
        sourceModel: connectionModel
    }

    // Mirrors the rows into objects the readouts above can be computed from.
    Instantiator {
        id: rows
        model: appletModel
        delegate: QtObject {
            required property var model
            readonly property int type: model.Type
            readonly property int connectionState: model.ConnectionState
            readonly property string name: model.ItemUniqueName ?? ""
            readonly property string ssid: model.Ssid ?? ""

            function snapshot() {
                return {
                    Uuid: model.Uuid,
                    ConnectionPath: model.ConnectionPath,
                    DevicePath: model.DevicePath,
                    SpecificPath: model.SpecificPath,
                };
            }

            onConnectionStateChanged: Qt.callLater(net._recompute)
            onNameChanged: Qt.callLater(net._recompute)
        }
        onObjectAdded: Qt.callLater(net._recompute)
        onObjectRemoved: Qt.callLater(net._recompute)
    }

    component TypeFilter: KItemModels.KSortFilterProxyModel {
        property var accepts: type => false
        sourceModel: appletModel
        filterRowCallback: (sourceRow, sourceParent) => {
            const index = sourceModel.index(sourceRow, 0, sourceParent);
            return accepts(sourceModel.data(index, sourceModel.KItemModels.KRoleNames.role("Type")));
        }
    }

    TypeFilter {
        id: wifiRows
        accepts: type => type === PlasmaNM.Enums.Wireless
    }
    TypeFilter {
        id: wiredRows
        accepts: type => type === PlasmaNM.Enums.Wired
    }
    TypeFilter {
        id: vpnRows
        accepts: type => net.isVpnType(type)
    }
}
