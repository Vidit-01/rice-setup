import QtQuick

// KDE Connect state and actions through its installed CLI. This backend only
// refreshes when the popup opens or the device panel is opened.
Item {
    id: kdeConnect
    visible: false

    required property var shell

    property bool available: false
    property bool appAvailable: false
    property bool adbAvailable: false
    property bool scrcpyAvailable: false
    property bool loading: false
    property var devices: []
    property var wirelessDevices: []
    property string message: ""

    readonly property var selectedDevice: {
        const reachable = devices.find(device => device.reachable);
        return reachable || devices[0] || null;
    }
    readonly property bool connected: devices.some(device => device.reachable)
    readonly property string summary: !available ? i18n("Unavailable")
        : loading ? i18n("Checking…")
        : selectedDevice ? (selectedDevice.reachable ? i18n("Connected") : i18n("Not connected"))
        : i18n("No paired devices")

    function _quote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function refresh() {
        checkTools(() => {
            refreshWireless();
            if (!available) return;
            loading = true;
            shell.exec("kdeconnect-cli --list-devices", (stdout, exitCode, stderr) => {
                kdeConnect.loading = false;
                if (exitCode !== 0) {
                    kdeConnect.devices = [];
                    kdeConnect.message = String(stderr || stdout).trim() || i18n("Could not read KDE Connect devices.");
                    return;
                }
                const found = [];
                String(stdout).split("\n").forEach(line => {
                    // Current kdeconnect-cli output: "- Device name: ID (paired and reachable)".
                    const match = line.match(/^\s*-\s*(.*):\s*(\S+)\s*\(([^)]*)\)\s*$/);
                    if (match) {
                        found.push({ name: match[1].trim(), id: match[2], state: match[3],
                            reachable: /reachable/i.test(match[3]) });
                    }
                });
                kdeConnect.devices = found;
                if (found.length) kdeConnect.message = "";
                else kdeConnect.message = i18n("No paired devices found.");
            });
        });
    }

    function checkTools(callback) {
        shell.exec("if command -v kdeconnect-cli >/dev/null 2>&1; then echo cli; else echo no-cli; fi; if command -v kdeconnect-app >/dev/null 2>&1; then echo app; else echo no-app; fi; if command -v adb >/dev/null 2>&1; then echo adb; else echo no-adb; fi; if command -v scrcpy >/dev/null 2>&1; then echo scrcpy; else echo no-scrcpy; fi", stdout => {
            const found = String(stdout).trim().split("\n");
            kdeConnect.available = found[0] === "cli";
            kdeConnect.appAvailable = found[1] === "app";
            kdeConnect.adbAvailable = found[2] === "adb";
            kdeConnect.scrcpyAvailable = found[3] === "scrcpy";
            if (!kdeConnect.available) kdeConnect.message = i18n("kdeconnect-cli is not installed.");
            else if (kdeConnect.message === i18n("kdeconnect-cli is not installed.")
                     || kdeConnect.message === i18n("KDE Connect is not installed.")) kdeConnect.message = "";
            if (!kdeConnect.available && !kdeConnect.appAvailable) kdeConnect.message = i18n("KDE Connect is not installed.");
            if (callback) callback();
        });
    }

    function refreshWireless() {
        if (!adbAvailable) return;
        shell.exec("adb devices -l", (stdout, exitCode) => {
            if (exitCode !== 0) {
                kdeConnect.wirelessDevices = [];
                return;
            }
            const found = [];
            String(stdout).split("\n").forEach(line => {
                const match = line.match(/^\s*(\S+)\s+(device|unauthorized|offline)\b(.*)$/);
                if (!match) return;
                const serial = match[1];
                const wifiSerial = /:\d+$/.test(serial) || /\._adb-tls-connect\._tcp$/.test(serial);
                if (!wifiSerial) return;
                const model = (match[3].match(/\bmodel:(\S+)/) || [])[1] || "";
                found.push({ serial: serial, state: match[2],
                    name: model.replace(/_/g, " ") || serial });
            });
            kdeConnect.wirelessDevices = found;
        });
    }

    function mirror(serial) {
        if (!scrcpyAvailable || !adbAvailable || !serial) return;
        shell.exec("kstart scrcpy --serial " + _quote(serial));
    }

    function openApp() {
        if (appAvailable) shell.exec("kdeconnect-app");
        else message = i18n("kdeconnect-app is not installed.");
    }

    function ring(device) {
        if (!device || !device.reachable || loading) return;
        loading = true;
        message = "";
        shell.exec("kdeconnect-cli --device " + _quote(device.id) + " --ring", (stdout, exitCode, stderr) => {
            kdeConnect.loading = false;
            if (exitCode === 0) {
                kdeConnect.message = String(stdout).trim() || i18n("Ring command completed.");
            } else {
                kdeConnect.message = String(stderr || stdout).trim() || i18n("Could not ring this device.");
            }
        });
    }

    Component.onCompleted: checkTools(() => refreshWireless())
}
