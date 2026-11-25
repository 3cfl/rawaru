pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as C

StepPage {
    id: page

    required property var logModel

    index: 6
    showHeader: false

    readonly property real value: app.backend.progress
    readonly property var stages: [
        { at: 0.0, label: "Prepare disk", icon: "hard_drive" },
        { at: 0.05, label: "Copy system", icon: "download" },
        { at: 0.45, label: "Configure", icon: "tune" },
        { at: 0.83, label: "Bootloader", icon: "rocket_launch" },
        { at: 0.92, label: "Finish", icon: "check_circle" }
    ]
    readonly property int stage: {
        let s = 0
        for (let i = 0; i < stages.length; i++)
            if (value >= stages[i].at) s = i
        return s
    }
    readonly property var tips: [
        ["tawaki install spotify", "One command for every app. tawaki picks pacman, Flathub or the AUR for you."],
        ["tawaki update", "Updates system packages, Flatpaks and AUR packages together."],
        ["Snapshots", "Btrfs snapshots are taken before every update, so a bad one can be rolled back."],
        ["Flatpak and AUR", "Flathub and the AUR are set up already. tawaki search finds apps in both."]
    ]
    property int tipIndex: 0

    Timer {
        interval: 7000
        running: page.active
        repeat: true
        onTriggered: page.tipIndex = (page.tipIndex + 1) % page.tips.length
    }

    Column {
        id: head
        width: parent.width
        spacing: 20

        Row {
            spacing: 20
            LoadingIndicator {
                id: spinner
                width: 64
                height: 64
                contained: true
                running: page.active
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Txt {
                    text: "installing fiordland"
                    role: Theme.headlineL
                    emphasized: true
                }
                Txt {
                    text: page.app.backend.status || "Starting"
                    role: Theme.bodyL
                    color: Theme.inkSurfaceVariant
                }
            }
        }

        Item {
            width: parent.width
            height: 40
            ProgressWavy {
                anchors.left: parent.left
                anchors.right: pct.left
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                value: page.value
                running: page.active
            }
            Txt {
                id: pct
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 64
                horizontalAlignment: Text.AlignRight
                text: Math.round(page.value * 100) + "%"
                role: Theme.titleL
                emphasized: true
                color: Theme.primary
                font.features: { "tnum": 1 }
            }
        }

        Flow {
            width: parent.width
            spacing: 8
            Repeater {
                model: page.stages
                Chip {
                    id: chip
                    required property var modelData
                    required property int index
                    text: modelData.label
                    icon: index < page.stage ? "check" : modelData.icon
                    tonal: index <= page.stage
                    tint: index === page.stage ? Theme.inkPrimaryContainer : (index < page.stage ? Theme.inkSecondaryContainer : Theme.inkSurfaceVariant)
                    opacity: index > page.stage ? 0.6 : 1
                }
            }
        }
    }

    Card {
        id: tipCard
        anchors.top: head.bottom
        anchors.topMargin: 24
        width: parent.width
        height: page.app.logOpen ? 0 : 92
        visible: height > 1
        clip: true
        Behavior on height {
            enabled: Motion.animate
            SpringAnimation { spring: Motion.defaultSpring; damping: Motion.defaultDamping; epsilon: 0.5 }
        }
        ExpressiveShape {
            x: 20
            y: 22
            width: 48
            height: 48
            lobes: 6
            depth: 0.08
            color: Theme.tertiaryContainer
            Icon {
                anchors.centerIn: parent
                name: "lightbulb"
                fill: 1
                color: Theme.inkTertiaryContainer
            }
        }
        Column {
            id: tipBody
            x: 88
            y: 20
            width: parent.width - x - 20
            spacing: 4
            Txt {
                text: page.tips[page.tipIndex][0]
                role: Theme.titleS
                font.family: Theme.mono
                color: Theme.tertiary
            }
            Txt {
                width: parent.width
                text: page.tips[page.tipIndex][1]
                role: Theme.bodyM
                color: Theme.inkSurfaceVariant
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }

    Card {
        id: logCard
        anchors.top: tipCard.bottom
        anchors.topMargin: tipCard.visible ? 16 : 0
        width: parent.width
        height: page.app.logOpen ? Math.max(56, page.height - y) : 56
        color: Theme.alpha(Theme.surfaceContainerLowest, Theme.lowEnd ? 0.9 : 0.6)

        ListItem {
            id: logHead
            width: parent.width
            height: 56
            icon: "terminal"
            headline: page.app.logOpen ? "Hide details" : "Show details"
            supporting: ""
            onClicked: page.app.logOpen = !page.app.logOpen
            Icon {
                name: "expand_more"
                rotation: page.app.logOpen ? 180 : 0
                Behavior on rotation {
                    enabled: Motion.animate
                    SpringAnimation { spring: Motion.fastSpring; damping: Motion.fastDamping; epsilon: 0.5 }
                }
            }
        }

        ListView {
            id: log
            anchors.top: logHead.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            anchors.topMargin: 0
            visible: page.app.logOpen
            clip: true
            model: page.logModel
            boundsBehavior: Flickable.StopAtBounds
            onCountChanged: Qt.callLater(positionViewAtEnd)
            C.ScrollBar.vertical: C.ScrollBar {
                policy: C.ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.outline; opacity: 0.5 }
            }
            delegate: Txt {
                required property string line
                width: log.width - 10
                text: line
                role: Theme.bodyS
                font.family: Theme.mono
                color: Theme.inkSurfaceVariant
                elide: Text.ElideRight
            }
        }
    }
}
