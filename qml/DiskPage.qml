pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as C

StepPage {
    id: page

    index: 2
    overline: "Step 2 of 5"
    title: "choose a disk"
    subtitle: "Fiordland gets its own space. Nothing is written until you press Install."

    readonly property var disks: app.backend.disks
    readonly property int cols: Math.max(1, Math.min(disks.length, Math.floor((width + 12) / 232)))

    function diskIcon(kind) {
        return kind === "usb" ? "usb" : kind === "nvme" ? "memory_alt" : "hard_drive"
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.height + 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        C.ScrollBar.vertical: C.ScrollBar {
            policy: C.ScrollBar.AsNeeded
            contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.outline; opacity: 0.5 }
        }

        Column {
            id: col
            width: flick.width - 8
            spacing: 20

            Flow {
                width: parent.width
                spacing: 12
                Repeater {
                    model: page.disks
                    Card {
                        id: dcard
                        required property var modelData
                        readonly property bool chosen: page.app.disk === modelData.path
                        width: (col.width - (page.cols - 1) * 12) / page.cols
                        height: 116
                        interactive: modelData.big
                        enabled: modelData.big
                        selected: chosen
                        opacity: modelData.big ? 1 : 0.5
                        onClicked: page.app.pickDisk(modelData.path)

                        ExpressiveShape {
                            x: 18
                            y: 18
                            width: 44
                            height: 44
                            lobes: dcard.chosen ? 9 : 4
                            depth: dcard.chosen ? 0.07 : 0.0
                            color: dcard.chosen ? Theme.primary : Theme.alpha(Theme.secondaryContainer, 0.9)
                            Icon {
                                anchors.centerIn: parent
                                name: page.diskIcon(dcard.modelData.kind)
                                fill: dcard.chosen ? 1 : 0
                                color: dcard.chosen ? Theme.inkPrimary : Theme.inkSecondaryContainer
                            }
                        }
                        Txt {
                            anchors.right: parent.right
                            anchors.rightMargin: 20
                            y: 22
                            text: dcard.modelData.sizeText
                            role: Theme.titleL
                            emphasized: true
                            color: dcard.chosen ? Theme.inkPrimaryContainer : Theme.inkSurface
                        }
                        Column {
                            x: 18
                            y: 70
                            width: parent.width - 36
                            spacing: 0
                            Txt {
                                width: parent.width
                                text: dcard.modelData.model
                                role: Theme.titleS
                                elide: Text.ElideRight
                                color: dcard.chosen ? Theme.inkPrimaryContainer : Theme.inkSurface
                            }
                            Txt {
                                width: parent.width
                                text: dcard.modelData.path + "  ·  " + (dcard.modelData.big
                                    ? (dcard.modelData.parts > 0 ? dcard.modelData.parts + " partition" + (dcard.modelData.parts > 1 ? "s" : "") : "empty")
                                    : "needs 20 GB")
                                role: Theme.bodyS
                                font.family: Theme.mono
                                elide: Text.ElideRight
                                color: Theme.inkSurfaceVariant
                            }
                        }
                    }
                }
            }

            Card {
                visible: page.disks.length === 0
                width: parent.width
                height: 120
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "hard_drive"; size: 32 }
                    Txt { text: "No disks found. Plug one in and it shows up here."; role: Theme.bodyM; color: Theme.inkSurfaceVariant }
                }
            }

            Row {
                visible: page.app.disk !== "" && page.app.probing
                spacing: 14
                height: 56
                LoadingIndicator {
                    width: 44
                    height: 44
                    anchors.verticalCenter: parent.verticalCenter
                    running: parent.visible
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Looking at what's on this disk"
                    role: Theme.bodyL
                    color: Theme.inkSurfaceVariant
                }
            }

            Column {
                visible: page.app.disk !== "" && !page.app.probing
                width: parent.width
                spacing: 10

                Txt {
                    text: "How should Fiordland use it"
                    role: Theme.titleM
                }

                Card {
                    width: parent.width
                    height: options.height + 16
                    Column {
                        id: options
                        x: 8
                        y: 8
                        width: parent.width - 16
                        spacing: 4

                        Repeater {
                            model: page.app.probing || !page.app.probe ? [] : page.app.probe.options
                            Column {
                                id: opt
                                required property var modelData
                                required property int index
                                readonly property bool on: page.app.mode === "alongside" && page.app.optIndex === index
                                width: options.width
                                spacing: 0
                                ListItem {
                                    width: parent.width
                                    leading: "radio"
                                    selected: opt.on
                                    headline: opt.modelData.kind === "shrink"
                                        ? "Install alongside " + (page.app.probe.system || opt.modelData.label)
                                        : "Install in the free space"
                                    supporting: opt.modelData.kind === "shrink"
                                        ? "Shrinks " + opt.modelData.label + " (" + opt.modelData.part + ") to make room. Nothing is deleted, and you pick the system when the computer starts."
                                        : page.app.gb(opt.modelData.max) + " of unused space. Nothing else on the disk is touched."
                                    badge: opt.index === 0 ? "Keeps your files" : ""
                                    onClicked: page.app.pickOption(opt.index)
                                }
                                Item {
                                    visible: opt.on
                                    width: parent.width
                                    height: visible ? 112 : 0
                                    Row {
                                        id: split
                                        x: 56
                                        y: 8
                                        width: parent.width - 72
                                        height: 28
                                        spacing: 4
                                        readonly property real total: opt.modelData.kind === "shrink" ? opt.modelData.partSize : opt.modelData.max
                                        readonly property real share: total > 0 ? page.app.fiordSize / total : 1
                                        Rectangle {
                                            visible: opt.modelData.kind === "shrink"
                                            width: Math.max(0, (split.width - 4) * (1 - split.share))
                                            height: parent.height
                                            radius: Theme.sm
                                            color: Theme.secondaryContainer
                                            Txt {
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: 10
                                                width: parent.width - 20
                                                elide: Text.ElideRight
                                                text: opt.modelData.label + "  " + page.app.gb(opt.modelData.partSize - page.app.fiordSize)
                                                role: Theme.labelM
                                                color: Theme.inkSecondaryContainer
                                            }
                                        }
                                        Rectangle {
                                            width: opt.modelData.kind === "shrink" ? (split.width - 4) * split.share : split.width
                                            height: parent.height
                                            radius: Theme.sm
                                            color: Theme.primary
                                            Txt {
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: 10
                                                width: parent.width - 20
                                                elide: Text.ElideRight
                                                text: "Fiordland  " + page.app.gb(page.app.fiordSize)
                                                role: Theme.labelM
                                                color: Theme.inkPrimary
                                            }
                                        }
                                    }
                                    Slider {
                                        x: 56
                                        y: 52
                                        width: parent.width - 72
                                        from: opt.modelData.min
                                        to: opt.modelData.max
                                        value: page.app.fiordSize
                                        stepSize: 1000000000
                                        onMoved: (v) => page.app.fiordSize = v
                                    }
                                }
                            }
                        }

                        Column {
                            width: options.width
                            spacing: 0
                            ListItem {
                                width: parent.width
                                leading: "radio"
                                selected: page.app.mode === "manual"
                                headline: "Choose partitions"
                                supporting: "Pick the partition for Fiordland yourself. Only that partition is formatted."
                                onClicked: page.app.pickManual()
                            }
                            Column {
                                visible: page.app.mode === "manual"
                                x: 40
                                width: parent.width - 48
                                spacing: 2
                                topPadding: 6
                                bottomPadding: 10
                                Txt { x: 16; text: "Install Fiordland on"; role: Theme.labelL; color: Theme.primary }
                                Repeater {
                                    model: page.app.mode === "manual" ? page.app.usableParts : []
                                    ListItem {
                                        required property var modelData
                                        width: parent.width
                                        implicitHeight: 48
                                        leading: "radio"
                                        selected: page.app.rootPart === modelData.node
                                        headline: page.app.partText(modelData)
                                        onClicked: page.app.pickRoot(modelData.node)
                                    }
                                }
                                Txt {
                                    visible: page.app.usableParts.length === 0
                                    x: 16
                                    width: parent.width - 32
                                    wrapMode: Text.WordWrap
                                    text: "No partition of 16 GB or more. Make one in the partition editor."
                                    role: Theme.bodyM
                                    color: Theme.inkSurfaceVariant
                                }
                                Txt {
                                    visible: page.app.backend.uefi
                                    x: 16
                                    topPadding: 8
                                    text: "Boot files go on"
                                    role: Theme.labelL
                                    color: Theme.primary
                                }
                                Repeater {
                                    model: page.app.mode === "manual" && page.app.backend.uefi ? page.app.espParts : []
                                    ListItem {
                                        required property var modelData
                                        width: parent.width
                                        implicitHeight: 48
                                        leading: "radio"
                                        selected: page.app.espPart === modelData.node
                                        headline: page.app.partText(modelData) + "  (kept, not formatted)"
                                        onClicked: page.app.espPart = modelData.node
                                    }
                                }
                                Txt {
                                    visible: page.app.backend.uefi && page.app.espParts.length === 0
                                    x: 16
                                    width: parent.width - 32
                                    wrapMode: Text.WordWrap
                                    text: "No EFI system partition. Make a 512 MB FAT32 partition with the boot and esp flags."
                                    role: Theme.bodyM
                                    color: Theme.inkSurfaceVariant
                                }
                                Txt {
                                    visible: !page.app.backend.uefi && !!page.app.probe && page.app.probe.gpt && !page.app.probe.biosBoot
                                    x: 16
                                    width: parent.width - 32
                                    wrapMode: Text.WordWrap
                                    text: "This disk needs a 1 MB partition with the bios_grub flag for GRUB. Make one in the partition editor."
                                    role: Theme.bodyM
                                    color: Theme.inkSurfaceVariant
                                }
                                PillButton {
                                    x: 8
                                    visible: page.app.backend.hasPartitionEditor()
                                    variant: "outlined"
                                    icon: "edit"
                                    text: "Partition editor"
                                    onClicked: page.app.backend.openPartitionEditor()
                                }
                            }
                        }

                        ListItem {
                            width: options.width
                            leading: "radio"
                            danger: true
                            selected: page.app.mode === "erase"
                            headline: "Erase the disk"
                            supporting: "Fiordland takes the whole disk. Everything on it is removed, including other systems."
                            onClicked: page.app.pickOption(-1)
                        }
                    }
                }

                Repeater {
                    model: page.app.probing || !page.app.probe ? [] : page.app.probe.notes
                    Row {
                        required property var modelData
                        spacing: 10
                        width: col.width
                        Icon { name: "info"; size: 20; color: Theme.inkSurfaceVariant }
                        Txt {
                            width: parent.width - 30
                            text: parent.modelData
                            role: Theme.bodyM
                            color: Theme.inkSurfaceVariant
                            wrapMode: Text.WordWrap
                            lineHeightMode: Text.ProportionalHeight
                            lineHeight: 1.1
                        }
                    }
                }

                Card {
                    width: parent.width
                    height: 64
                    interactive: true
                    danger: page.app.mode !== "alongside"
                    selected: page.app.understood
                    onClicked: page.app.understood = !page.app.understood
                    ListItem {
                        anchors.fill: parent
                        interactive: false
                        leading: "check"
                        danger: page.app.mode !== "alongside"
                        selected: page.app.understood
                        headline: page.app.confirmText
                    }
                }
            }

            Row {
                spacing: 10
                width: parent.width
                Icon { name: "shield"; size: 20; color: Theme.tertiary }
                Txt {
                    width: parent.width - 30
                    text: "Btrfs with compression, zram swap, and automatic snapshots you can start from the boot menu."
                    role: Theme.bodyM
                    color: Theme.inkSurfaceVariant
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
