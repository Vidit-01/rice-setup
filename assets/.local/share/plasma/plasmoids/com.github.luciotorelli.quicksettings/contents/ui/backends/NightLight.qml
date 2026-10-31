import QtQuick
import org.kde.plasma.workspace.dbus as DBus

// Night Light, read live from KWin.
//
// KWin's D-Bus interface can only *inhibit* Night Light, and an inhibition
// dies with whoever asked for it. The pill is meant to be the same switch as
// the one in System Settings, so it writes that setting instead: KWin watches
// its config and picks the change up at once, and the state survives a reboot.
Item {
    id: nightLight
    visible: false

    required property var shell

    property bool available: false
    property bool active: false
    // Actually tinting the screen right now, as opposed to merely switched on
    // and waiting for sunset.
    property bool running: false

    function setEnabled(on) {
        nightLight.active = on; // echo; KWin's change signal confirms it
        shell.exec("kwriteconfig6 --file kwinrc --group NightColor --key Active --type bool "
                   + (on ? "true" : "false") + " --notify",
                   () => props.updateAll());
    }

    function _sync() {
        const p = props.properties;
        nightLight.available = p.available === true;
        nightLight.active = p.enabled === true;
        nightLight.running = p.running === true;
    }

    DBus.Properties {
        id: props
        busType: DBus.BusType.Session
        service: "org.kde.KWin"
        path: "/org/kde/KWin/NightLight"
        iface: "org.kde.KWin.NightLight"
        onRefreshed: nightLight._sync()
        onPropertiesChanged: nightLight._sync()
    }
}
