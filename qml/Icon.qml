import QtQuick

Text {
    id: icon

    property string name
    property real fill: 0
    property int size: 24
    property int weight: 400

    width: size
    height: size
    text: Theme.hasSymbols ? name : ""
    color: Theme.onSurfaceVariant
    font.family: Theme.symbols
    font.pixelSize: size
    font.variableAxes: ({ "FILL": icon.fill, "wght": icon.weight, "GRAD": 0, "opsz": Math.max(20, Math.min(48, icon.size)) })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on fill {
        enabled: Motion.animate
        NumberAnimation { duration: Motion.durMedium; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standard }
    }
}
