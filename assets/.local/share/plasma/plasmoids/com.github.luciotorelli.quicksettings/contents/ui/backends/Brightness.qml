import QtQuick
import org.kde.plasma.workspace.dbus as DBus

// Screen brightness through Plasma's own org.kde.ScreenBrightness service.
//
// It covers the laptop panel and DDC/CI monitors alike, already scaled to each
// display's real range, so the ddcutil detection and the per-monitor maximum
// handling from the Cinnamon applet are not needed for brightness at all.
Item {
    id: brightness
    visible: false

    readonly property string service: "org.kde.ScreenBrightness"
    readonly property string rootPath: "/org/kde/ScreenBrightness"

    // Display objects, each with: name, label, isInternal, value (0-1), setValue().
    property var displays: []
    property var displayNames: []

    /**
     * Steps every display, for scrolling over the panel button.
     *
     * @param {real} delta - Fraction to add, e.g. 0.05.
     */
    function stepAll(delta) {
        for (const display of displays) {
            display.setValue(display.value + delta);
        }
    }

    function refresh() {
        manager.updateAll();
        for (const display of displays) {
            display.refresh();
        }
    }

    function _rebuild() {
        const list = [];
        for (let i = 0; i < objects.count; ++i) {
            const display = objects.objectAt(i);
            if (display) {
                list.push(display);
            }
        }
        // Laptop panel first, then monitors in the order Plasma lists them.
        list.sort((a, b) => Number(b.isInternal) - Number(a.isInternal));
        brightness.displays = list;
    }

    DBus.Properties {
        id: manager
        busType: DBus.BusType.Session
        service: brightness.service
        path: brightness.rootPath
        iface: "org.kde.ScreenBrightness"
        onRefreshed: brightness.displayNames = properties.DisplaysDBusNames || []
    }

    DBus.SignalWatcher {
        busType: DBus.BusType.Session
        service: brightness.service
        path: brightness.rootPath
        iface: "org.kde.ScreenBrightness"

        function dbusDisplayAdded(name) {
            manager.updateAll();
        }
        function dbusDisplayRemoved(name) {
            manager.updateAll();
        }
        function dbusBrightnessChanged(name, value, sourceClientName, sourceClientContext) {
            for (const display of brightness.displays) {
                if (display.name === name) {
                    display.raw = value;
                }
            }
        }
        function dbusBrightnessRangeChanged(name, max, value) {
            for (const display of brightness.displays) {
                if (display.name === name) {
                    display.max = max;
                    display.raw = value;
                }
            }
        }
    }

    Instantiator {
        id: objects
        model: brightness.displayNames
        delegate: QtObject {
            id: display

            required property string modelData
            readonly property string name: modelData
            property string label: ""
            property bool isInternal: false
            property int raw: 0
            property int max: 1
            readonly property real value: max > 0 ? raw / max : 0

            function setValue(fraction) {
                const target = Math.round(Math.max(0, Math.min(1, fraction)) * max);
                if (target === raw) {
                    return;
                }
                raw = target; // echo at once so the slider does not fight the drag
                DBus.SessionBus.asyncCall({
                    service: brightness.service,
                    path: brightness.rootPath + "/" + display.name,
                    iface: "org.kde.ScreenBrightness.Display",
                    member: "SetBrightness",
                    // flag 1: no on-screen indicator; the slider is the indicator
                    arguments: [target, 1],
                    signature: "(iu)",
                }, () => {}, error => console.warn("Quick Settings: SetBrightness failed:", error.message));
            }

            function refresh() {
                props.updateAll();
            }

            readonly property var props: DBus.Properties {
                busType: DBus.BusType.Session
                service: brightness.service
                path: brightness.rootPath + "/" + display.name
                iface: "org.kde.ScreenBrightness.Display"
                onRefreshed: {
                    display.label = properties.Label || "";
                    display.isInternal = properties.IsInternal === true;
                    display.max = Number(properties.MaxBrightness) || 1;
                    display.raw = Number(properties.Brightness) || 0;
                    brightness._rebuild();
                }
            }
        }
        onObjectAdded: brightness._rebuild()
        onObjectRemoved: brightness._rebuild()
    }
}
