import QtQuick

Text {
    property real fill: 0
    property int size: 22
    font.family: Theme.icons
    font.pixelSize: size
    font.variableAxes: { "FILL": fill, "opsz": size, "wght": 400 }
    color: Theme.text
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    renderType: Text.NativeRendering
}
