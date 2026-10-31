import QtQuick
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.private.sessions as Sessions
import "backends" as Backends

// Quick Settings - a GNOME-style control centre for KDE Plasma.
//
// The backends live here rather than in the popup, so their state is already
// current when the popup opens and the panel button can show the battery
// without the popup ever having been built.
PlasmoidItem {
    id: root

    readonly property alias network: network
    readonly property alias bluetooth: bluetooth
    readonly property alias audio: audio
    readonly property alias brightness: brightness
    readonly property alias nightLight: nightLight
    readonly property alias keepAwake: keepAwake
    readonly property alias power: power
    readonly property alias battery: battery
    readonly property alias fan: fan
    readonly property alias contrast: contrast
    readonly property alias kdeConnect: kdeConnect

    function openSettings(module) {
        KCMUtils.KCMLauncher.openSystemSettings(module);
        root.expanded = false;
    }

    function openSystemSettings() {
        shell.exec("kstart systemsettings");
        root.expanded = false;
    }

    function takeScreenshot() {
        // Close first, or the popup is what ends up in the picture.
        root.expanded = false;
        shell.exec("kstart spectacle");
    }

    function lockScreen() {
        root.expanded = false;
        session.lock();
    }

    // The power menu's actions. ConfirmationMode.Skip: act at once, without
    // Plasma's confirmation screen and its countdown.
    readonly property bool canSuspend: session.canSuspend
    readonly property bool canReboot: session.canReboot
    readonly property bool canShutdown: session.canShutdown

    function suspend() {
        root.expanded = false;
        session.suspend();
    }

    function reboot() {
        root.expanded = false;
        session.requestReboot(Sessions.SessionManagement.ConfirmationMode.Skip);
    }

    function shutDown() {
        root.expanded = false;
        session.requestShutdown(Sessions.SessionManagement.ConfirmationMode.Skip);
    }

    toolTipMainText: i18n("Quick Settings")
    toolTipSubText: !battery.present ? ""
        : battery.charging ? i18n("Battery at %1%, charging", battery.percent)
        : battery.fullyCharged ? i18n("Battery fully charged")
        : i18n("Battery at %1%", battery.percent)

    switchWidth: Kirigami.Units.gridUnit * 18
    switchHeight: Kirigami.Units.gridUnit * 14

    compactRepresentation: CompactRepresentation {
        app: root
    }
    fullRepresentation: FullRepresentation {
        app: root
    }

    Backends.Shell { id: shell }
    Backends.Network { id: network }
    Backends.Bluetooth { id: bluetooth }
    Backends.Audio { id: audio }
    Backends.Brightness { id: brightness }
    Backends.NightLight {
        id: nightLight
        shell: shell
    }
    Backends.KeepAwake {
        id: keepAwake
        shell: shell
        reason: i18n("Keep Awake is on")
        // Test renders share the runtime directory with the real widget;
        // they must not switch its Keep Awake on or off.
        markerName: root.devGrabPath !== "" ? "quicksettings-keep-awake-test" : "quicksettings-keep-awake"
    }
    Backends.PowerProfiles { id: power }
    Backends.Battery { id: battery }
    Backends.Fan {
        id: fan
        shell: shell
    }
    Backends.Contrast {
        id: contrast
        shell: shell
        Component.onCompleted: scan(true)
    }
    Backends.KdeConnect {
        id: kdeConnect
        shell: shell
    }

    // A monitor swap changes which DDC/CI displays exist. Debounced, because
    // the display list changes several times through a swap and a monitor
    // needs a moment to wake before it answers.
    Connections {
        target: brightness
        function onDisplayNamesChanged() {
            rescan.restart();
        }
    }
    Timer {
        id: rescan
        interval: 3000
        onTriggered: contrast.scan(true)
    }

    Sessions.SessionManagement { id: session }

    Loader {
        active: root.devGrabPath !== ""
        source: "DevGrab.qml"
        onLoaded: item.plasmoidItem = root
    }

    // `plasmawindowed <package> qs-grab=/path/out.png` renders the popup to a
    // file and quits. Never set inside plasmashell, so this stays inert there.
    readonly property string devGrabPath: {
        const arg = Qt.application.arguments.find(a => a.startsWith("qs-grab="));
        return arg ? arg.slice("qs-grab=".length) : "";
    }
}
