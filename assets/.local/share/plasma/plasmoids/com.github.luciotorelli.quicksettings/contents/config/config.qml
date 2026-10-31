import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Pills")
        icon: "view-grid-symbolic"
        source: "config/ConfigPills.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "config/ConfigAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Sliders & Panel")
        icon: "preferences-desktop-display"
        source: "config/ConfigSliders.qml"
    }
    ConfigCategory {
        name: i18n("Behaviour")
        icon: "preferences-system"
        source: "config/ConfigBehaviour.qml"
    }
}
