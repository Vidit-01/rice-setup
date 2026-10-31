import QtQuick

// Fan strategy through fw-fanctrl. Only useful on a Framework laptop with
// fw-fanctrl installed; without it `available` stays false and the pill hides.
Item {
    id: fan
    visible: false

    required property var shell

    property bool available: false
    property var strategies: []
    property string current: ""
    property string speed: ""

    readonly property string summary: [current, speed].filter(Boolean).join("  ·  ")

    // Reaction times for the strategies that share one curve, so the panel
    // can say what actually differs between them.
    readonly property var reaction: ({ "medium": "5s", "agile": "3s", "very-agile": "2s" })

    function label(name) {
        return reaction[name] ? name + "  (" + reaction[name] + ")" : name;
    }

    function _quote(text) {
        return "'" + String(text).replace(/'/g, "'\\''") + "'";
    }

    function use(name) {
        if (name === current) {
            return;
        }
        current = name; // echo; refresh() confirms it
        shell.exec("fw-fanctrl use " + _quote(name), () => refresh());
    }

    function reset() {
        shell.exec("fw-fanctrl reset", () => refresh());
    }

    function refresh() {
        if (!available) {
            return;
        }
        shell.exec("fw-fanctrl print list", stdout => {
            fan.strategies = String(stdout).split("\n")
                .map(line => line.match(/^\s*-\s*(\S+)\s*$/))
                .filter(Boolean)
                .map(match => match[1]);
        });
        shell.exec("fw-fanctrl print current", stdout => {
            fan.current = (String(stdout).match(/Strategy in use:\s*'([^']+)'/) || [])[1] || "";
        });
        shell.exec("fw-fanctrl print speed", stdout => {
            fan.speed = (String(stdout).match(/'(\d+%)'/) || [])[1] || "";
        });
    }

    Component.onCompleted: shell.exec("command -v fw-fanctrl", (stdout, exitCode) => {
        fan.available = exitCode === 0;
        fan.refresh();
    })
}
