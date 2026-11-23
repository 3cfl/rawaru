import QtQuick
import QtQuick.Controls

Item {
    id: root
    property alias text: input.text
    property string label
    property string icon
    property string hint
    property string error
    property bool password: false
    property alias input: input
    signal edited

    implicitHeight: 56 + (msg.text !== "" ? 22 : 0)
    implicitWidth: 300

    Rectangle {
        id: box
        width: parent.width
        height: 56
        radius: 16
        color: Theme.surface3
        border.width: input.activeFocus ? 2 : 1
        border.color: root.error !== "" ? Theme.danger : input.activeFocus ? Theme.primary : Theme.outlineVariant
        Behavior on border.color { ColorAnimation { duration: Theme.fast } }

        Sym {
            id: ico
            visible: root.icon !== ""
            text: root.icon
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            color: input.activeFocus ? Theme.primary : Theme.textVariant
        }
        Text {
            id: lbl
            text: root.label
            x: input.x
            font.family: Theme.font
            color: root.error !== "" ? Theme.danger : input.activeFocus ? Theme.primary : Theme.textVariant
            property bool up: input.activeFocus || input.text !== ""
            y: up ? 8 : (parent.height - height) / 2
            font.pixelSize: up ? 11 : 15
            Behavior on y { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
            Behavior on font.pixelSize { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
        }
        TextInput {
            id: input
            x: root.icon !== "" ? 50 : 16
            width: parent.width - x - (eye.visible ? 48 : 16)
            y: 26
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 15
            selectionColor: Theme.primaryContainer
            selectedTextColor: Theme.inkPrimaryContainer
            echoMode: root.password && !eye.shown ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            clip: true
            onTextEdited: root.edited()
        }
        Sym {
            id: eye
            property bool shown: false
            visible: root.password
            text: shown ? "visibility_off" : "visibility"
            color: Theme.textVariant
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: eye.shown = !eye.shown
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.rightMargin: eye.visible ? 48 : 0
            cursorShape: Qt.IBeamCursor
            onPressed: (m) => { input.forceActiveFocus(); m.accepted = false }
        }
    }
    Text {
        id: msg
        anchors.top: box.bottom
        anchors.topMargin: 5
        x: 16
        text: root.error !== "" ? root.error : root.hint
        visible: text !== ""
        color: root.error !== "" ? Theme.danger : Theme.textVariant
        font.family: Theme.font
        font.pixelSize: 12
    }
}
