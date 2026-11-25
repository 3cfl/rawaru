import QtQuick

Rectangle {
    id: check

    property bool checked: false
    property color tint: Theme.primary
    property color ink: Theme.onPrimary

    implicitWidth: 20
    implicitHeight: 20
    radius: checked ? 6 : 4
    color: checked ? tint : "transparent"
    border.width: checked ? 0 : 2
    border.color: Theme.onSurfaceVariant

    Behavior on radius {
        enabled: Motion.animate
        SpringAnimation { spring: Motion.fastSpring; damping: Motion.fastDamping; epsilon: 0.05 }
    }
    Behavior on color {
        enabled: Motion.animate
        ColorAnimation { duration: Motion.durShort }
    }

    Icon {
        anchors.centerIn: parent
        name: "check"
        size: 18
        weight: 700
        color: check.ink
        scale: check.checked ? 1 : 0.4
        opacity: check.checked ? 1 : 0
        Behavior on scale {
            enabled: Motion.animate
            SpringAnimation { spring: Motion.fastSpring; damping: Motion.fastDamping; epsilon: 0.01 }
        }
    }
}
