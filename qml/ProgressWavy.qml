import QtQuick
import QtQuick.Shapes

Item {
    id: bar

    property real value: 0
    property real thickness: 6
    property real amplitude: Theme.lowEnd ? 0 : 3.5
    property real wavelength: 36
    property bool running: visible
    property real phase: 0
    property real shown: value

    implicitWidth: 320
    implicitHeight: 24

    Behavior on shown {
        enabled: Motion.animate
        SpringAnimation { spring: Motion.slowSpring; damping: 0.9; epsilon: 0.0005 }
    }

    NumberAnimation on phase {
        running: bar.running && Motion.animate && bar.amplitude > 0
        from: 0
        to: 1
        duration: 1300
        loops: Animation.Infinite
    }

    readonly property real cap: thickness / 2
    readonly property real span: Math.max(0, width - thickness * 2 - 4)
    readonly property real activeEnd: cap + span * Math.max(0, Math.min(1, shown))
    readonly property real gap: thickness + 2
    readonly property real ramp: Math.min(1, shown * 12, (1 - shown) * 12)

    readonly property var wave: {
        const pts = []
        const mid = height / 2
        const amp = amplitude * Math.max(0, ramp)
        const end = activeEnd
        const step = amp > 0 ? 2 : Math.max(1, end - cap)
        for (let x = cap; x < end; x += step)
            pts.push(Qt.point(x, mid + amp * Math.sin((x / wavelength - phase) * Math.PI * 2)))
        pts.push(Qt.point(end, mid + amp * Math.sin((end / wavelength - phase) * Math.PI * 2)))
        return pts
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: bar.activeEnd + bar.gap < bar.width - bar.thickness ? Theme.secondaryContainer : "transparent"
            strokeWidth: bar.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: Math.min(bar.activeEnd + bar.gap + bar.cap, bar.width - bar.thickness - bar.cap)
            startY: bar.height / 2
            PathLine { x: bar.width - bar.thickness - bar.cap; y: bar.height / 2 }
        }
        ShapePath {
            strokeColor: bar.shown > 0.002 ? Theme.primary : "transparent"
            strokeWidth: bar.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: bar.wave }
        }
    }

    Rectangle {
        width: bar.thickness - 2
        height: width
        radius: width / 2
        x: bar.width - bar.cap - width / 2 - 1
        y: (bar.height - height) / 2
        color: Theme.primary
        visible: bar.shown < 0.995
    }
}
