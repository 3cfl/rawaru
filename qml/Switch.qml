import QtQuick

Item {
    id: sw

    property bool checked: false
    readonly property bool pressed: mouse.pressed

    signal toggled(bool value)

    implicitWidth: 52
    implicitHeight: 32
    activeFocusOnTab: enabled
    Keys.onSpacePressed: sw.toggled(!sw.checked)
    Keys.onReturnPressed: sw.toggled(!sw.checked)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? Theme.primary : Theme.surfaceContainerHighest
        border.width: sw.checked ? 0 : 2
        border.color: Theme.outline
        opacity: sw.enabled ? 1 : 0.38
        Behavior on color {
            enabled: Motion.animate
            ColorAnimation { duration: Motion.durShort }
        }
    }

    Rectangle {
        id: thumb
        readonly property real d: sw.pressed ? 28 : sw.checked ? 24 : 16
        readonly property real cx: sw.checked ? sw.width - 16 : 16
        width: d
        height: d
        radius: d / 2
        x: cx - d / 2
        y: (sw.height - d) / 2
        color: sw.checked ? Theme.onPrimary : Theme.outline
        Behavior on x {
            enabled: Motion.animate
            SpringAnimation { spring: Motion.fastSpring; damping: Motion.fastDamping; epsilon: 0.1 }
        }
        Behavior on width {
            enabled: Motion.animate
            SpringAnimation { spring: Motion.fastSpring; damping: Motion.fastDamping; epsilon: 0.1 }
        }
        Behavior on height {
            enabled: Motion.animate
            SpringAnimation { spring: Motion.fastSpring; damping: Motion.fastDamping; epsilon: 0.1 }
        }
        Icon {
            anchors.centerIn: parent
            name: "check"
            size: 16
            weight: 600
            color: Theme.onPrimaryContainer
            opacity: sw.checked ? 1 : 0
            Behavior on opacity {
                enabled: Motion.animate
                NumberAnimation { duration: Motion.durShort }
            }
        }
    }

    Rectangle {
        width: 40
        height: 40
        radius: 20
        x: thumb.cx - 20
        y: (sw.height - 40) / 2
        color: sw.checked ? Theme.primary : Theme.onSurface
        opacity: mouse.pressed ? Motion.statePressed : mouse.containsMouse || sw.activeFocus ? Motion.stateHover : 0
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled(!sw.checked)
    }
}
