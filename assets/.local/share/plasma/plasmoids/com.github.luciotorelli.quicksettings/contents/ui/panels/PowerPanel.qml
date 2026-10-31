import QtQuick
import "../components"

PanelBody {
    id: body

    title: i18n("Power Mode")
    iconName: "power-profile-balanced-symbolic"
    fallbackIconName: "battery-profile-balanced"
    footerText: i18n("Power Settings")
    settingsModule: "kcm_powerdevilprofilesconfig"

    Repeater {
        id: list
        model: body.app.power.choices
        delegate: PanelRow {
            required property string modelData

            style: body.style
            iconName: body.app.power.icon(modelData)
            fallbackIconName: "battery-profile-" + (modelData === "power-saver" ? "powersave" : modelData)
            label: body.app.power.label(modelData)
            current: modelData === body.app.power.current
            actionText: current ? i18n("Active") : i18n("Select")
            onActivated: body.app.power.setProfile(modelData)
        }
    }

    PanelNote {
        style: body.style
        visible: list.count === 0
        text: i18n("No power profiles available")
    }
}
