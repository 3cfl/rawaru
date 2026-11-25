import QtQuick

Item {
    id: btn

    property string icon
    property string variant: "standard"
    property bool checkable: false
    property bool checked: false
    property int size: 40
    property color tint: Theme.onSurfaceVariant
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    signal clicked

    readonly property color container: variant === "filled" ? (checked || !checkable ? Theme.primary : Theme.surfaceContainerHighest)
        : variant === "tonal" ? (checked ? Theme.secondary : Theme.secondaryContainer)
        : checked ? Theme.secondaryContainer : "transparent"
    readonly property color content: variant === "filled" ? (checked || !checkable ? Theme.onPrimary : Theme.primary)
        : variant === "tonal" ? (checked ? Theme.surface : Theme.onSecondaryContainer)
        : checked ? Theme.onSecondaryContainer : tint

    implicitWidth: size
    implicitHeight: size
    activeFocusOnTab: enabled
    Keys.onSpacePressed: btn.clicked()
    Keys.onReturnPressed: btn.clicked()

    Rectangle {
        id: shape
        anchors.fill: parent
        radius: btn.pressed ? Theme.sm : btn.checked ? Theme.md : height / 2
        color: btn.container
        border.width: btn.variant === "outlined" ? 1 : 0
        border.color: Theme.outlineVariant
        Behavior on radius {
            enabled: Motion.animate
            SpringAnimation { spring: Motion.fastSpring; damping: Motion.fastDamping; epsilon: 0.1 }
        }
        Behavior on color {
            enabled: Motion.animate
            ColorAnimation { duration: Motion.durShort }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: shape.radius
        color: btn.content
        opacity: btn.pressed ? Motion.statePressed : btn.hovered ? Motion.stateHover : btn.activeFocus ? Motion.stateFocus : 0
    }

    Icon {
        anchors.centerIn: parent
        name: btn.icon
        size: Math.round(btn.size * 0.6)
        fill: btn.checked ? 1 : 0
        color: btn.content
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
