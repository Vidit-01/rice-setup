import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

KCM.SimpleKCM {
    property alias cfg_pillPadding: pillPadding.value
    property alias cfg_pillRadius: pillRadius.value
    property alias cfg_pillIconSize: pillIconSize.value
    property alias cfg_pillSpacing: pillSpacing.value
    property alias cfg_useThemeAccent: useThemeAccent.checked
    property alias cfg_customAccent: customAccent.color
    property string cfg_textContrast
    property alias cfg_floatingPopup: floatingPopup.checked

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: floatingPopup
            Kirigami.FormData.label: i18n("Popup:")
            text: i18n("Float clear of the panel and the screen edge")
        }
        QQC2.Label {
            leftPadding: floatingPopup.indicator.width + floatingPopup.spacing
            text: i18n("Unless the panel itself is set to floating, Plasma docks a popup against it and squares off the corners that touch. This keeps the gap and the rounded corners all the way round.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.SpinBox {
            id: pillPadding
            Kirigami.FormData.label: i18n("Pill height:")
            from: 4
            to: 22
            textFromValue: (value, locale) => i18np("%1 pixel of padding", "%1 pixels of padding", value)
            valueFromText: (text, locale) => parseInt(text, 10)
        }
        QQC2.SpinBox {
            id: pillRadius
            Kirigami.FormData.label: i18n("Corner rounding:")
            from: 0
            to: 30
            textFromValue: (value, locale) => i18np("%1 pixel", "%1 pixels", value)
            valueFromText: (text, locale) => parseInt(text, 10)
        }
        QQC2.Label {
            text: i18n("0 gives square corners; half the pill height or more gives a full capsule.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
        QQC2.SpinBox {
            id: pillIconSize
            Kirigami.FormData.label: i18n("Icon size:")
            from: 12
            to: 32
            textFromValue: (value, locale) => i18np("%1 pixel", "%1 pixels", value)
            valueFromText: (text, locale) => parseInt(text, 10)
        }
        QQC2.SpinBox {
            id: pillSpacing
            Kirigami.FormData.label: i18n("Gap between pills:")
            from: 0
            to: 20
            textFromValue: (value, locale) => i18np("%1 pixel", "%1 pixels", value)
            valueFromText: (text, locale) => parseInt(text, 10)
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: useThemeAccent
            Kirigami.FormData.label: i18n("Colour:")
            text: i18n("Take the accent colour from the desktop theme")
        }
        KQuickControls.ColorButton {
            id: customAccent
            Kirigami.FormData.label: i18n("Accent colour:")
            enabled: !useThemeAccent.checked
            showAlphaChannel: false
        }
        QQC2.ComboBox {
            id: textContrast
            Kirigami.FormData.label: i18n("Text on an active pill:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Choose automatically"), value: "auto" },
                { text: i18n("Always dark"), value: "dark" },
                { text: i18n("Always light"), value: "light" },
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(cfg_textContrast))
            onActivated: cfg_textContrast = currentValue
        }
        QQC2.Label {
            text: i18n("Automatic picks dark or light from how bright the accent is, which keeps text readable on both a light orange and a dark blue.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }
    }
}
