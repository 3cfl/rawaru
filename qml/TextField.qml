import QtQuick

Item {
    id: field

    property alias text: input.text
    property alias editor: input
    property string label
    property string placeholder
    property string supporting
    property string error
    property string icon
    property bool password: false
    property bool revealed: false
    readonly property bool floated: input.activeFocus || input.text !== "" || label === ""

    signal edited

    implicitWidth: 280
    implicitHeight: 56 + (message.text !== "" ? message.implicitHeight + 4 : 0)

    Rectangle {
        id: box
        width: parent.width
        height: 56
        radius: Theme.lg
        color: Theme.alpha(Theme.surfaceContainerHighest, Theme.lowEnd ? 0.9 : 0.6)
        border.width: input.activeFocus || field.error !== "" ? 2 : 0
        border.color: field.error !== "" ? Theme.error : Theme.primary
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.onSurface
            opacity: hover.containsMouse && !input.activeFocus ? Motion.stateHover : 0
        }

        Icon {
            id: lead
            visible: field.icon !== ""
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            name: field.icon
            color: field.error !== "" ? Theme.error : Theme.onSurfaceVariant
        }

        Txt {
            id: floating
            x: field.icon !== "" ? 50 : 16
            y: field.floated ? 7 : (box.height - height) / 2
            text: field.label
            role: field.floated ? Theme.bodyS : Theme.bodyL
            color: field.error !== "" ? Theme.error : input.activeFocus ? Theme.primary : Theme.onSurfaceVariant
            Behavior on y {
                enabled: Motion.animate
                SpringAnimation { spring: Motion.fastSpring; damping: 0.6; epsilon: 0.1 }
            }
        }

        TextInput {
            id: input
            x: floating.x
            y: field.label !== "" ? 25 : (box.height - height) / 2
            width: box.width - x - (reveal.visible ? 52 : 16)
            color: Theme.onSurface
            font.family: Theme.font
            font.pixelSize: 16
            selectionColor: Theme.primary
            selectedTextColor: Theme.onPrimary
            echoMode: field.password && !field.revealed ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            clip: true
            onTextEdited: field.edited()
            Txt {
                visible: input.text === "" && field.floated && field.placeholder !== ""
                text: field.placeholder
                role: Theme.bodyL
                height: input.height
                color: Theme.alpha(Theme.onSurfaceVariant, 0.7)
            }
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            anchors.rightMargin: reveal.visible ? 52 : 0
            hoverEnabled: true
            cursorShape: Qt.IBeamCursor
            onPressed: (m) => { input.forceActiveFocus(); m.accepted = false }
        }

        IconButton {
            id: reveal
            visible: field.password && input.text !== ""
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            icon: field.revealed ? "visibility_off" : "visibility"
            activeFocusOnTab: false
            onClicked: field.revealed = !field.revealed
        }
    }

    Txt {
        id: message
        x: 16
        y: box.height + 4
        width: parent.width - 32
        text: field.error !== "" ? field.error : field.supporting
        role: Theme.bodyS
        color: field.error !== "" ? Theme.error : Theme.onSurfaceVariant
        wrapMode: Text.WordWrap
        lineHeightMode: Text.ProportionalHeight
        lineHeight: 1.0
    }
}
