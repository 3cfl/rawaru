pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: shadow

    property real radius: Theme.xl
    property int level: 1
    readonly property int layers: 8
    readonly property real spread: level >= 2 ? 32 : 18
    readonly property real drop: level >= 2 ? 12 : 4
    readonly property real strength: level >= 2 ? 0.35 : 0.24

    visible: !Theme.lowEnd && level > 0

    Repeater {
        model: shadow.visible ? shadow.layers : 0
        Rectangle {
            required property int index
            readonly property real grow: shadow.spread * (index + 1) / shadow.layers / 2
            x: -grow
            y: -grow + shadow.drop * (index + 1) / shadow.layers
            width: shadow.width + grow * 2
            height: shadow.height + grow * 2
            radius: shadow.radius + grow
            color: "transparent"
            border.width: grow + 1
            border.color: Qt.rgba(0, 0, 0, shadow.strength / shadow.layers)
        }
    }
}
