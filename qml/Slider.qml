import QtQuick

Item {
    id: slider

    property real from: 0
    property real to: 1
    property real value: 0
    property real stepSize: 0
    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    readonly property bool pressed: mouse.pressed

    signal moved(real value)

    implicitWidth: 320
    implicitHeight: 44
    activeFocusOnTab: true
    Keys.onLeftPressed: emitAt(value - (stepSize || (to - from) / 50))
    Keys.onRightPressed: emitAt(value + (stepSize || (to - from) / 50))

    function emitAt(v) {
        let x = Math.max(from, Math.min(to, v))
        if (stepSize > 0)
            x = from + Math.round((x - from) / stepSize) * stepSize
        slider.moved(Math.max(from, Math.min(to, x)))
    }

    readonly property real trackH: 16
    readonly property real handleW: pressed ? 2 : 4
    readonly property real handleX: ratio * (width - 4)

    Rectangle {
        x: 0
        width: Math.max(0, slider.handleX - 6)
        height: slider.trackH
        anchors.verticalCenter: parent.verticalCenter
        radius: Theme.md
        color: Theme.primary
        visible: width > 0
    }
    Rectangle {
        x: slider.handleX + 4 + 6
        width: Math.max(0, slider.width - x)
        height: slider.trackH
        anchors.verticalCenter: parent.verticalCenter
        radius: Theme.md
        color: Theme.secondaryContainer
        visible: width > 0
        Rectangle {
            width: 4
            height: 4
            radius: 2
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.primary
        }
    }
    Rectangle {
        x: slider.handleX + (4 - slider.handleW) / 2
        width: slider.handleW
        height: 44
        radius: 2
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.primary
        Behavior on width {
            enabled: Motion.animate
            SpringAnimation { spring: Motion.fastSpring; damping: Motion.fastDamping; epsilon: 0.05 }
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: Theme.lg
        color: "transparent"
        border.width: 2
        border.color: Theme.primary
        visible: slider.activeFocus && !mouse.containsMouse
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: (m) => { slider.forceActiveFocus(); slider.emitAt(slider.from + (m.x / slider.width) * (slider.to - slider.from)) }
        onPositionChanged: (m) => { if (pressed) slider.emitAt(slider.from + (m.x / slider.width) * (slider.to - slider.from)) }
    }
}
