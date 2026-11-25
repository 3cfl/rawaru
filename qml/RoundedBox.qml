import QtQuick

Item {
    id: box

    property real leftRadius: 0
    property real rightRadius: 0
    property color color: Theme.surfaceContainer
    property color borderColor: "transparent"
    property real borderWidth: 0

    Item {
        width: Math.ceil(box.width / 2)
        height: box.height
        clip: true
        Rectangle {
            width: box.width
            height: box.height
            radius: Math.min(box.leftRadius, box.height / 2, box.width / 2)
            color: box.color
            border.color: box.borderColor
            border.width: box.borderWidth
        }
    }
    Item {
        x: Math.ceil(box.width / 2)
        width: box.width - x
        height: box.height
        clip: true
        Rectangle {
            x: -parent.x
            width: box.width
            height: box.height
            radius: Math.min(box.rightRadius, box.height / 2, box.width / 2)
            color: box.color
            border.color: box.borderColor
            border.width: box.borderWidth
        }
    }
}
