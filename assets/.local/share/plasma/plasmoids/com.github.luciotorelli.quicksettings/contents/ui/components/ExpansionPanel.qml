import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// The inline panel a chevron opens: header, live list, footer action.
//
// It opens to a height it is given (`openHeight`, whatever the popup has left
// beneath the row that owns it) rather than to the height of its contents, and
// the list scrolls inside. That is what lets the popup window stay one size:
// Plasma cannot resize a popup that hangs off a bottom panel without it
// visibly jumping, so nothing here may ask it to.
//
// One number, `progress`, drives the reveal. The height follows it, and the
// content is scaled vertically by the same fraction so its bottom edge stays
// pinned to the clip edge: every row is there from the first frame and the
// panel unfolds as one piece, instead of rows being uncovered one by one.
// While it moves, the content is drawn through a layer - rendered once into a
// texture and that texture scaled - because scaling the live items makes Qt
// re-rasterise every glyph at every intermediate size.
//
// The bodies are built ahead of time (`preload`), in the background, and kept.
// Building one on the click meant the animation ran while its rows were still
// being created, and they visibly arrived a line at a time - the same thing
// the Cinnamon applet's prefetch was there to hide.
Item {
    id: panel

    required property Style style

    // Which panel to show; "" closes it.
    property string panelKey: ""
    property var panels: ({})           // key -> Component
    property bool snap: false           // skip the animation (switching panels)
    property bool preload: false        // build every body now, not on demand
    property real openHeight: 0
    property real gapAbove: 0           // space above the card, part of openHeight

    // The body on show. Outlives panelKey, so the content is still there
    // while the panel folds shut.
    property string shownKey: ""
    property var bodies: ({})           // key -> built body

    readonly property bool open: panelKey !== ""
    readonly property var body: bodies[shownKey] || null
    readonly property bool settled: progress === (open ? 1 : 0)

    property real progress: open ? 1 : 0
    Behavior on progress {
        enabled: !panel.snap && panel.style.panelDuration > 0
        NumberAnimation {
            // Must not overshoot: height and scale have to stay in lockstep.
            duration: panel.open ? panel.style.panelDuration : Math.round(panel.style.panelDuration * 0.75)
            easing.type: Easing.OutCubic
        }
    }

    onPanelKeyChanged: {
        if (panelKey !== "") {
            shownKey = panelKey;
            scroller.contentY = 0;
        }
    }

    // Tell the body once it is fully open, e.g. so Wi-Fi can rescan without
    // its list reshuffling under the animation.
    onSettledChanged: {
        if (settled && open && body) {
            body.opened();
        }
    }

    implicitHeight: Math.round(progress * openHeight)
    Layout.fillWidth: true
    visible: progress > 0
    clip: true

    Rectangle {
        anchors {
            fill: parent
            topMargin: panel.gapAbove * panel.progress
        }
        radius: 18
        color: panel.style.panel
        opacity: Math.min(1, panel.progress * 1.5)
    }

    // Laid out once at the open size and never again while the panel moves;
    // only the transform changes from frame to frame.
    ColumnLayout {
        id: content
        x: 14
        y: (panel.gapAbove + 12) * panel.progress
        width: panel.width - 28
        height: Math.max(0, panel.openHeight - panel.gapAbove - 24)
        spacing: 6
        opacity: Math.min(1, panel.progress * 1.5)

        layer.enabled: panel.progress > 0 && panel.progress < 1
        layer.smooth: true

        transform: Scale {
            origin.y: 0
            yScale: panel.progress
        }

        RowLayout {
            spacing: 12
            Layout.bottomMargin: 4

            Rectangle {
                implicitWidth: 34
                implicitHeight: 34
                radius: 17
                color: panel.style.accent

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: panel.body ? panel.body.iconName : ""
                    fallback: panel.body ? panel.body.fallbackIconName : ""
                    isMask: true
                    color: panel.style.accentText
                }
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: panel.body ? panel.body.title : ""
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            Loader {
                active: panel.body !== null && panel.body.busy === true
                visible: active
                sourceComponent: PlasmaComponents.BusyIndicator {
                    implicitWidth: 22
                    implicitHeight: 22
                    running: true
                }
            }
        }

        Flickable {
            id: scroller
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: bodyHost.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            T.ScrollBar.vertical: PlasmaComponents.ScrollBar {
                id: scrollBar
            }

            ColumnLayout {
                id: bodyHost
                // Clear of the scroll bar, which otherwise sits on top of the
                // row actions.
                width: scroller.width - (scroller.interactive ? scrollBar.width + 4 : 0)
                spacing: 0

                Repeater {
                    model: Object.keys(panel.panels)
                    delegate: Loader {
                        required property string modelData

                        Layout.fillWidth: true
                        // In the background, unless it is wanted this instant.
                        asynchronous: panel.shownKey !== modelData
                        active: panel.preload || panel.shownKey === modelData
                        visible: panel.shownKey === modelData && status === Loader.Ready
                        sourceComponent: panel.panels[modelData]
                        onLoaded: panel.bodies = Object.assign({}, panel.bodies, { [modelData]: item })
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            implicitHeight: 1
            color: panel.style.rule
        }

        T.AbstractButton {
            id: footer
            Layout.fillWidth: true
            implicitHeight: footerLabel.implicitHeight + 8
            Accessible.name: footerLabel.text
            Accessible.role: Accessible.Button
            onClicked: {
                if (panel.body) {
                    panel.body.footerAction();
                }
            }

            contentItem: PlasmaComponents.Label {
                id: footerLabel
                leftPadding: 2
                text: panel.body ? panel.body.footerText : ""
                opacity: footer.hovered ? 1 : 0.85
                font.underline: footer.visualFocus
                verticalAlignment: Text.AlignVCenter
                textFormat: Text.PlainText
            }
        }
    }
}
