import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM
import "../components"

// VPN and WireGuard tunnels known to NetworkManager.
PanelBody {
    id: body

    title: i18n("VPN")
    iconName: "network-vpn-symbolic"
    footerText: i18n("Network Settings")
    settingsModule: "kcm_networkmanagement"

    Repeater {
        id: list
        model: body.app.network.vpnConnections
        delegate: PanelRow {
            required property var model
            readonly property bool up: model.ConnectionState === PlasmaNM.Enums.Activated

            style: body.style
            iconName: "network-vpn-symbolic"
            label: model.ItemUniqueName
            busy: model.ConnectionState === PlasmaNM.Enums.Activating
                  || model.ConnectionState === PlasmaNM.Enums.Deactivating
            actionText: up ? i18n("Disconnect") : i18n("Connect")
            onActivated: body.app.network.setConnection(model, !up)
        }
    }

    PanelNote {
        style: body.style
        visible: list.count === 0
        text: i18n("No VPN configured")
    }
}
