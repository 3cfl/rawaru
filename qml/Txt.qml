import QtQuick

Text {
    property var role: Theme.bodyM
    property bool emphasized: false

    color: Theme.inkSurface
    font.family: role.size >= 24 ? Theme.display : Theme.font
    font.pixelSize: role.size
    font.weight: Math.min(900, role.weight + (emphasized ? 200 : 0))
    font.letterSpacing: role.size >= 22 ? -0.02 * role.size : 0
    font.features: { "tnum": 1 }
    lineHeightMode: Text.FixedHeight
    lineHeight: role.line
    verticalAlignment: Text.AlignVCenter
}
