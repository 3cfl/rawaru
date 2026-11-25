pragma ComponentBehavior: Bound
import QtQuick

Row {
    id: seg

    property var model: []
    property string current
    property int size: 40

    signal picked(string value)

    spacing: 2

    Repeater {
        model: seg.model
        Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool on: seg.current === modelData.value
            readonly property bool first: index === 0
            readonly property bool last: index === seg.model.length - 1
            readonly property real inner: mouse.pressed ? Theme.xs : Theme.sm
            readonly property real outer: height / 2

            width: label.implicitWidth + (cell.on || cell.modelData.icon ? 56 : 40)
            height: seg.size
            activeFocusOnTab: true
            Keys.onSpacePressed: seg.picked(cell.modelData.value)
            Keys.onReturnPressed: seg.picked(cell.modelData.value)

            Behavior on width {
                enabled: Motion.animate
                SpringAnimation { spring: Motion.fastSpring; damping: Motion.fastDamping; epsilon: 0.25 }
            }

            RoundedBox {
                id: box
                anchors.fill: parent
                leftRadius: cell.on || cell.first ? cell.outer : cell.inner
                rightRadius: cell.on || cell.last ? cell.outer : cell.inner
                color: cell.on ? Theme.secondaryContainer : Theme.cardFill
                Behavior on leftRadius {
                    enabled: Motion.animate
                    SpringAnimation { spring: Motion.fastSpring; damping: Motion.fastDamping; epsilon: 0.1 }
                }
                Behavior on rightRadius {
                    enabled: Motion.animate
                    SpringAnimation { spring: Motion.fastSpring; damping: Motion.fastDamping; epsilon: 0.1 }
                }
            }

            RoundedBox {
                anchors.fill: parent
                leftRadius: box.leftRadius
                rightRadius: box.rightRadius
                color: Theme.alpha(Theme.inkSurface, mouse.pressed ? Motion.statePressed : mouse.containsMouse || cell.activeFocus ? Motion.stateHover : 0)
            }

            Row {
                anchors.centerIn: parent
                spacing: 8
                Icon {
                    visible: cell.on || cell.modelData.icon !== undefined
                    anchors.verticalCenter: parent.verticalCenter
                    name: cell.on ? "check" : (cell.modelData.icon || "")
                    size: 18
                    weight: cell.on ? 600 : 400
                    color: cell.on ? Theme.inkSecondaryContainer : Theme.inkSurfaceVariant
                }
                Txt {
                    id: label
                    anchors.verticalCenter: parent.verticalCenter
                    text: cell.modelData.label
                    role: Theme.labelL
                    color: cell.on ? Theme.inkSecondaryContainer : Theme.inkSurface
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: seg.picked(cell.modelData.value)
            }
        }
    }
}
