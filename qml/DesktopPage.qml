pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as C

StepPage {
    id: page

    index: 4
    overline: "Step 4 of 5"
    title: "pick a desktop"
    subtitle: "You can add others later with tawaki."

    readonly property var list: app.backend.desktops.filter(d => (d.kind === "wm") === app.wmTab)
    readonly property bool split: app.wmTab && !!app.desktopSel && app.desktopSel.kind === "wm" && app.desktopSel.shells.length > 0
    readonly property int cols: split ? 1 : (width >= 700 ? 2 : 1)

    Item {
        id: topBar
        width: parent.width
        height: 48

        Segmented {
            anchors.verticalCenter: parent.verticalCenter
            model: [{ value: "desktops", label: "Desktops", icon: "desktop_windows" }, { value: "wm", label: "Window managers", icon: "grid_view" }]
            current: page.app.wmTab ? "wm" : "desktops"
            onPicked: (v) => page.app.wmTab = v === "wm"
        }

        Card {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: lightRow.implicitWidth + 36
            height: 48
            radius: 24
            interactive: true
            onClicked: page.app.setLowEnd(!page.app.lowend)
            Row {
                id: lightRow
                anchors.centerIn: parent
                spacing: 10
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "eco"
                    size: 20
                    fill: page.app.lowend ? 1 : 0
                    color: page.app.lowend ? Theme.tertiary : Theme.inkSurfaceVariant
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Low-end PC"
                    role: Theme.labelL
                }
                Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: page.app.lowend
                    onToggled: (v) => page.app.setLowEnd(v)
                }
            }
        }
    }

    Row {
        id: hint
        anchors.top: topBar.bottom
        anchors.topMargin: page.app.lowend ? 12 : 0
        height: page.app.lowend ? 20 : 0
        spacing: 8
        clip: true
        visible: height > 0
        Icon { name: "info"; size: 18; color: Theme.tertiary }
        Txt {
            text: "Lighter defaults: no gaming tools or 32-bit libraries, and a light desktop is suggested."
            role: Theme.bodyM
            color: Theme.inkSurfaceVariant
        }
    }

    Card {
        id: listCard
        anchors.top: hint.bottom
        anchors.topMargin: 14
        anchors.bottom: parent.bottom
        width: page.split ? Math.round(parent.width * 0.42) : parent.width
        Behavior on width {
            enabled: Motion.animate
            SpringAnimation { spring: Motion.defaultSpring; damping: Motion.defaultDamping; epsilon: 0.5 }
        }

        GridView {
            id: grid
            anchors.fill: parent
            anchors.margins: 8
            clip: true
            cellWidth: Math.floor(width / page.cols)
            cellHeight: 80
            boundsBehavior: Flickable.StopAtBounds
            model: page.list
            C.ScrollBar.vertical: C.ScrollBar {
                policy: C.ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.outline; opacity: 0.5 }
            }
            delegate: Item {
                id: cell
                required property var modelData
                width: grid.cellWidth
                height: grid.cellHeight
                ListItem {
                    anchors.fill: parent
                    anchors.margins: 2
                    leading: "radio"
                    selected: page.app.desktop === cell.modelData.id
                    headline: cell.modelData.name
                    supporting: cell.modelData.desc
                    supportingLines: 1
                    badge: cell.modelData.recommended && !page.app.lowend ? "Recommended"
                        : cell.modelData.light && page.app.lowend ? "Light" : ""
                    badgeColor: cell.modelData.recommended && !page.app.lowend ? Theme.primaryContainer : Theme.tertiaryContainer
                    badgeInk: cell.modelData.recommended && !page.app.lowend ? Theme.inkPrimaryContainer : Theme.inkTertiaryContainer
                    onClicked: page.app.pickDesktop(cell.modelData)
                }
            }
        }
    }

    Column {
        anchors.top: listCard.top
        anchors.left: listCard.right
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 10
        visible: page.split
        opacity: page.split ? 1 : 0
        Behavior on opacity {
            enabled: Motion.animate
            NumberAnimation { duration: Motion.durMedium }
        }
        Txt {
            text: "Shell for " + (page.app.desktopSel ? page.app.desktopSel.name : "")
            role: Theme.titleM
        }
        Card {
            width: parent.width
            height: parent.height - 34
            Flickable {
                anchors.fill: parent
                anchors.margins: 8
                contentHeight: shells.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                C.ScrollBar.vertical: C.ScrollBar {
                    policy: C.ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.outline; opacity: 0.5 }
                }
                Column {
                    id: shells
                    width: parent.width - 6
                    spacing: 2
                    Repeater {
                        model: page.app.desktopSel ? page.app.desktopSel.shells : []
                        ListItem {
                            required property var modelData
                            width: shells.width
                            leading: "radio"
                            selected: page.app.dots === modelData.id
                            headline: modelData.name
                            supporting: (modelData.by !== "" ? modelData.by + ". " : "") + modelData.desc
                                + (modelData.script ? " Installs on first login with its own setup script." : "")
                            supportingLines: 3
                            onClicked: page.app.dots = modelData.id
                        }
                    }
                }
            }
        }
    }
}
