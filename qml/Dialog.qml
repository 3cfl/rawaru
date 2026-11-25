import QtQuick
import QtQuick.Controls.Basic as C

C.Popup {
    id: dialog

    property string icon
    property string title
    property string body
    property bool danger: false
    default property alias content: extra.data
    property alias actions: actionRow.data

    anchors.centerIn: C.Overlay.overlay
    width: Math.min(560, (parent ? parent.width : 560) - 48)
    modal: true
    dim: true
    padding: 28
    topPadding: 28
    focus: true
    closePolicy: C.Popup.CloseOnEscape | C.Popup.CloseOnPressOutside

    C.Overlay.modal: Rectangle {
        color: Theme.alpha(Theme.scrim, 0.55)
        Behavior on opacity { NumberAnimation { duration: Motion.durMedium } }
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.durMedium; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedDecel }
            SpringAnimation { property: "scale"; from: Motion.animate ? 0.88 : 1; to: 1; spring: Motion.defaultSpring; damping: Motion.defaultDamping; epsilon: 0.002 }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: Motion.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedAccel }
            NumberAnimation { property: "scale"; to: Motion.animate ? 0.94 : 1; duration: Motion.durShort }
        }
    }

    background: Item {
        Elevation {
            anchors.fill: parent
            radius: Theme.xl
            level: 2
        }
        RoundedBox {
            anchors.fill: parent
            leftRadius: Theme.xxl
            rightRadius: Theme.xl
            color: Theme.alpha(Theme.surfaceContainerHigh, Theme.lowEnd ? 1 : 0.97)
        }
    }

    contentItem: Column {
        spacing: 16
        Item {
            visible: dialog.icon !== ""
            width: parent.width
            height: 56
            ExpressiveShape {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 56
                height: 56
                lobes: 9
                depth: 0.07
                color: dialog.danger ? Theme.errorContainer : Theme.secondaryContainer
                Icon {
                    anchors.centerIn: parent
                    name: dialog.icon
                    size: 28
                    fill: 1
                    color: dialog.danger ? Theme.inkErrorContainer : Theme.inkSecondaryContainer
                }
            }
        }
        Txt {
            width: parent.width
            text: dialog.title
            role: Theme.headlineS
            horizontalAlignment: dialog.icon !== "" ? Text.AlignHCenter : Text.AlignLeft
            wrapMode: Text.WordWrap
        }
        Txt {
            visible: dialog.body !== ""
            width: parent.width
            text: dialog.body
            role: Theme.bodyM
            color: Theme.inkSurfaceVariant
            wrapMode: Text.WordWrap
            lineHeightMode: Text.ProportionalHeight
            lineHeight: 1.25
        }
        Column {
            id: extra
            width: parent.width
            spacing: 8
        }
        Item {
            width: parent.width
            height: 8
        }
        Row {
            id: actionRow
            anchors.right: parent.right
            spacing: 8
        }
    }
}
