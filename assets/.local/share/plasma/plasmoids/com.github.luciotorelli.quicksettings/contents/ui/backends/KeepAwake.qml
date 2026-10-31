import QtQuick
import org.kde.plasma.workspace.dbus as DBus

// Keep Awake: one inhibition held with Plasma's power manager.
//
// On Cinnamon this took a systemd lock *and* zeroing the screen timeouts,
// because csd-power never consults logind. PowerDevil honours a single
// inhibition for both sleep and screen blanking, so there is nothing to stash
// and restore.
//
// Two things make the bookkeeping less simple than that sounds.
//
// The inhibition belongs to plasmashell's D-Bus connection, so it dies
// whenever plasmashell restarts - a crash, an update, a manual restart - and
// the pill used to come back switched off. What the user asked for is
// therefore kept separately, as a marker file in $XDG_RUNTIME_DIR, and the
// inhibition is taken out again on startup if the marker is there. That
// directory goes away on logout and reboot, so Keep Awake lasts for the login
// session, as it did on Cinnamon, and cannot be left on by accident for good.
//
// And the widget is often there more than once - a panel on each screen.
// Every copy runs inside the same plasmashell but in a QML engine of its own
// (a singleton is not shared between them; tried), so they cannot share an
// object. They share the marker instead. It records which plasmashell holds
// the inhibition and under which cookie: "<pid> <cookie>". A copy that finds
// its own plasmashell's pid there adopts that inhibition; any copy can
// release it, since the connection is the same. When the pid is a previous
// plasmashell's, exactly one copy wins the claim (an atomic mkdir) and takes
// the inhibition out again, and the others pick it up from the marker.
Item {
    id: keepAwake
    visible: false

    required property var shell
    property string markerName: "quicksettings-keep-awake"
    property string reason: ""          // shown by Plasma beside the inhibition

    readonly property string service: "org.kde.Solid.PowerManagement.PolicyAgent"
    readonly property string path: "/org/kde/Solid/PowerManagement/PolicyAgent"
    readonly property string appName: "Quick Settings"
    readonly property string marker: '"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/' + markerName + '"'

    // InterruptSession (1) | ChangeScreenSettings (4): no sleep, no blanking.
    readonly property int inhibitionTypes: 5

    property bool active: false
    property int cookie: 0
    property int _retries: 0

    /**
     * Brings this copy in line with the marker. Run at startup, whenever the
     * popup opens, and when the power manager's list of inhibitions changes -
     * another copy may have switched Keep Awake since this one last looked.
     */
    function refresh() {
        shell.exec(_readMarker, stdout => {
            const state = keepAwake._parse(stdout);
            if (!state.wanted) {
                keepAwake.active = false;
                keepAwake.cookie = 0;
            } else if (state.heldHere) {
                keepAwake.active = true;
                keepAwake.cookie = state.cookie;
            } else {
                keepAwake.active = true;        // wanted, but held by no one
                keepAwake._restore();
            }
        });
    }

    // The engine runs this as plasmashell's direct child, so $PPID is
    // plasmashell. Prints "yes <pid> <cookie>" or "no", then the own pid. A
    // marker that exists but is empty still counts as wanted.
    readonly property string _readMarker: 'm=' + marker
        + '; if [ -e "$m" ]; then echo "yes $(cat "$m")"; else echo no; fi; echo "$PPID"'

    function _parse(stdout) {
        const lines = String(stdout).trim().split("\n");
        const first = (lines[0] || "").trim().split(/\s+/);
        const ownPid = Number(lines[1]) || -1;
        const pid = Number(first[1]) || 0;
        const cookie = Number(first[2]) || 0;
        return {
            wanted: first[0] === "yes",
            heldHere: pid === ownPid && cookie > 0,
            cookie: cookie,
        };
    }

    function _restore() {
        // mkdir either creates the directory or fails, nothing in between, so
        // only one copy gets to take the inhibition out. Claims left behind
        // by earlier plasmashells are cleared on the way.
        shell.exec('m=' + marker + '; for d in "$m".claim.*; do [ "$d" = "$m.claim.$PPID" ] || rmdir "$d" 2>/dev/null; done; '
                   + 'mkdir "$m.claim.$PPID" 2>/dev/null', (stdout, exitCode) => {
            if (exitCode === 0) {
                keepAwake._acquire();
            } else if (keepAwake._retries < 6) {
                keepAwake._retries += 1;
                retry.restart();                // another copy is on it
            }
        });
    }

    Timer {
        id: retry
        interval: 700
        onTriggered: keepAwake.refresh()
    }

    function _acquire() {
        _call("AddInhibition", [inhibitionTypes, appName, reason], "(uss)", value => {
            const granted = Number(value) || 0;
            keepAwake.cookie = granted;
            keepAwake.active = granted !== 0;
            if (granted !== 0) {
                shell.exec('echo "$PPID ' + granted + '" > ' + marker);
            }
        });
    }

    function setActive(on) {
        active = on; // echo, so the pill does not lag the click
        if (on) {
            _acquire();
            return;
        }
        // Release whatever the marker names rather than what this copy last
        // knew: another copy may have been the one to take it out.
        shell.exec(_readMarker + '; rm -f "$m"', stdout => {
            const state = keepAwake._parse(stdout);
            const held = state.heldHere ? state.cookie : keepAwake.cookie;
            keepAwake.cookie = 0;
            if (held > 0) {
                keepAwake._call("ReleaseInhibition", [held], "(u)", null);
            }
        });
    }

    function _call(member, args, signature, resolve) {
        DBus.SessionBus.asyncCall({
            service: keepAwake.service,
            path: keepAwake.path,
            iface: keepAwake.service,
            member: member,
            arguments: args,
            signature: signature,
        }, reply => {
            if (resolve) {
                // Basic types come back wrapped ({ value: 25 }), lists do not.
                const v = reply.value;
                resolve(v !== null && typeof v === "object" && "value" in v ? v.value : v);
            }
        }, error => console.warn("Quick Settings: " + member + " failed:", error && error.message));
    }

    // Another copy switching Keep Awake shows up here.
    DBus.SignalWatcher {
        busType: DBus.BusType.Session
        service: keepAwake.service
        path: keepAwake.path
        iface: keepAwake.service

        function dbusInhibitionsChanged(added, removed) {
            keepAwake._retries = 0;
            keepAwake.refresh();
        }
    }

    Component.onCompleted: refresh()
}
