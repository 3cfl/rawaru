import QtQuick

Item {
    id: loader

    property bool running: visible
    property bool contained: false
    property color color: contained ? Theme.inkPrimaryContainer : Theme.primary
    readonly property var sequence: [10, 9, 5, 4, 7, 12, 6]
    property int stage: 0
    property real phase: 0
    property real turn: 0

    implicitWidth: 48
    implicitHeight: 48

    Rectangle {
        visible: loader.contained
        anchors.fill: parent
        radius: width / 2
        color: Theme.primaryContainer
    }

    ExpressiveShape {
        anchors.centerIn: parent
        width: parent.width * (loader.contained ? 0.62 : 0.8)
        height: width
        lobes: loader.sequence[loader.stage % loader.sequence.length]
        lobesNext: loader.sequence[(loader.stage + 1) % loader.sequence.length]
        morph: loader.phase
        depth: 0.1 + 0.04 * Math.sin(loader.phase * Math.PI)
        spin: loader.turn
        steps: Theme.lowEnd ? 60 : 120
        color: loader.color
    }

    SequentialAnimation {
        running: loader.running && Motion.animate
        loops: Animation.Infinite
        NumberAnimation {
            target: loader
            property: "phase"
            from: 0
            to: 1
            duration: 650
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standard
        }
        ScriptAction { script: { loader.stage = (loader.stage + 1) % loader.sequence.length; loader.phase = 0 } }
    }

    NumberAnimation {
        target: loader
        property: "turn"
        running: loader.running && Motion.animate
        from: 0
        to: 360
        duration: 4200
        loops: Animation.Infinite
    }
}
