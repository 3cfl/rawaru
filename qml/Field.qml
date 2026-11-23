import QtQuick

Column {
    id: root
    property alias text: input.text
    property string label
    property string placeholder
    property string hint
    property string error
    property bool password: false
    property alias input: input
    signal edited

    spacing: 6

    Text {
        visible: root.label !== ""
        text: root.label
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: 13
    }
    Rectangle {
        width: root.width
        height: 40
        radius: Theme.radius
        color: Theme.panel
        border.width: 1
        border.color: root.error !== "" ? Theme.danger : input.activeFocus ? Theme.accent : Theme.lineStrong
        Behavior on border.color { ColorAnimation { duration: Theme.fast } }

        TextInput {
            id: input
            x: 12
            width: parent.width - 24 - (reveal.visible ? reveal.width + 10 : 0)
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentInk
            echoMode: root.password && !reveal.shown ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            clip: true
            onTextEdited: root.edited()
            Text {
                visible: input.text === "" && root.placeholder !== ""
                text: root.placeholder
                color: Theme.faint
                font: input.font
            }
        }
        Text {
            id: reveal
            property bool shown: false
            visible: root.password && input.text !== ""
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: shown ? "Hide" : "Show"
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 12
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: reveal.shown = !reveal.shown
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.rightMargin: reveal.visible ? reveal.width + 20 : 0
            cursorShape: Qt.IBeamCursor
            onPressed: (m) => { input.forceActiveFocus(); m.accepted = false }
        }
    }
    Text {
        text: root.error !== "" ? root.error : root.hint
        visible: text !== ""
        color: root.error !== "" ? Theme.danger : Theme.muted
        font.family: Theme.font
        font.pixelSize: 12
    }
}
