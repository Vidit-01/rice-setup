import QtQuick

// External monitor contrast over DDC/CI, through ddcutil.
//
// Brightness no longer needs this - Plasma drives it itself - but Plasma has
// no contrast control, so this one setting still goes the way the Cinnamon
// applet did it. Commands run strictly one after another: two ddcutil
// processes talking to the same I2C bus at once corrupt each other's replies.
Item {
    id: contrast
    visible: false

    required property var shell

    property bool available: false      // ddcutil is installed
    property bool scanning: false
    // [{ bus, model, value, max }]. Replaced wholesale on every change, so
    // bindings that look a monitor up re-evaluate.
    property var monitors: []

    property double _lastScan: 0
    property var _queue: []
    property bool _busy: false

    /**
     * The DDC/CI monitor behind one of Plasma's displays, matched by model
     * name: Plasma labels a display "Dell Inc. Dell S2716DG", ddcutil reports
     * the model as "Dell S2716DG".
     *
     * @param {string} label - The display's label from org.kde.ScreenBrightness.
     * @returns {object|null}
     */
    function monitorFor(label) {
        const wanted = String(label).toLowerCase();
        for (const monitor of monitors) {
            // value < 0: found, but its contrast has not been read yet. ddcutil
            // takes seconds, and a slider sitting at a made-up 0 is worse
            // than one that turns up a moment late.
            if (monitor.value >= 0 && monitor.model !== "" && wanted.indexOf(monitor.model.toLowerCase()) >= 0) {
                return monitor;
            }
        }
        return null;
    }

    /**
     * @param {int} bus - I2C bus of the monitor.
     * @param {real} fraction - 0 to 1 of the monitor's own maximum.
     */
    function setContrast(bus, fraction) {
        let target = -1;
        contrast.monitors = monitors.map(monitor => {
            if (monitor.bus !== bus) {
                return monitor;
            }
            // Not every monitor runs 0-100: the Dell S2716DG reports a
            // contrast maximum of 125. Scale by what the monitor says.
            target = Math.round(Math.max(0, Math.min(1, fraction)) * monitor.max);
            return Object.assign({}, monitor, { value: target });
        });
        if (target < 0) {
            return;
        }
        // Only the latest position matters; drop any write still waiting.
        _queue = _queue.filter(job => !(job.write && job.bus === bus));
        _enqueue({ write: true, bus: bus, command: "ddcutil --bus=" + bus + " setvcp 12 " + target });
    }

    /**
     * Looks for DDC/CI monitors and reads their contrast.
     *
     * @param {bool} [force] - Scan even if one ran a moment ago.
     */
    function scan(force) {
        if (scanning || (!force && Date.now() - _lastScan < 60000)) {
            return;
        }
        scanning = true;
        _lastScan = Date.now();
        shell.exec("command -v ddcutil >/dev/null 2>&1 && ddcutil detect --brief", (stdout, exitCode) => {
            contrast.available = exitCode === 0;
            const found = [];
            let current = null;
            // Blocks look like:
            //   Display 1
            //      I2C bus:          /dev/i2c-21
            //      Monitor:          DEL:Dell S2716DG:<serial>
            // "Invalid display" blocks (the laptop panel) are skipped.
            for (const line of String(stdout).split("\n")) {
                if (/^Display \d+/.test(line)) {
                    current = { bus: -1, model: "", value: -1, max: 100 };
                    found.push(current);
                } else if (/^\S/.test(line)) {
                    current = null;
                } else if (current) {
                    const bus = line.match(/I2C bus:\s+\/dev\/i2c-(\d+)/);
                    const monitor = line.match(/Monitor:\s+[^:]*:([^:]*):/);
                    if (bus) {
                        current.bus = parseInt(bus[1], 10);
                    } else if (monitor) {
                        current.model = monitor[1].trim();
                    }
                }
            }
            contrast.monitors = found.filter(monitor => monitor.bus >= 0);
            for (const monitor of contrast.monitors) {
                _enqueue({ write: false, bus: monitor.bus, command: "ddcutil --bus=" + monitor.bus + " --terse getvcp 12" });
            }
            _enqueue({ done: true });
        });
    }

    function _enqueue(job) {
        _queue.push(job);
        _pump();
    }

    function _pump() {
        if (_busy || _queue.length === 0) {
            return;
        }
        const job = _queue.shift();
        if (job.done) {
            scanning = false;
            _pump();
            return;
        }
        _busy = true;
        shell.exec(job.command, (stdout, exitCode, stderr) => {
            _busy = false;
            if (exitCode !== 0) {
                console.warn("Quick Settings:", job.command, "failed:", String(stderr).trim());
            } else if (!job.write) {
                // "VCP 12 C 94 125": current value, then maximum.
                const reply = String(stdout).match(/VCP 12 C (\d+) (\d+)/);
                if (reply) {
                    contrast.monitors = contrast.monitors.map(monitor => monitor.bus !== job.bus ? monitor
                        : Object.assign({}, monitor, { value: parseInt(reply[1], 10), max: parseInt(reply[2], 10) || 100 }));
                }
            }
            _pump();
        });
    }
}
