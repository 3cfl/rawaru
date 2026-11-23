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

    radius: 24
    color: Theme.surface2
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
    onCurrentChanged: if (!search.input.activeFocus) Qt.callLater(reveal)
    Component.onCompleted: Qt.callLater(reveal)

    M3Field {
        id: search
        x: 12; y: 12
        width: parent.width - 24
        label: root.placeholder
        icon: "search"
        onEdited: root.query = text
    }

    ListView {
        id: list
        anchors.top: search.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        x: 8
        width: parent.width - 16
        model: root.shown
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property bool selected: root.keyOf(modelData) === root.current
            width: ListView.view.width - 10
            height: 48
            radius: 16
            color: selected ? Theme.primaryContainer : hover.containsMouse ? Theme.surface3 : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            Text {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 32 - sec.implicitWidth - (check.visible ? 30 : 0)
                elide: Text.ElideRight
                text: root.primaryOf(row.modelData)
                color: row.selected ? Theme.inkPrimaryContainer : Theme.text
                font.family: Theme.font
                font.pixelSize: 15
                font.weight: row.selected ? Font.DemiBold : Font.Normal
            }
            Text {
                id: sec
                anchors.right: check.visible ? check.left : parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: root.secondaryOf(row.modelData)
                color: row.selected ? Theme.inkPrimaryContainer : Theme.textVariant
                font.family: Theme.font
                font.pixelSize: 13
            }
            Sym {
                id: check
                visible: row.selected
                text: "check"
                color: Theme.primary
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
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
