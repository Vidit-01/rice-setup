import QtQuick
import "../components"

PanelBody {
    id: body

    title: i18n("Fan Curve")
    iconName: "sensors-fan-symbolic"
    fallbackIconName: "weather-windy-symbolic"
    // No GUI exists for fw-fanctrl, so the footer runs the reset rather than
    // opening something.
    footerText: i18n("Reset to Default")

    function footerAction() {
        app.fan.reset();
    }

    Repeater {
        id: list
        model: body.app.fan.strategies
        delegate: PanelRow {
            required property string modelData

            style: body.style
            iconName: "sensors-fan-symbolic"
            fallbackIconName: "weather-windy-symbolic"
            label: body.app.fan.label(modelData)
            current: modelData === body.app.fan.current
            actionText: current ? i18n("Active") : i18n("Select")
            onActivated: body.app.fan.use(modelData)
        }
    }

    PanelNote {
        style: body.style
        visible: list.count === 0
        text: i18n("fw-fanctrl is not responding")
    }
}
