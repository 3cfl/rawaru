import QtQuick

ExpressiveShape {
    id: logo

    property int size: 36

    width: size
    height: size
    lobes: 4
    depth: 0.12
    spin: 45
    color: Theme.primary

    Icon {
        anchors.centerIn: parent
        name: "landscape"
        size: Math.round(logo.size * 0.56)
        fill: 1
        color: Theme.inkPrimary
    }
}
