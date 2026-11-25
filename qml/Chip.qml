import QtQuick

Item {
    id: chip

    property string text
    property string icon
    property bool tonal: false
    property bool glass: false
    property color tint: tonal ? Theme.onSecondaryContainer : Theme.onSurfaceVariant

    implicitHeight: 32
    implicitWidth: row.implicitWidth + (icon ? 24 : 32)

    Rectangle {
        anchors.fill: parent
        radius: Theme.sm
        color: chip.glass ? Theme.glassHigh : chip.tonal ? Theme.alpha(Theme.secondaryContainer, 0.85) : "transparent"
        border.width: chip.tonal || chip.glass ? 0 : 1
        border.color: Theme.outlineVariant
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Icon {
            visible: chip.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: chip.icon
            size: 18
            color: chip.tint
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.text
            role: Theme.labelL
            color: chip.tonal || chip.glass ? Theme.onSurface : Theme.onSurfaceVariant
        }
    }
}
