import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Runs shell commands and hands back their output. Only used where Plasma has
// no API of its own (ddcutil, fw-fanctrl, launching apps).
P5Support.DataSource {
    id: shell

    engine: "executable"
    connectedSources: []

    property var _callbacks: ({})
    property int _serial: 0
    // The engine behind this is shared by everything in plasmashell, and it
    // identifies a run by its command line: two runners asking for the same
    // text at the same moment get one execution and the same result. Two
    // copies of the widget do exactly that - same commands, same serials - and
    // for a command that must only succeed once (Keep Awake's claim) both were
    // told it had. The token makes every runner's command lines its own.
    readonly property string _token: Math.random().toString(36).slice(2, 10)

    /**
     * @param {string} command - Command line, run through sh.
     * @param {function(string, int, string)} [callback] - Receives stdout, exit code, stderr.
     */
    function exec(command, callback) {
        // The engine keys a run by its full command line and ignores a repeat
        // while one is in flight. A trailing comment makes every call unique.
        const source = command + " #qs" + _token + "-" + (++_serial);
        if (callback) {
            _callbacks[source] = callback;
        }
        connectSource(source);
    }

    onNewData: (source, data) => {
        const callback = _callbacks[source];
        delete _callbacks[source];
        disconnectSource(source);
        if (callback) {
            callback(data["stdout"] || "", data["exit code"], data["stderr"] || "");
        }
    }
}
