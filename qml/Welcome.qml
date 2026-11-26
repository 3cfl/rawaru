import QtQuick

Item {
    id: welcome

    required property var app
    readonly property bool active: app.step === 0
    readonly property bool roomy: width >= 1100 && height >= 760

    opacity: active ? 1 : 0
    visible: opacity > 0.01
    enabled: active

    Behavior on opacity {
        enabled: Motion.animate
        NumberAnimation { duration: Motion.durLong; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standard }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.alpha(Theme.surface, 0.10) }
            GradientStop { position: 0.45; color: Theme.alpha(Theme.surface, 0.18) }
            GradientStop { position: 1.0; color: Theme.alpha(Theme.surface, 0.92) }
        }
    }

    Row {
        x: 40
        y: 32
        spacing: 12
        Logo {
            size: 36
            anchors.verticalCenter: parent.verticalCenter
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: "fiordland"
            role: Theme.titleL
            emphasized: true
        }
    }

    PillButton {
        anchors.right: parent.right
        anchors.rightMargin: 32
        y: 30
        variant: "glass"
        icon: "translate"
        trailingIcon: "expand_more"
        text: welcome.app.localeName(welcome.app.sysLocale)
        onClicked: welcome.app.openLanguage()
    }

    Column {
        id: hero
        x: welcome.roomy ? 72 : 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: welcome.roomy ? 72 : 48
        width: Math.min(620, parent.width - 96)
        spacing: 0
        transform: Translate {
            y: welcome.active ? 0 : 24
            Behavior on y {
                enabled: Motion.animate
                SpringAnimation { spring: Motion.slowSpring; damping: Motion.slowDamping; epsilon: 0.25 }
            }
        }

        Chip {
            glass: true
            icon: "auto_awesome"
            tint: Theme.tertiary
            text: "Fiordland 1"
        }
        Item { width: 1; height: 20 }
        Txt {
            text: "welcome to"
            role: welcome.roomy ? Theme.displayS : Theme.headlineL
            color: Theme.inkSurfaceVariant
        }
        Txt {
            text: "fiordland"
            role: welcome.roomy ? ({ size: 76, line: 84, weight: 500 }) : Theme.displayL
            emphasized: true
        }
        Item { width: 1; height: 14 }
        Txt {
            width: Math.min(parent.width, 500)
            text: "Install it on this computer, or keep trying it live. Nothing on your disks changes until you say so."
            role: Theme.bodyL
            color: Theme.inkSurfaceVariant
            wrapMode: Text.WordWrap
            lineHeightMode: Text.ProportionalHeight
            lineHeight: 1.3
        }
        Item { width: 1; height: 32 }
        Row {
            spacing: 12
            PillButton {
                size: 56
                icon: "download"
                text: "Install Fiordland"
                onClicked: welcome.app.begin()
            }
            PillButton {
                size: 56
                variant: "glass"
                text: "Keep trying it"
                onClicked: welcome.app.backend.quit()
            }
        }
    }

    Column {
        anchors.right: parent.right
        anchors.rightMargin: 32
        anchors.bottom: parent.bottom
        anchors.bottomMargin: welcome.roomy ? 72 : 48
        spacing: 8
        Chip {
            anchors.right: parent.right
            glass: true
            icon: "memory"
            text: welcome.app.backend.uefi ? "UEFI" : "BIOS"
        }
        Chip {
            anchors.right: parent.right
            glass: true
            icon: "developer_board"
            text: welcome.app.backend.graphics
        }
        Chip {
            anchors.right: parent.right
            visible: welcome.app.backend.dryRun
            glass: true
            icon: "visibility"
            tint: Theme.tertiary
            text: "Preview mode"
        }
    }
}
