import QtQuick

Item {
    id: root
    property string text
    property string icon
    property string kind: "filled"
    property bool enabled: true
    signal clicked

    implicitWidth: row.implicitWidth + (kind === "text" ? 28 : 44)
    implicitHeight: 44
    opacity: enabled ? 1 : 0.38
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: height / 2
        color: root.kind === "filled" ? Theme.primary
             : root.kind === "tonal" ? Theme.primaryContainer
             : "transparent"
        border.width: root.kind === "outlined" ? 1 : 0
        border.color: Theme.outline
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: fg
        opacity: !root.enabled ? 0 : mouse.pressed ? 0.14 : mouse.containsMouse ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
    }
    readonly property color fg: kind === "filled" ? Theme.inkPrimary
                              : kind === "tonal" ? Theme.inkPrimaryContainer
                              : Theme.primary

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Sym {
            visible: root.icon !== ""
            text: root.icon
            size: 20
            color: root.fg
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.text
            color: root.fg
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
            font.letterSpacing: 0.1
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled) root.clicked()
    }
    scale: mouse.pressed && enabled ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
}
