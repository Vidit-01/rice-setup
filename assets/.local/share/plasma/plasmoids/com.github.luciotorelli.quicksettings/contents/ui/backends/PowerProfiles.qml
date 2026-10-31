import QtQuick
import org.kde.plasma.workspace.dbus as DBus

// Power profile, through PowerDevil rather than powerprofilesctl: the CLI is
// not installed everywhere (Fedora KDE ships without it), while this
// interface is there whenever Plasma can switch profiles at all.
Item {
    id: power
    visible: false

    readonly property string service: "org.kde.Solid.PowerManagement"
    readonly property string path: "/org/kde/Solid/PowerManagement/Actions/PowerProfile"
    readonly property string iface: "org.kde.Solid.PowerManagement.Actions.PowerProfile"

    property string current: ""
    property var choices: []
    readonly property bool available: choices.length > 0

    function label(profile) {
        switch (profile) {
        case "power-saver": return i18n("Power Saver");
        case "balanced": return i18n("Balanced");
        case "performance": return i18n("Performance");
        }
        return profile;
    }

    function icon(profile) {
        return profile ? "power-profile-" + profile + "-symbolic" : "power-profile-balanced-symbolic";
    }

    function setProfile(profile) {
        if (profile === current) {
            return;
        }
        current = profile; // echo; currentProfileChanged confirms it
        _call("setProfile", [profile], "(s)", null);
    }

    function refresh() {
        _call("currentProfile", [], "", value => power.current = value || "");
        _call("profileChoices", [], "", value => power.choices = value || []);
    }

    function _call(member, args, signature, resolve) {
        DBus.SessionBus.asyncCall({
            service: power.service,
            path: power.path,
            iface: power.iface,
            member: member,
            arguments: args,
            signature: signature,
        }, reply => {
            if (resolve) {
                const v = reply.value;
                resolve(v !== null && typeof v === "object" && "value" in v ? v.value : v);
            }
        }, error => console.warn("Quick Settings: " + member + " failed:", error && error.message));
    }

    DBus.SignalWatcher {
        busType: DBus.BusType.Session
        service: power.service
        path: power.path
        iface: power.iface

        function dbuscurrentProfileChanged(profile) {
            power.current = profile;
        }
        function dbusprofileChoicesChanged(choices) {
            power.choices = choices;
        }
    }

    Component.onCompleted: refresh()
}
