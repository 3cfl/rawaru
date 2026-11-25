import QtQuick
import QtQuick.Controls.Basic as C

StepPage {
    id: page

    index: 7
    showHeader: false

    readonly property bool failed: app.failed
    property bool saved: false

    onActiveChanged: if (active) saved = false

    Column {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        y: page.failed ? 8 : Math.max(0, (parent.height - height) / 2 - 24)
        width: Math.min(parent.width, 620)
        spacing: 20

        ExpressiveShape {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 112
            height: 112
            lobes: page.failed ? 4 : 12
            depth: page.failed ? 0.05 : 0.07
            spin: 0
            color: page.failed ? Theme.errorContainer : Theme.tertiaryContainer
            scale: page.active ? 1 : 0.6
            Behavior on scale {
                enabled: Motion.animate
                SpringAnimation { spring: Motion.fastSpring; damping: Motion.fastDamping; epsilon: 0.002 }
            }
            Icon {
                anchors.centerIn: parent
                name: page.failed ? "error" : "check"
                size: 48
                weight: 600
                fill: 1
                color: page.failed ? Theme.onErrorContainer : Theme.onTertiaryContainer
            }
        }

        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: page.failed ? "the install stopped" : "fiordland is installed"
            role: Theme.displayS
            emphasized: true
            wrapMode: Text.WordWrap
        }

        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: page.failed ? (page.app.errorText || "Something went wrong.")
                : "Restart and remove the USB stick when the screen goes dark. Your new system will be waiting."
            role: Theme.bodyL
            color: Theme.onSurfaceVariant
            wrapMode: Text.WordWrap
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            PillButton {
                visible: !page.failed
                size: 56
                icon: "restart_alt"
                text: "Restart now"
                onClicked: page.app.backend.reboot()
            }
            PillButton {
                visible: !page.failed
                size: 56
                variant: "tonal"
                text: "Keep exploring"
                onClicked: page.app.backend.quit()
            }
            PillButton {
                visible: page.failed
                size: 56
                icon: "replay"
                text: "Try again"
                onClicked: page.app.go(5)
            }
            PillButton {
                visible: page.failed
                size: 56
                variant: "tonal"
                icon: page.saved ? "check" : "save"
                text: page.saved ? "Saved to ~/rawaru.log" : "Save log"
                onClicked: { page.app.backend.saveLog(); page.saved = true }
            }
        }

        Card {
            visible: page.failed && page.app.errorDetail !== ""
            width: parent.width
            height: Math.min(220, detail.contentHeight + 32)
            color: Theme.alpha(Theme.surfaceContainerLowest, Theme.lowEnd ? 0.9 : 0.6)
            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: 16
                clip: true
                contentHeight: detail.contentHeight
                boundsBehavior: Flickable.StopAtBounds
                C.ScrollBar.vertical: C.ScrollBar {
                    policy: C.ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.outline; opacity: 0.5 }
                }
                TextEdit {
                    id: detail
                    width: flick.width - 8
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    text: page.app.errorDetail
                    color: Theme.onSurfaceVariant
                    selectionColor: Theme.primaryContainer
                    font.family: Theme.mono
                    font.pixelSize: 12
                }
            }
        }
    }
}
