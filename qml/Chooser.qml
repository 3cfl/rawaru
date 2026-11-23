import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    property var items: []
    property var primaryOf: (x) => String(x)
    property var secondaryOf: (x) => ""
    property var keyOf: (x) => String(x)
    property string current
    property string placeholder: "Search"
    signal picked(string key)

    radius: Theme.radius
    color: Theme.panel
    border.color: Theme.line
    clip: true

    property string query: ""
    readonly property var shown: {
        const q = query.toLowerCase().trim()
        if (!q) return items
        return items.filter(x => (primaryOf(x) + " " + secondaryOf(x) + " " + keyOf(x)).toLowerCase().indexOf(q) >= 0)
    }

    function reveal() {
        for (let i = 0; i < shown.length; i++) {
            if (keyOf(shown[i]) === current) {
                list.positionViewAtIndex(i, ListView.Center)
                return
            }
        }
    }
    onCurrentChanged: if (!search.activeFocus) Qt.callLater(reveal)
    Component.onCompleted: Qt.callLater(reveal)

    Item {
        id: top
        width: parent.width
        height: 44
        Glyph { id: glass; x: 14; anchors.verticalCenter: parent.verticalCenter; kind: "search"; width: 15; height: 15; stroke: 1.6; color: Theme.faint }
        TextInput {
            id: search
            anchors.left: glass.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentInk
            clip: true
            onTextEdited: root.query = text
            Text { visible: search.text === ""; text: root.placeholder; color: Theme.faint; font: search.font }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
    }

    ListView {
        id: list
        anchors.top: top.bottom
        anchors.bottom: parent.bottom
        anchors.margins: 4
        x: 4
        width: parent.width - 8
        model: root.shown
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property bool selected: root.keyOf(modelData) === root.current
            width: ListView.view.width - 8
            height: 36
            radius: 6
            color: selected ? Theme.accentSoft : hover.containsMouse ? Theme.hover : "transparent"
            Text {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 30 - sec.implicitWidth
                elide: Text.ElideRight
                text: root.primaryOf(row.modelData)
                color: row.selected ? Theme.accent : Theme.text
                font.family: Theme.font
                font.pixelSize: 14
            }
            Text {
                id: sec
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: root.secondaryOf(row.modelData)
                color: row.selected ? Theme.accent : Theme.faint
                font.family: Theme.font
                font.pixelSize: 12
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(root.keyOf(row.modelData))
            }
        }
    }
}
