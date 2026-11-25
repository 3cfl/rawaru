import QtQuick

Item {
    id: backdrop

    property string source
    property real blur: 0
    readonly property bool hasImage: sharp.status === Image.Ready

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0B1A2A" }
            GradientStop { position: 0.55; color: "#0E1A24" }
            GradientStop { position: 1.0; color: "#070B10" }
        }
    }

    Rectangle {
        visible: !backdrop.hasImage
        width: parent.width * 1.2
        height: width
        x: parent.width * 0.35
        y: parent.height * 0.25
        radius: width / 2
        color: Theme.alpha(Theme.tertiary, 0.06)
    }

    Image {
        id: sharp
        anchors.fill: parent
        source: backdrop.source
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 2560
        asynchronous: true
        cache: true
        opacity: 1 - backdrop.blur
        visible: opacity > 0.01
    }

    Image {
        anchors.fill: parent
        source: backdrop.source
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: Theme.lowEnd ? 24 : 48
        smooth: true
        mipmap: false
        asynchronous: true
        opacity: backdrop.blur
        visible: opacity > 0.01
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        opacity: backdrop.blur * 0.38
    }

    Behavior on blur {
        enabled: Motion.animate
        NumberAnimation { duration: Motion.durExtraLong; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standard }
    }
}
