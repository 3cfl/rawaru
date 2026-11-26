import QtQuick

Dialog {
    id: wifi

    required property var app
    property string picked
    property bool pickedSecure: false
    property string err
    property bool proceed: false
    readonly property var backend: app.backend
    readonly property bool online: backend.online

    signal ready

    icon: online ? "wifi" : "wifi_off"
    title: online ? "you're online" : "connect to the internet"
    body: online
        ? "Fiordland downloads its packages while installing, and you're good to go."
        : backend.hasWifi
        ? "Fiordland downloads its packages while installing, so pick a Wi‑Fi network first. A cable works too."
        : "Fiordland downloads its packages while installing. Plug in a network cable to continue."

    function start(thenGo) {
        proceed = thenGo
        err = ""
        picked = ""
        open()
        if (!online && backend.hasWifi) backend.scanWifi()
    }
    function join() {
        if (picked === "" || backend.wifiJoining) return
        if (pickedSecure && pass.text.length < 8) { err = "Wi‑Fi passwords are at least 8 characters"; return }
        err = ""
        backend.connectWifi(picked, pickedSecure ? pass.text : "")
    }

    onOnlineChanged: if (online && visible && proceed) Qt.callLater(() => { wifi.close(); wifi.ready() })

    Connections {
        target: wifi.backend
        function onWifiConnected(ok, msg) {
            if (!wifi.visible) return
            if (ok) {
                pass.text = ""
                if (wifi.proceed) { wifi.close(); wifi.ready() }
            } else wifi.err = msg
        }
    }

    Item {
        visible: !wifi.online && wifi.backend.hasWifi
        width: parent.width
        height: Math.max(140, Math.min(280, wifi.app.height - 480))

        Column {
            anchors.centerIn: parent
            spacing: 12
            visible: wifi.backend.wifiScanning && wifi.backend.wifiNetworks.length === 0
            LoadingIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: parent.visible }
            Txt { text: "Looking for networks"; role: Theme.bodyM; color: Theme.inkSurfaceVariant }
        }
        Txt {
            anchors.centerIn: parent
            visible: !wifi.backend.wifiScanning && wifi.backend.wifiNetworks.length === 0
            text: "No networks found"
            role: Theme.bodyM
            color: Theme.inkSurfaceVariant
        }
        ListView {
            id: nets
            anchors.fill: parent
            clip: true
            spacing: 2
            model: wifi.backend.wifiNetworks
            delegate: ListItem {
                required property var modelData
                width: nets.width
                icon: modelData.signal >= 67 ? "network_wifi" : modelData.signal >= 34 ? "network_wifi_2_bar" : "network_wifi_1_bar"
                headline: modelData.ssid
                supporting: modelData.active ? "Connected, no internet" : modelData.secure ? "Secured" : "Open"
                selected: wifi.picked === modelData.ssid
                enabled: !wifi.backend.wifiJoining
                onClicked: {
                    wifi.err = ""
                    wifi.picked = modelData.ssid
                    wifi.pickedSecure = modelData.secure
                    if (modelData.secure) pass.editor.forceActiveFocus()
                    else wifi.join()
                }
                Icon {
                    visible: modelData.secure
                    anchors.verticalCenter: parent.verticalCenter
                    name: "lock"
                    size: 18
                    color: Theme.inkSurfaceVariant
                }
            }
        }
    }

    TextField {
        id: pass
        visible: !wifi.online && wifi.picked !== "" && wifi.pickedSecure
        width: parent.width
        label: "Password for " + wifi.picked
        icon: "key"
        password: true
        error: wifi.err
        enabled: !wifi.backend.wifiJoining
    }

    Connections {
        target: pass.editor
        function onAccepted() { wifi.join() }
    }

    Txt {
        visible: wifi.err !== "" && !pass.visible
        width: parent.width
        text: wifi.err
        role: Theme.bodyM
        color: Theme.error
        wrapMode: Text.WordWrap
    }

    actions: [
        PillButton {
            variant: "text"
            text: wifi.online ? "Close" : "Cancel"
            onClicked: wifi.close()
        },
        PillButton {
            visible: !wifi.online && wifi.backend.hasWifi
            variant: "text"
            icon: "refresh"
            text: "Rescan"
            enabled: !wifi.backend.wifiScanning && !wifi.backend.wifiJoining
            onClicked: wifi.backend.scanWifi()
        },
        PillButton {
            visible: !wifi.online && wifi.pickedSecure && wifi.picked !== ""
            icon: wifi.backend.wifiJoining ? "" : "wifi"
            text: wifi.backend.wifiJoining ? "Connecting…" : "Connect"
            enabled: !wifi.backend.wifiJoining && pass.text.length > 0
            onClicked: wifi.join()
        },
        PillButton {
            visible: wifi.online && wifi.proceed
            text: "Continue"
            trailingIcon: "arrow_forward"
            onClicked: { wifi.close(); wifi.ready() }
        }
    ]
}
