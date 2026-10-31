import QtQuick
import "../components"

PanelBody {
    id: body

    title: i18n("Sound")
    iconName: "audio-volume-high-symbolic"
    footerText: i18n("Sound Settings")
    settingsModule: "kcm_pulseaudio"

    PanelNote {
        style: body.style
        heading: true
        visible: outputs.count > 0
        text: i18n("Output")
    }
    Repeater {
        id: outputs
        model: body.app.audio.outputs
        delegate: PanelRow {
            required property var model

            style: body.style
            iconName: "audio-speakers-symbolic"
            label: model.Description
            current: model.Default === true
            actionText: current ? i18n("Active") : i18n("Select")
            onActivated: body.app.audio.makeDefault(model.PulseObject)
        }
    }

    PanelNote {
        style: body.style
        heading: true
        visible: inputs.count > 0
        text: i18n("Input")
    }
    Repeater {
        id: inputs
        model: body.app.audio.inputs
        delegate: PanelRow {
            required property var model

            style: body.style
            iconName: "audio-input-microphone-symbolic"
            label: model.Description
            current: model.Default === true
            actionText: current ? i18n("Active") : i18n("Select")
            onActivated: body.app.audio.makeDefault(model.PulseObject)
        }
    }

    PanelNote {
        style: body.style
        visible: outputs.count === 0 && inputs.count === 0
        text: i18n("No audio devices found")
    }
}
