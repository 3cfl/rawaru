import QtQuick

Item {
    id: page

    required property var app
    property int index: 0
    property string overline
    property string title
    property string subtitle
    property bool showHeader: true
    readonly property bool active: app.step === index
    readonly property real offset: active ? 0 : (app.step > index ? -48 : 48)
    default property alias content: body.data
    property alias body: body

    opacity: active ? 1 : 0
    visible: opacity > 0.01
    enabled: active

    Behavior on opacity {
        enabled: Motion.animate
        NumberAnimation {
            duration: page.active ? Motion.durLong : Motion.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: page.active ? Motion.emphasizedDecel : Motion.emphasizedAccel
        }
    }

    transform: Translate {
        x: page.offset
        Behavior on x {
            enabled: Motion.animate
            SpringAnimation { spring: Motion.defaultSpring; damping: Motion.defaultDamping; epsilon: 0.25 }
        }
    }

    Column {
        id: header
        visible: page.showHeader
        width: parent.width
        spacing: 6
        Txt {
            text: page.overline
            role: Theme.labelL
            color: Theme.primary
            visible: text !== ""
        }
        Txt {
            width: parent.width
            text: page.title
            role: Theme.headlineL
            emphasized: true
            wrapMode: Text.WordWrap
        }
        Txt {
            width: parent.width
            text: page.subtitle
            role: Theme.bodyL
            color: Theme.inkSurfaceVariant
            wrapMode: Text.WordWrap
            visible: text !== ""
        }
    }

    Item {
        id: body
        anchors.top: page.showHeader ? header.bottom : parent.top
        anchors.topMargin: page.showHeader ? 24 : 0
        anchors.bottom: parent.bottom
        width: parent.width
    }
}
