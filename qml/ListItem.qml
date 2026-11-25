import QtQuick

Item {
    id: item

    property string headline
    property string supporting
    property string icon
    property string leading: icon !== "" ? "icon" : ""
    property bool selected: false
    property bool interactive: true
    property bool danger: false
    property string badge
    property color badgeColor: Theme.tertiaryContainer
    property color badgeInk: Theme.inkTertiaryContainer
    property int supportingLines: 2
    property bool mono: false
    readonly property bool hovered: mouse.containsMouse
    default property alias trailing: trail.data

    signal clicked

    implicitWidth: 320
    implicitHeight: Math.max(supporting !== "" ? 72 : 56, col.implicitHeight + 20)
    activeFocusOnTab: interactive && enabled
    Keys.onSpacePressed: item.clicked()
    Keys.onReturnPressed: item.clicked()
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: item.selected ? Theme.lgInc : Theme.md
        color: item.selected ? (item.danger ? Theme.alpha(Theme.errorContainer, 0.6) : Theme.alpha(Theme.secondaryContainer, 0.9)) : "transparent"
        Behavior on radius {
            enabled: Motion.animate
            SpringAnimation { spring: Motion.fastSpring; damping: Motion.fastDamping; epsilon: 0.1 }
        }
        Behavior on color {
            enabled: Motion.animate
            ColorAnimation { duration: Motion.durShort }
        }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.inkSurface
            opacity: !item.interactive ? 0 : mouse.pressed ? Motion.statePressed : item.hovered || item.activeFocus ? Motion.stateHover : 0
        }
    }

    Item {
        id: lead
        x: 16
        width: item.leading === "" ? 0 : 24
        height: 24
        anchors.verticalCenter: parent.verticalCenter
        RadioMark {
            visible: item.leading === "radio"
            anchors.centerIn: parent
            checked: item.selected
            tint: item.danger ? Theme.error : Theme.primary
        }
        CheckMark {
            visible: item.leading === "check"
            anchors.centerIn: parent
            checked: item.selected
            tint: item.danger ? Theme.error : Theme.primary
            ink: item.danger ? Theme.inkError : Theme.inkPrimary
        }
        Icon {
            visible: item.leading === "icon"
            anchors.centerIn: parent
            name: item.icon
            fill: item.selected ? 1 : 0
            color: item.danger ? Theme.error : item.selected ? Theme.inkSecondaryContainer : Theme.inkSurfaceVariant
        }
    }

    Column {
        id: col
        anchors.left: lead.right
        anchors.leftMargin: item.leading === "" ? 0 : 16
        anchors.right: trail.left
        anchors.rightMargin: trail.width > 0 ? 12 : 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Row {
            width: parent.width
            spacing: 8
            Txt {
                id: head
                width: Math.min(implicitWidth, parent.width - (chip.visible ? chip.width + 8 : 0))
                text: item.headline
                role: Theme.bodyL
                emphasized: item.selected
                elide: Text.ElideRight
                color: item.danger && item.selected ? Theme.error : item.selected ? Theme.inkSecondaryContainer : Theme.inkSurface
            }
            Rectangle {
                id: chip
                visible: item.badge !== ""
                anchors.verticalCenter: head.verticalCenter
                width: badgeText.implicitWidth + 16
                height: 22
                radius: 11
                color: item.badgeColor
                Txt {
                    id: badgeText
                    anchors.centerIn: parent
                    text: item.badge
                    role: Theme.labelS
                    color: item.badgeInk
                }
            }
        }
        Txt {
            visible: item.supporting !== ""
            width: parent.width
            text: item.supporting
            role: Theme.bodyM
            font.family: item.mono ? Theme.mono : (role.size >= 24 ? Theme.display : Theme.font)
            color: Theme.inkSurfaceVariant
            wrapMode: Text.WordWrap
            maximumLineCount: item.supportingLines
            elide: Text.ElideRight
            lineHeightMode: Text.ProportionalHeight
            lineHeight: 1.1
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: item.interactive && item.enabled
        hoverEnabled: enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: item.clicked()
    }

    Item {
        id: trail
        anchors.right: parent.right
        anchors.rightMargin: childrenRect.width > 0 ? 16 : 0
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
