pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic

Card {
    id: root

    property var items: []
    property var primaryOf: (x) => String(x)
    property var secondaryOf: (x) => ""
    property var keyOf: (x) => String(x)
    property string current
    property string placeholder: "Search"
    property string query: ""
    readonly property var shown: {
        const q = query.toLowerCase().trim()
        if (!q)
            return items
        return items.filter(x => (primaryOf(x) + " " + secondaryOf(x) + " " + keyOf(x)).toLowerCase().indexOf(q) >= 0)
    }

    signal picked(string key)

    radius: Theme.xl
    clip: true

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

    Rectangle {
        id: bar
        x: 8
        y: 8
        width: parent.width - 16
        height: 48
        radius: 24
        color: Theme.alpha(Theme.surfaceContainerHighest, Theme.lowEnd ? 0.95 : 0.7)
        border.width: search.activeFocus ? 2 : 0
        border.color: Theme.primary
        Icon {
            id: glass
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 22
        }
        TextInput {
            id: search
            anchors.left: glass.right
            anchors.leftMargin: 10
            anchors.right: clear.visible ? clear.left : parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.onSurface
            font.family: Theme.font
            font.pixelSize: 15
            selectionColor: Theme.primary
            selectedTextColor: Theme.onPrimary
            clip: true
            onTextEdited: root.query = text
            Keys.onDownPressed: list.forceActiveFocus()
            Txt {
                visible: search.text === ""
                height: search.height
                text: root.placeholder
                role: Theme.bodyL
                color: Theme.onSurfaceVariant
            }
        }
        IconButton {
            id: clear
            visible: search.text !== ""
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            icon: "close"
            size: 40
            onClicked: {
                search.text = ""
                root.query = ""
                Qt.callLater(root.reveal)
            }
        }
    }

    ListView {
        id: list
        anchors.top: bar.bottom
        anchors.topMargin: 6
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        x: 8
        width: parent.width - 16
        model: root.shown
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        keyNavigationEnabled: true
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: Theme.outline
                opacity: 0.5
            }
        }
        delegate: Item {
            id: row
            required property var modelData
            readonly property bool selected: root.keyOf(modelData) === root.current
            width: ListView.view.width - 8
            height: 44
            Rectangle {
                anchors.fill: parent
                radius: row.selected ? 22 : Theme.md
                color: row.selected ? Theme.secondaryContainer : Theme.alpha(Theme.onSurface, hover.containsMouse ? Motion.stateHover : 0)
                Behavior on radius {
                    enabled: Motion.animate
                    SpringAnimation { spring: Motion.fastSpring; damping: Motion.fastDamping; epsilon: 0.1 }
                }
            }
            Txt {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 32 - sec.width - (tick.visible ? 28 : 0)
                elide: Text.ElideRight
                text: root.primaryOf(row.modelData)
                role: Theme.bodyL
                emphasized: row.selected
                color: row.selected ? Theme.onSecondaryContainer : Theme.onSurface
            }
            Txt {
                id: sec
                anchors.right: tick.visible ? tick.left : parent.right
                anchors.rightMargin: tick.visible ? 8 : 16
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width * 0.45)
                elide: Text.ElideLeft
                horizontalAlignment: Text.AlignRight
                text: root.secondaryOf(row.modelData)
                role: Theme.bodyS
                color: row.selected ? Theme.onSecondaryContainer : Theme.onSurfaceVariant
            }
            Icon {
                id: tick
                visible: row.selected
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                name: "check"
                size: 20
                weight: 600
                color: Theme.onSecondaryContainer
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(root.keyOf(row.modelData))
            }
        }
        Txt {
            anchors.centerIn: parent
            visible: list.count === 0
            text: "nothing matches"
            role: Theme.bodyM
            color: Theme.onSurfaceVariant
        }
    }
}
