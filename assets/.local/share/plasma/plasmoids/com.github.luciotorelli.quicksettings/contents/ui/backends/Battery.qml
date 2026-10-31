import QtQuick
import org.kde.plasma.workspace.dbus as DBus

// Laptop battery, from UPower's DisplayDevice.
//
// The DisplayDevice is UPower's own composite of the system batteries, so a
// paired Logitech mouse (hidpp_battery_0) cannot be mistaken for the laptop's
// pack the way it can when walking /sys/class/power_supply by hand.
Item {
    id: battery
    visible: false

    property bool present: false
    property int percent: 0
    // UPower state: 1 charging, 2 discharging, 4 fully charged, 5 pending charge
    property int chargeState: 0
    property bool onBattery: false

    readonly property bool charging: chargeState === 1
    readonly property bool pluggedIn: !onBattery
    readonly property bool fullyCharged: chargeState === 4

    function _sync() {
        const p = device.properties;
        battery.present = p.IsPresent === true;
        battery.percent = Math.round(Number(p.Percentage) || 0);
        battery.chargeState = Number(p.State) || 0;
    }

    DBus.Properties {
        id: device
        busType: DBus.BusType.System
        service: "org.freedesktop.UPower"
        path: "/org/freedesktop/UPower/devices/DisplayDevice"
        iface: "org.freedesktop.UPower.Device"
        onRefreshed: battery._sync()
        onPropertiesChanged: battery._sync()
    }

    DBus.Properties {
        id: upower
        busType: DBus.BusType.System
        service: "org.freedesktop.UPower"
        path: "/org/freedesktop/UPower"
        iface: "org.freedesktop.UPower"
        onRefreshed: battery.onBattery = properties.OnBattery === true
        onPropertiesChanged: battery.onBattery = properties.OnBattery === true
    }
}
