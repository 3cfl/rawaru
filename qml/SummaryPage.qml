pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as C

StepPage {
    id: page

    index: 5
    overline: "Step 5 of 5"
    title: "ready to install"
    subtitle: "Check everything below. Nothing has changed on your computer yet."

    readonly property int cols: width >= 640 ? 2 : 1
    readonly property var tiles: [
        { icon: "translate", label: "Language", value: app.localeName(app.sysLocale), step: 1 },
        { icon: "schedule", label: "Time zone and keyboard", value: app.timezone.replace(/_/g, " ") + "  ·  " + app.keymapName(app.keymap), step: 1 },
        { icon: "hard_drive", label: "Disk", value: app.diskSummary, step: 2, danger: app.mode === "erase" || app.mode === "manual" },
        { icon: "person", label: "Account", value: (app.fullname ? app.fullname + ", " : "") + app.username + "@" + app.hostname + (app.autologin ? ", automatic login" : ""), step: 3 },
        { icon: "desktop_windows", label: "Desktop", value: app.desktopSel ? app.desktopSel.name + (app.shellSel && app.shellSel.id !== "none" ? " with " + app.shellSel.name : "") : "", step: 4 },
        { icon: "developer_board", label: "Graphics", value: app.backend.graphics, step: -1 }
    ]
    readonly property var kernels: {
        const out = [{ value: "cachyos", label: "CachyOS", icon: "bolt" }, { value: "arch", label: "Arch", icon: "deployed_code" }]
        if (app.backend.fiordKernel)
            out.push({ value: "fiord", label: "Fiordland", icon: "landscape" })
        return out
    }
    readonly property var kernelText: ({
        cachyos: "Tuned for responsiveness and games. The Arch kernel stays installed as a backup boot option.",
        arch: "The stock Arch Linux kernel, nothing else added.",
        fiord: "Fiordland's own kernel, built and tested for this release. The Arch kernel stays as a backup."
    })

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

            Grid {
                id: grid
                width: parent.width
                columns: page.cols
                columnSpacing: 12
                rowSpacing: 12
                Repeater {
                    model: page.tiles
                    Card {
                        id: tile
                        required property var modelData
                        width: (grid.width - (page.cols - 1) * 12) / page.cols
                        height: 84
                        interactive: modelData.step >= 0
                        onClicked: page.app.go(modelData.step)
                        ExpressiveShape {
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44
                            height: 44
                            lobes: 4
                            depth: 0.0
                            color: tile.modelData.danger ? Theme.errorContainer : Theme.alpha(Theme.secondaryContainer, 0.9)
                            Icon {
                                anchors.centerIn: parent
                                name: tile.modelData.icon
                                color: tile.modelData.danger ? Theme.inkErrorContainer : Theme.inkSecondaryContainer
                            }
                        }
                        Column {
                            x: 74
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - (edit.visible ? 56 : 18)
                            spacing: 2
                            Txt {
                                text: tile.modelData.label
                                role: Theme.labelL
                                color: tile.modelData.danger ? Theme.error : Theme.primary
                            }
                            Txt {
                                width: parent.width
                                text: tile.modelData.value
                                role: Theme.bodyM
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                lineHeightMode: Text.ProportionalHeight
                                lineHeight: 1.1
                            }
                        }
                        Icon {
                            id: edit
                            visible: tile.interactive
                            anchors.right: parent.right
                            anchors.rightMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            name: "edit"
                            size: 20
                            opacity: tile.hovered ? 1 : 0.6
                        }
                    }
                }
            }

            Txt {
                text: "System"
                role: Theme.titleM
            }

            Card {
                width: parent.width
                height: sys.height + 32
                Column {
                    id: sys
                    x: 20
                    y: 16
                    width: parent.width - 40
                    spacing: 14

                    Row {
                        spacing: 12
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: "memory"; color: Theme.primary }
                        Txt { anchors.verticalCenter: parent.verticalCenter; text: "Kernel"; role: Theme.titleS }
                    }
                    Segmented {
                        model: page.kernels
                        current: page.app.kernel
                        onPicked: (v) => page.app.kernel = v
                    }
                    Txt {
                        width: parent.width
                        text: page.kernelText[page.app.kernel] || ""
                        role: Theme.bodyM
                        color: Theme.inkSurfaceVariant
                        wrapMode: Text.WordWrap
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.outlineVariant; opacity: 0.6 }

                    ListItem {
                        x: -16
                        width: parent.width + 32
                        icon: "eco"
                        headline: "Low-end PC"
                        supporting: page.app.lowend ? "Lighter defaults: no gaming tools or 32-bit libraries." : "Off. Gaming tools and 32-bit libraries are included."
                        supportingLines: 1
                        onClicked: page.app.setLowEnd(!page.app.lowend)
                        Switch {
                            checked: page.app.lowend
                            onToggled: (v) => page.app.setLowEnd(v)
                        }
                    }

                    Column {
                        visible: page.app.greeterOffered
                        width: parent.width
                        spacing: 14
                        Rectangle { width: parent.width; height: 1; color: Theme.outlineVariant; opacity: 0.6 }
                        Row {
                            spacing: 12
                            Icon { anchors.verticalCenter: parent.verticalCenter; name: "login"; color: Theme.primary }
                            Txt { anchors.verticalCenter: parent.verticalCenter; text: "Login screen"; role: Theme.titleS }
                        }
                        Segmented {
                            model: [{ value: "crest", label: "crest greeter" }, { value: "", label: "Text greeter" }]
                            current: page.app.greeter
                            onPicked: (v) => page.app.greeter = v
                        }
                    }
                }
            }
        }
    }
}
