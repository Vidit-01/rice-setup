import QtQuick 2.5

Rectangle {
    id: root
    color: "#090a10"

    property int stage

    onStageChanged: {
        if (stage == 1) introAnimation.running = true
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#11111b" }
                GradientStop { position: 0.55; color: "#090a10" }
                GradientStop { position: 1.0; color: "#101018" }
            }
        }

        Rectangle {
            width: Math.min(parent.width, parent.height) * 0.66
            height: width
            radius: width / 2
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -parent.height * 0.09
            color: "#18e51c45"
        }

        Image {
            id: logo
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -parent.height * 0.09
            width: Math.min(parent.width * 0.40, parent.height * 0.44)
            height: width * 0.722
            source: "images/logo.png"
            sourceSize.width: 877
            sourceSize.height: 633
            fillMode: Image.PreserveAspectFit
            smooth: true

            SequentialAnimation on scale {
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 1.025; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.025; to: 1.0; duration: 1800; easing.type: Easing.InOutSine }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: logo.bottom
            anchors.topMargin: parent.height * 0.065
            text: "Welcome back"
            color: "#f4f1f5"
            font.pixelSize: Math.max(22, parent.height * 0.035)
            font.weight: Font.DemiBold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: parent.height * 0.235
            text: "Starting KDE Plasma"
            color: "#aaa6b5"
            font.pixelSize: Math.max(13, parent.height * 0.018)
            font.letterSpacing: 0.4
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: parent.height * 0.285
            spacing: 8

            Repeater {
                model: 3
                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: index == 1 ? "#ff557b" : "#a92d59"
                    opacity: 0.35

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 180 }
                        NumberAnimation { from: 0.35; to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 1.0; to: 0.35; duration: 500; easing.type: Easing.InOutQuad }
                        PauseAnimation { duration: (2 - index) * 180 }
                    }
                }
            }
        }
    }

    OpacityAnimator {
        id: introAnimation
        running: false
        target: content
        from: 0
        to: 1
        duration: 900
        easing.type: Easing.InOutQuad
    }
}
