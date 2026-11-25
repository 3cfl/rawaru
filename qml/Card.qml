import QtQuick

Item {
    id: card

    property color color: Theme.cardFill
    property real radius: Theme.xl
    property int elevation: 0
    property bool selected: false
    property bool interactive: false
    property bool outlined: false
    property bool ice: true
    property bool danger: false
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    default property alias content: body.data

    signal clicked

    activeFocusOnTab: interactive && enabled
    Keys.onSpacePressed: card.clicked()
    Keys.onReturnPressed: card.clicked()
    Keys.onEnterPressed: card.clicked()

    Elevation {
        anchors.fill: parent
        radius: card.radius
        level: card.elevation
    }

    Rectangle {
        anchors.fill: parent
        radius: card.radius
        color: card.selected ? (card.danger ? Theme.alpha(Theme.errorContainer, 0.55) : Theme.cardSelected) : card.color
        border.width: card.selected || card.outlined ? 1 : 0
        border.color: card.selected ? (card.danger ? Theme.error : Theme.alpha(Theme.primary, 0.55)) : Theme.outlineVariant
        Behavior on color {
            enabled: Motion.animate
            ColorAnimation { duration: Motion.durMedium; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standard }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: card.radius
        color: Theme.inkSurface
        opacity: !card.interactive || !card.enabled ? 0 : card.pressed ? Motion.statePressed : card.hovered ? Motion.stateHover : 0
        Behavior on opacity {
            enabled: Motion.animate
            NumberAnimation { duration: Motion.durShort }
        }
    }

    Item {
        visible: card.ice
        width: parent.width
        height: Math.max(1, card.radius)
        clip: true
        Rectangle {
            width: card.width
            height: card.height
            radius: card.radius
            color: "transparent"
            border.width: 1
            border.color: Theme.iceStroke
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: card.interactive && card.enabled
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            card.forceActiveFocus()
            card.clicked()
        }
    }

    Item {
        id: body
        anchors.fill: parent
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: card.radius + 3
        color: "transparent"
        border.width: 2
        border.color: Theme.primary
        visible: card.activeFocus && card.interactive
    }
}
