pragma Singleton
import QtQuick

QtObject {
    property bool reduced: false
    readonly property bool animate: !reduced

    readonly property int durShort: reduced ? 0 : 150
    readonly property int durMedium: reduced ? 0 : 300
    readonly property int durLong: reduced ? 0 : 500
    readonly property int durExtraLong: reduced ? 0 : 700

    readonly property var emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property var standard: [0.2, 0, 0, 1, 1, 1]

    readonly property real fastSpring: 5
    readonly property real fastDamping: reduced ? 1 : 0.28
    readonly property real defaultSpring: 3.5
    readonly property real defaultDamping: reduced ? 1 : 0.35
    readonly property real slowSpring: 2.4
    readonly property real slowDamping: reduced ? 1 : 0.4

    readonly property real stateHover: 0.08
    readonly property real stateFocus: 0.10
    readonly property real statePressed: 0.10
    readonly property real stateDragged: 0.16
}
