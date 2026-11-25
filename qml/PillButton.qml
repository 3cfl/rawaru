import QtQuick

Item {
    id: btn

    property string text
    property string icon
    property string trailingIcon
    property string variant: "filled"
    property bool danger: false
    property int size: 40
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    signal clicked

    readonly property color container: !enabled ? (variant === "text" || variant === "outlined" ? "transparent" : Theme.alpha(Theme.inkSurface, 0.12))
        : variant === "filled" ? (danger ? Theme.error : Theme.primary)
        : variant === "tonal" ? (danger ? Theme.errorContainer : Theme.secondaryContainer)
        : variant === "glass" ? Theme.glassHigh
        : "transparent"
    readonly property color content: !enabled ? Theme.alpha(Theme.inkSurface, 0.38)
        : variant === "filled" ? (danger ? Theme.inkError : Theme.inkPrimary)
        : variant === "tonal" ? (danger ? Theme.inkErrorContainer : Theme.inkSecondaryContainer)
        : variant === "glass" ? Theme.inkSurface
        : variant === "outlined" ? Theme.inkSurfaceVariant
        : danger ? Theme.error : Theme.primary
    readonly property int pad: size >= 56 ? 28 : 24

    implicitHeight: size
    implicitWidth: row.implicitWidth + (variant === "text" ? 24 : pad * 2 - (icon ? 8 : 0))
    activeFocusOnTab: enabled
    Keys.onSpacePressed: btn.clicked()
    Keys.onReturnPressed: btn.clicked()
    Keys.onEnterPressed: btn.clicked()

    Rectangle {
        id: shape
        anchors.fill: parent
        radius: btn.pressed ? Theme.md : height / 2
        color: btn.container
        border.width: btn.variant === "outlined" ? 1 : 0
        border.color: btn.enabled ? Theme.outlineVariant : Theme.alpha(Theme.inkSurface, 0.12)
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
        opacity: !btn.enabled ? 0 : btn.pressed ? Motion.statePressed : btn.hovered ? Motion.stateHover : btn.activeFocus ? Motion.stateFocus : 0
        Behavior on opacity {
            enabled: Motion.animate
            NumberAnimation { duration: Motion.durShort }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Icon {
            visible: btn.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: btn.icon
            size: btn.size >= 56 ? 24 : 20
            color: btn.content
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: btn.text
            role: btn.size >= 56 ? Theme.titleM : Theme.labelL
            color: btn.content
        }
        Icon {
            visible: btn.trailingIcon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: btn.trailingIcon
            size: btn.size >= 56 ? 24 : 20
            color: btn.content
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: shape.radius + 3
        color: "transparent"
        border.width: 2
        border.color: Theme.primary
        visible: btn.activeFocus && !mouse.containsMouse
    }
}
