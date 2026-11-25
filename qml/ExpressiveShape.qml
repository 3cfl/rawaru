import QtQuick
import QtQuick.Shapes

Item {
    id: blob

    property int lobes: 9
    property int lobesNext: lobes
    property real morph: 0
    property real depth: 0.08
    property real spin: 0
    property color color: Theme.primaryContainer
    property color strokeColor: "transparent"
    property real strokeWidth: 0
    property int steps: 120

    readonly property string path: {
        const w = width, h = height
        const r = Math.min(w, h) / 2 - strokeWidth
        const cx = w / 2, cy = h / 2
        const base = r / (1 + depth)
        const rot = spin * Math.PI / 180
        let d = ""
        for (let i = 0; i <= steps; i++) {
            const t = i / steps * Math.PI * 2
            const wave = (1 - morph) * Math.cos(lobes * (t - rot)) + morph * Math.cos(lobesNext * (t - rot))
            const rr = base * (1 + depth * wave)
            const x = cx + rr * Math.cos(t - Math.PI / 2)
            const y = cy + rr * Math.sin(t - Math.PI / 2)
            d += (i === 0 ? "M " : " L ") + x.toFixed(2) + " " + y.toFixed(2)
        }
        return d + " Z"
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: blob.color
            strokeColor: blob.strokeColor
            strokeWidth: blob.strokeWidth
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: blob.path }
        }
    }
}
