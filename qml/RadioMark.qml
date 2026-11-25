import QtQuick

Item {
    id: radio

    property bool checked: false
    property color tint: Theme.primary

    implicitWidth: 20
    implicitHeight: 20

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: radio.checked ? radio.tint : Theme.onSurfaceVariant
        Behavior on border.color {
            enabled: Motion.animate
            ColorAnimation { duration: Motion.durShort }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 10
        height: 10
        radius: 5
        color: radio.tint
        scale: radio.checked ? 1 : 0
        Behavior on scale {
            enabled: Motion.animate
            SpringAnimation { spring: Motion.fastSpring; damping: Motion.fastDamping; epsilon: 0.01 }
        }
    }
}
