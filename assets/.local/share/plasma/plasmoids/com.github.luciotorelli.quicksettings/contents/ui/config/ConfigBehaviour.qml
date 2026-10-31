import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_animatePanels: animatePanels.checked
    property alias cfg_animationDuration: animationDuration.value

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: animatePanels
            Kirigami.FormData.label: i18n("Opening a panel:")
            text: i18n("Animate panels opening and closing")
        }
        QQC2.SpinBox {
            id: animationDuration
            Kirigami.FormData.label: i18n("Animation length:")
            enabled: animatePanels.checked
            from: 0
            to: 600
            stepSize: 10
            textFromValue: (value, locale) => i18n("%1 ms", value)
            valueFromText: (text, locale) => parseInt(text, 10)
        }
        QQC2.Label {
            text: i18n("Around 150 to 250 feels responsive; higher starts to feel sluggish.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }
    }
}
