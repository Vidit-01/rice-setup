import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.plasma.workspace.components as WorkspaceComponents
import "components"
import "panels" as Panels

// The popup. Top to bottom: a header strip (battery plus screenshot, settings,
// lock and power buttons), the volume and brightness sliders, then a
// two-column grid of toggle pills.
//
// Opening a panel never changes the size of the window. A popup hanging off a
// bottom panel has to be resized and moved to grow upwards, and Plasma does
// not do the two together on Wayland: the old contents are moved first and
// the taller ones arrive a moment later, so the popup visibly jumps up and
// drops back. So the panel is given room inside the window instead. The row
// that owns it slides up to sit under the header, everything else fades out,
// and the panel unfolds beneath its row into the space that frees up.
Item {
    id: full

    required property var app

    readonly property var config: Plasmoid.configuration

    // The open panel, or "". Only ever one: reopening the popup starts
    // collapsed rather than restoring whatever was last expanded.
    property string expandedKey: ""
    property int gridPanelSlot: 0

    // Which row a panel was last opened for, and how far up it has to travel.
    // Worked out when the panel opens, and kept while it closes again.
    property string focusKey: ""
    property real focusShift: 0
    property real focusRowHeight: 0
    readonly property bool focusIsGrid: focusKey !== "" && focusKey !== "audio"
    readonly property int focusRow: Math.floor(gridPanelSlot / 2)
    readonly property real focusProgress: Math.max(sliderPanel.progress, gridPanel.progress)

    // Pills in grid order, before the visibility filter.
    readonly property var tileOrder: ["wired", "bluetooth", "wifi", "vpn", "power", "fan", "nightlight", "awake", "airplane", "kdeconnect"]
    readonly property var visibleKeys: tileOrder.filter(key => tileVisible(key))
    readonly property real pillPitch: firstPill.implicitHeight + look.pillSpacing

    function tileVisible(key) {
        switch (key) {
        case "wired": return config.showWired;
        case "bluetooth": return config.showBluetooth;
        case "wifi": return config.showWifi;
        case "vpn": return config.showVpn;
        case "power": return config.showPower && app.power.available;
        case "fan": return config.showFan && app.fan.available;
        case "nightlight": return config.showNightLight && app.nightLight.available;
        case "awake": return config.showAwake;
        case "airplane": return config.showAirplane;
        case "kdeconnect": return config.showKdeConnect;
        }
        return false;
    }

    function toggleExpansion(key) {
        if (expandedKey === key) {
            expandedKey = "";
            return;
        }
        if (expandedKey !== "") {
            // Switching panels: drop the old one at once - two panels
            // animating opposite ways reads as a glitch - and open the new one
            // a frame later, once the layout it is measured against has
            // forgotten the old one.
            collapse();
            pendingKey = key;
            openTimer.restart();
            return;
        }
        open(key);
    }

    function open(key) {
        if (key === "audio") {
            focusShift = sliderStack.y + volumeRow.y;
            focusRowHeight = volumeRow.height + 4;
        } else {
            gridPanelSlot = visibleKeys.indexOf(key);
            focusShift = grid.y + focusRow * pillPitch;
            focusRowHeight = pillPitch;
        }
        focusKey = key;
        expandedKey = key;
    }

    function collapse() {
        openTimer.stop();
        sliderPanel.snap = gridPanel.snap = true;
        expandedKey = "";
        sliderPanel.snap = gridPanel.snap = false;
    }

    property string pendingKey: ""
    Timer {
        id: openTimer
        interval: 16
        onTriggered: full.open(full.pendingKey)
    }

    // The window is as tall as the content with every panel shut, and stays
    // that way. The height is only ever taken while nothing is open or moving:
    // mid-animation it is pieced together from layout sizes that update one
    // after another, and measured it took two different values on every
    // frame. It is applied a frame late so that several steps make one resize.
    readonly property bool idle: expandedKey === "" && sliderPanel.settled && gridPanel.settled
    readonly property real contentHeight: Math.ceil(header.implicitHeight + column.spacing + column.implicitHeight
        - sliderPanel.implicitHeight - gridPanel.implicitHeight)
    // With most pills hidden the content is short; a panel still needs room.
    readonly property real minimumHeight: Math.ceil(header.implicitHeight + column.spacing + pillPitch
        + Kirigami.Units.gridUnit * 13)
    property real appliedHeight: 0
    readonly property real windowHeight: Math.max(appliedHeight, minimumHeight)

    onContentHeightChanged: applyTimer.restart()
    onIdleChanged: applyTimer.restart()
    Component.onCompleted: {
        appliedHeight = contentHeight;
        floatPopup();
    }
    Timer {
        id: applyTimer
        interval: 16
        onTriggered: {
            if (full.idle) {
                full.appliedHeight = full.contentHeight;
            }
        }
    }

    // A popup that floats, whatever the panel does.
    //
    // Unless the panel is set to floating, the shell gives an applet's popup
    // no margin and takes away its border wherever it meets the panel or the
    // screen edge. Tucked into a corner it then reads as a docked side panel:
    // two square, shadowless edges. Both are ordinary properties of the popup
    // window, so the widget sets them on the window it finds itself in. They
    // are only touched when they exist - in a test window, or on the desktop,
    // there is nothing to set.
    function floatPopup() {
        const popup = full.Window.window;
        if (!popup || !("margin" in popup) || !("removeBorderStrategy" in popup)) {
            return;
        }
        if (config.floatingPopup) {
            popup.removeBorderStrategy = 0;     // PopupPlasmaWindow.Never
            popup.margin = Kirigami.Units.largeSpacing;
        } else {
            // What the shell would have chosen itself.
            const floatingPanel = Plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentPrefersFloatingApplets;
            popup.removeBorderStrategy = 3;     // AtScreenEdges | AtPanelEdges
            popup.margin = floatingPanel ? Kirigami.Units.largeSpacing : 0;
        }
    }
    Window.onWindowChanged: floatPopup()
    Connections {
        target: full.config
        function onFloatingPopupChanged() {
            full.floatPopup();
        }
    }

    // Build the panels in the background once the popup has had a moment to
    // open, so that by the time a chevron is clicked there is nothing left to
    // create. They are kept from then on; their lists are live either way.
    property bool preloadPanels: false
    Timer {
        interval: 250
        running: full.app.expanded && !full.preloadPanels
        onTriggered: full.preloadPanels = true
    }

    Connections {
        target: full.app
        function onExpandedChanged() {
            if (full.app.expanded) {
                // Everything else is live; these are the ones that are read.
                full.app.brightness.refresh();
                full.app.keepAwake.refresh();
                full.app.fan.refresh();
                full.app.contrast.scan(false);
                full.app.kdeConnect.refresh();
            } else {
                full.collapse();
            }
        }
    }

    Layout.minimumWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.maximumWidth: Kirigami.Units.gridUnit * 28
    Layout.minimumHeight: windowHeight
    Layout.preferredHeight: windowHeight
    Layout.maximumHeight: windowHeight

    SystemPalette {
        id: systemPalette
        colorGroup: SystemPalette.Active
    }
    Style {
        id: look
        // Read off the popup itself, which is visible; see Style.qml for why.
        text: full.Kirigami.Theme.textColor
        systemAccent: systemPalette.accent
    }

    // Test renders (tools/grab.sh) capture this item alone, without the popup
    // window that normally provides the background.
    Rectangle {
        visible: full.app.devGrabPath !== ""
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
    }

    Component {
        id: audioPanel
        Panels.AudioPanel { app: full.app; style: look }
    }
    Component {
        id: wiredPanel
        Panels.WiredPanel { app: full.app; style: look }
    }
    Component {
        id: bluetoothPanel
        Panels.BluetoothPanel { app: full.app; style: look }
    }
    Component {
        id: wifiPanel
        Panels.WifiPanel { app: full.app; style: look }
    }
    Component {
        id: vpnPanel
        Panels.VpnPanel { app: full.app; style: look }
    }
    Component {
        id: powerPanel
        Panels.PowerPanel { app: full.app; style: look }
    }
    Component {
        id: fanPanel
        Panels.FanPanel { app: full.app; style: look }
    }
    Component {
        id: kdeConnectPanel
        Panels.KdeConnectPanel { app: full.app; style: look }
    }

    // Header strip: battery readout on the left, system actions on the right.
    // Stays put while a panel is open; everything beneath it moves.
    RowLayout {
        id: header
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: 6

        T.AbstractButton {
            id: batteryChip
            visible: full.app.battery.present
            implicitWidth: chipRow.implicitWidth + 28
            implicitHeight: 32

            // The readout doubles as the way into the power settings.
            Accessible.name: i18n("Battery at %1%. Open power settings", full.app.battery.percent)
            Accessible.role: Accessible.Button
            onClicked: full.app.openSettings("kcm_powerdevilprofilesconfig")

            contentItem: Item {
                RowLayout {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 6

                    WorkspaceComponents.BatteryIcon {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        hasBattery: true
                        percent: full.app.battery.percent
                        pluggedIn: full.app.battery.pluggedIn
                    }
                    PlasmaComponents.Label {
                        text: i18nc("battery percentage", "%1%", full.app.battery.percent)
                        textFormat: Text.PlainText
                    }
                }
            }

            background: Rectangle {
                radius: height / 2
                color: batteryChip.pressed ? look.tilePressed
                     : batteryChip.hovered ? look.tileHover : look.tileIdle
                border.width: batteryChip.visualFocus ? 2 : 0
                border.color: look.accent
                Behavior on color {
                    ColorAnimation { duration: look.hoverDuration }
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        IconButton {
            style: look
            filled: true
            iconName: "applets-screenshooter-symbolic"
            fallbackIconName: "camera-photo-symbolic"
            tooltip: i18n("Take a Screenshot")
            onClicked: full.app.takeScreenshot()
        }
        IconButton {
            style: look
            filled: true
            iconName: "emblem-system-symbolic"
            fallbackIconName: "configure"
            tooltip: i18n("System Settings")
            onClicked: full.app.openSystemSettings()
        }
        IconButton {
            style: look
            filled: true
            iconName: "changes-prevent-symbolic"
            fallbackIconName: "system-lock-screen"
            tooltip: i18n("Lock Screen")
            onClicked: full.app.lockScreen()
        }
        IconButton {
            style: look
            filled: true
            id: powerButton
            iconName: "system-shutdown-symbolic"
            tooltip: i18n("Power")
            onClicked: powerMenu.openRelative()

            // Each entry acts at once: no confirmation screen, no countdown.
            PlasmaExtras.Menu {
                id: powerMenu
                visualParent: powerButton
                placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup

                PlasmaExtras.MenuItem {
                    text: i18n("Sleep")
                    icon: "system-suspend"
                    visible: full.app.canSuspend
                    onClicked: full.app.suspend()
                }
                PlasmaExtras.MenuItem {
                    text: i18n("Restart")
                    icon: "system-reboot"
                    visible: full.app.canReboot
                    onClicked: full.app.reboot()
                }
                PlasmaExtras.MenuItem {
                    text: i18n("Shut Down")
                    icon: "system-shutdown"
                    visible: full.app.canShutdown
                    onClicked: full.app.shutDown()
                }
            }
        }
    }

    Item {
        id: viewport
        anchors {
            left: parent.left
            right: parent.right
            top: header.bottom
            topMargin: column.spacing
            bottom: parent.bottom
        }
        // Only while something is sliding out of it; otherwise a focus ring or
        // a pressed slider handle at the very edge would lose a pixel.
        clip: full.focusProgress > 0

        ColumnLayout {
            id: column
            width: parent.width
            // Whole pixels, or every label sits on a fractional position and
            // shimmers as it moves.
            y: -Math.round(full.focusProgress * full.focusShift)
            spacing: 10

            // Slider stack: volume (with its device chevron), then one brightness
            // slider per display.
            ColumnLayout {
                id: sliderStack
                // No layout spacing here or in the grid: spacing around a panel
                // would arrive all at once when it turns visible. Every row
                // carries its own bottom margin instead, cancelled after the last.
                spacing: 0
                Layout.bottomMargin: -4

                SliderRow {
                    id: volumeRow
                    style: look
                    Layout.bottomMargin: 4
                    // Stays while its own panel is open, fades for any other.
                    opacity: full.focusKey === "audio" ? 1 : 1 - full.focusProgress
                    enabled: opacity > 0.5
                    expanded: full.expandedKey === "audio"
                    visible: full.config.showVolume && full.app.audio.available
                    iconName: full.app.audio.icon
                    label: i18n("Volume")
                    value: full.app.audio.volume
                    iconClickable: true
                    expandable: true
                    onMoved: value => full.app.audio.setVolume(value)
                    onIconClicked: full.app.audio.toggleMute()
                    onExpandRequested: full.toggleExpansion("audio")
                }

                ExpansionPanel {
                    id: sliderPanel
                    style: look
                    preload: full.preloadPanels
                    panels: ({ audio: audioPanel })
                    panelKey: full.expandedKey === "audio" ? "audio" : ""
                    openHeight: Math.max(0, viewport.height - full.focusRowHeight)
                    gapAbove: 2
                }

                Repeater {
                    model: full.config.showBrightness ? full.app.brightness.displays : []
                    delegate: MonitorRow {
                        required property var modelData

                        style: look
                        Layout.bottomMargin: 4
                        opacity: 1 - full.focusProgress
                        enabled: opacity > 0.5
                        display: modelData
                        monitor: full.config.showMonitorContrast && !modelData.isInternal
                            ? full.app.contrast.monitorFor(modelData.label) : null
                        onContrastCommitted: fraction => full.app.contrast.setContrast(monitor.bus, fraction)
                    }
                }
            }

            // The pills, two to a row. Rows and columns are assigned from each
            // pill's place among the visible ones, which leaves the odd rows free
            // for the panel to drop into beneath whichever row owns it.
            GridLayout {
                id: grid
                columns: 2
                uniformCellWidths: true
                columnSpacing: look.pillSpacing
                rowSpacing: 0
                Layout.bottomMargin: -look.pillSpacing

                component Pill: QuickTile {
                    required property string key
                    readonly property int slot: full.visibleKeys.indexOf(key)

                    // Its own row stays while a panel is open; the rest fade.
                    readonly property bool inFocusRow: full.focusIsGrid && Math.floor(slot / 2) === full.focusRow

                    style: look
                    bodyToggles: full.config.bodyToggles
                    expanded: full.expandedKey === key
                    opacity: inFocusRow ? 1 : 1 - full.focusProgress
                    enabled: opacity > 0.5
                    visible: slot >= 0
                    Layout.bottomMargin: look.pillSpacing
                    Layout.row: 2 * Math.floor(Math.max(0, slot) / 2)
                    Layout.column: Math.max(0, slot) % 2
                    onExpandRequested: full.toggleExpansion(key)
                }

                Pill {
                    id: firstPill
                    key: "wired"
                    title: i18n("Wired")
                    iconName: "network-wired-symbolic"
                    expandable: true
                    active: full.app.network.wiredActive
                    subtitle: active ? full.app.network.wiredName
                            : full.app.network.wiredAvailable ? i18n("Not connected") : i18n("No adapter")
                    onToggled: full.app.network.setWired(!active)
                }
                Pill {
                    key: "bluetooth"
                    title: i18n("Bluetooth")
                    iconName: "bluetooth-symbolic"
                    fallbackIconName: "network-bluetooth"
                    expandable: true
                    active: full.app.bluetooth.powered
                    subtitle: full.app.bluetooth.summary
                    onToggled: full.app.bluetooth.setEnabled(!active)
                }
                Pill {
                    key: "wifi"
                    title: i18n("Wi-Fi")
                    iconName: "network-wireless-symbolic"
                    expandable: true
                    active: full.app.network.wifiEnabled
                    subtitle: !active ? ""
                            : full.app.network.wifiName !== "" ? full.app.network.wifiName
                            : full.app.network.wifiConnecting ? i18n("Connecting…") : ""
                    onToggled: full.app.network.setWifi(!active)
                }
                Pill {
                    key: "vpn"
                    title: i18n("VPN")
                    iconName: "network-vpn-symbolic"
                    expandable: true
                    active: full.app.network.vpnActive
                    subtitle: active ? full.app.network.vpnName
                            : full.app.network.vpnCount > 0 ? i18n("Not connected") : i18n("None configured")
                    onToggled: full.app.network.setVpn(!active)
                }
                Pill {
                    key: "power"
                    title: i18n("Power Mode")
                    iconName: full.app.power.icon(full.app.power.current)
                    fallbackIconName: "battery-profile-balanced"
                    toggleable: false
                    expandable: true
                    // Performance is the one profile worth flagging at a glance.
                    active: full.app.power.current === "performance"
                    subtitle: full.app.power.label(full.app.power.current)
                }
                Pill {
                    key: "fan"
                    title: i18n("Fan Curve")
                    iconName: "sensors-fan-symbolic"
                    fallbackIconName: "weather-windy-symbolic"
                    toggleable: false
                    expandable: true
                    subtitle: full.app.fan.summary
                }
                Pill {
                    key: "nightlight"
                    title: i18n("Night Light")
                    iconName: "night-light-symbolic"
                    fallbackIconName: "redshift-status-on"
                    active: full.app.nightLight.active
                    subtitle: !active ? "" : full.app.nightLight.running ? i18n("On") : i18n("Waiting for sunset")
                    onToggled: full.app.nightLight.setEnabled(!active)
                }
                Pill {
                    key: "awake"
                    title: i18n("Keep Awake")
                    iconName: "preferences-desktop-screensaver-symbolic"
                    fallbackIconName: "system-suspend-inhibited"
                    active: full.app.keepAwake.active
                    subtitle: active ? i18n("No timeout") : ""
                    onToggled: full.app.keepAwake.setActive(!active)
                }
                Pill {
                    key: "airplane"
                    title: i18n("Airplane Mode")
                    iconName: "airplane-mode-symbolic"
                    fallbackIconName: "network-flightmode-on"
                    active: full.app.network.airplaneMode
                    onToggled: full.app.network.setAirplane(!active)
                }
                Pill {
                    key: "kdeconnect"
                    title: i18n("KDE Connect")
                    iconName: "kdeconnect"
                    fallbackIconName: "phone"
                    toggleable: false
                    expandable: true
                    active: full.app.kdeConnect.connected
                    subtitle: full.app.kdeConnect.summary
                }
                ExpansionPanel {
                    id: gridPanel
                    style: look
                    preload: full.preloadPanels
                    openHeight: Math.max(0, viewport.height - full.focusRowHeight)
                    panels: ({
                        wired: wiredPanel,
                        bluetooth: bluetoothPanel,
                        wifi: wifiPanel,
                        vpn: vpnPanel,
                        power: powerPanel,
                        fan: fanPanel,
                        kdeconnect: kdeConnectPanel,
                    })
                    panelKey: full.expandedKey !== "audio" ? full.expandedKey : ""
                    Layout.row: 2 * Math.floor(full.gridPanelSlot / 2) + 1
                    Layout.column: 0
                    Layout.columnSpan: 2
                }
            }

        }
    }
}
