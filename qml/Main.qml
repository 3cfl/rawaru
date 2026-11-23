import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: win
    width: 1040
    height: 700
    minimumWidth: 900
    minimumHeight: 620
    visible: true
    title: "Install Fiordland"
    color: Theme.bg
    font.family: Theme.font

    Material.theme: Material.Dark
    Material.accent: Theme.primary
    Material.primary: Theme.primary
    Material.background: Theme.bg
    Material.foreground: Theme.text

    property int step: 0
    property string sysLocale: "en_US.UTF-8"
    property string timezone: "UTC"
    property string keymap: "us"
    property string disk: backend.disks.length === 1 && backend.disks[0].big ? backend.disks[0].path : ""
    property bool understood: false
    property string fullname: ""
    property string username: ""
    property bool usernameTouched: false
    property string hostname: "fiordland"
    property string password: ""
    property string password2: ""
    property bool autologin: false
    property bool failed: false
    property string errorText: ""

    readonly property var steps: [
        { icon: "public", label: "Region" },
        { icon: "hard_drive", label: "Disk" },
        { icon: "person", label: "You" },
        { icon: "checklist", label: "Review" },
        { icon: "download", label: "Install" }
    ]
    readonly property var reserved: ["root", "bin", "daemon", "mail", "ftp", "http", "nobody", "dbus", "systemd-network",
        "systemd-resolve", "systemd-timesync", "systemd-coredump", "uuidd", "greeter", "polkitd", "rtkit", "git", "avahi"]
    readonly property string usernameError: username === "" ? ""
        : !/^[a-z_][a-z0-9_-]{0,31}$/.test(username) ? "Use lowercase letters, numbers, - and _"
        : reserved.indexOf(username) >= 0 ? "That name is taken by the system" : ""
    readonly property string hostnameError: hostname === "" ? ""
        : !/^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/.test(hostname) ? "Letters, numbers and dashes only" : ""
    readonly property string passwordError: password2 !== "" && password !== password2 ? "Passwords don't match" : ""
    readonly property bool youValid: username !== "" && usernameError === "" && hostname !== "" && hostnameError === ""
        && password !== "" && password === password2
    readonly property var diskInfo: {
        for (const d of backend.disks) if (d.path === disk) return d
        return null
    }
    readonly property bool canNext: step === 1 ? timezone !== "" && keymap !== ""
        : step === 2 ? disk !== "" && understood
        : step === 3 ? youValid
        : true

    function localeName(code) {
        const l = Qt.locale(code.replace(".UTF-8", ""))
        const lang = l.nativeLanguageName || code
        const terr = l.nativeTerritoryName
        return terr ? lang.charAt(0).toUpperCase() + lang.slice(1) + " (" + terr + ")" : lang
    }
    function keymapName(code) {
        for (const k of backend.keymaps) if (k.code === code) return k.name
        return code
    }
    function zoneCity(z) { return z.split("/").slice(-1)[0].replace(/_/g, " ") }
    function zoneRegion(z) { return z.indexOf("/") < 0 ? "" : z.split("/").slice(0, -1).join(" / ").replace(/_/g, " ") }

    function next() {
        if (step < 1 || step > 4 || !canNext) return
        if (step === 4) { startInstall(); return }
        step++
    }
    function startInstall() {
        failed = false
        errorText = ""
        logModel.clear()
        step = 5
        backend.install({
            disk: disk, locale: sysLocale, timezone: timezone, keymap: keymap, fullname: fullname,
            username: username, hostname: hostname, password: password, autologin: autologin
        })
    }

    onFullnameChanged: if (!usernameTouched) username = fullname.trim().split(/\s+/)[0].toLowerCase().replace(/[^a-z0-9_-]/g, "")
    onKeymapChanged: backend.setKeymap(keymap)
    Component.onCompleted: backend.guessTimezone()

    Connections {
        target: backend
        function onTimezoneGuessed(tz) { if (win.timezone === "UTC") win.timezone = tz }
        function onLogAdded(line) {
            logModel.append({ line: line })
            if (logModel.count > 1500) logModel.remove(0, 300)
        }
        function onInstallFinished(ok, err) {
            win.failed = !ok
            win.errorText = err
            win.step = 6
        }
    }
    ListModel { id: logModel }

    component PageHeader: Row {
        property string icon
        property string title
        property string subtitle
        spacing: 18
        Rectangle {
            width: 56; height: 56; radius: 18
            color: Theme.primaryContainer
            Sym { anchors.centerIn: parent; text: parent.parent.icon; size: 28; fill: 1; color: Theme.inkPrimaryContainer }
        }
        Column {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            Text { text: parent.parent.title; color: Theme.text; font.pixelSize: 28; font.weight: Font.DemiBold }
            Text { text: parent.parent.subtitle; color: Theme.textVariant; font.pixelSize: 15 }
        }
    }

    component Page: Item {
        property int index
        readonly property bool active: win.step === index
        anchors.fill: parent
        opacity: active ? 1 : 0
        visible: opacity > 0
        enabled: active
        transform: Translate { x: active ? 0 : (win.step > index ? -40 : 40); Behavior on x { NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic } }
    }

    component Card: Rectangle { radius: 24; color: Theme.surface2 }

    component ReviewRow: Item {
        property string icon
        property string label
        property string value
        property int target: -1
        width: parent.width
        height: 64
        Sym { id: ri; x: 20; anchors.verticalCenter: parent.verticalCenter; text: parent.icon; color: Theme.primary }
        Column {
            x: 60
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 160
            Text { text: parent.parent.label; color: Theme.textVariant; font.pixelSize: 12 }
            Text { text: parent.parent.value; color: Theme.text; font.pixelSize: 15; elide: Text.ElideRight; width: parent.width }
        }
        M3Button {
            visible: parent.target >= 0
            kind: "text"; text: "Change"
            anchors.right: parent.right; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            onClicked: win.step = parent.target
        }
    }

    Item {
        id: welcome
        anchors.fill: parent
        opacity: win.step === 0 ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

        Image {
            anchors.fill: parent
            source: backend.wallpaper
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 2080
            asynchronous: true
            scale: win.step === 0 ? 1 : 1.06
            Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0.075, 0.075, 0.075, 0.94) }
                GradientStop { position: 0.55; color: Qt.rgba(0.075, 0.075, 0.075, 0.55) }
                GradientStop { position: 1.0; color: Qt.rgba(0.075, 0.075, 0.075, 0.05) }
            }
        }
        Column {
            x: 72
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Image { source: "logo.svg"; width: 76; height: 76; sourceSize: Qt.size(152, 152) }
            Item { width: 1; height: 28 }
            Text { text: "Kia ora."; color: Theme.primary; font.pixelSize: 64; font.weight: Font.Bold; font.letterSpacing: -1.5 }
            Text { text: "Welcome to Fiordland Linux"; color: Theme.text; font.pixelSize: 30; font.weight: Font.DemiBold; font.letterSpacing: -0.4 }
            Item { width: 1; height: 16 }
            Text {
                width: 440
                wrapMode: Text.WordWrap
                text: "Fast, stable and yours. This will set up Fiordland on your computer in a few minutes. You can also keep trying it out first, nothing changes until you press Install."
                color: Theme.textVariant
                font.pixelSize: 16
                lineHeight: 1.35
            }
            Item { width: 1; height: 32 }
            Rectangle {
                width: langRow.implicitWidth + 40
                height: 48
                radius: 24
                color: Qt.rgba(1, 1, 1, langMouse.containsMouse ? 0.12 : 0.07)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                Row {
                    id: langRow
                    anchors.centerIn: parent
                    spacing: 10
                    Sym { text: "translate"; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: win.localeName(win.sysLocale); color: Theme.text; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                    Sym { text: "expand_more"; color: Theme.textVariant; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: langMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: langPopup.open() }
            }
            Item { width: 1; height: 20 }
            Row {
                spacing: 12
                M3Button { text: "Install Fiordland"; icon: "arrow_forward"; onClicked: win.step = 1; implicitHeight: 52 }
                M3Button { text: "Keep trying it"; kind: "outlined"; implicitHeight: 52; onClicked: backend.quit() }
            }
        }
        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 24
            text: "Fiordland 1  ·  rawaru"
            color: Qt.rgba(1, 1, 1, 0.5)
            font.pixelSize: 12
        }
    }

    Popup {
        id: langPopup
        anchors.centerIn: parent
        width: 460
        height: 520
        modal: true
        padding: 0
        background: Rectangle { radius: 28; color: Theme.surface1; border.color: Theme.outlineVariant }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.fast } NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.medium; easing.type: Easing.OutCubic } }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.fast } }
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }
        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14
            Text { text: "System language"; color: Theme.text; font.pixelSize: 22; font.weight: Font.DemiBold; leftPadding: 4 }
            Chooser {
                width: parent.width
                height: parent.height - 50
                color: Theme.surface2
                items: backend.locales
                primaryOf: (x) => win.localeName(x)
                secondaryOf: (x) => x.replace(".UTF-8", "")
                current: win.sysLocale
                placeholder: "Search languages"
                onPicked: (k) => { win.sysLocale = k; langPopup.close() }
            }
        }
    }

    Item {
        id: shell
        anchors.fill: parent
        opacity: win.step > 0 ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

        Rectangle {
            id: rail
            width: 248
            height: parent.height
            color: Theme.surface1

            Row {
                x: 28; y: 30
                spacing: 12
                Image { source: "logo.svg"; width: 36; height: 36; sourceSize: Qt.size(72, 72) }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Fiordland"; color: Theme.text; font.pixelSize: 18; font.weight: Font.Bold }
                    Text { text: "Installer"; color: Theme.textVariant; font.pixelSize: 12 }
                }
            }

            Column {
                x: 16; y: 112
                width: parent.width - 32
                spacing: 4
                Repeater {
                    model: win.steps
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property int num: index + 1
                        readonly property bool current: win.step === num || (win.step === 6 && num === 5 && win.failed)
                        readonly property bool done: win.step > num && !(win.step === 6 && num === 5 && win.failed)
                        width: parent.width
                        height: 52
                        radius: 26
                        color: current ? Theme.primaryContainer : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.medium } }
                        Rectangle {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28; height: 28; radius: 14
                            color: parent.done ? Theme.primary : "transparent"
                            border.width: parent.done ? 0 : 1.5
                            border.color: parent.current ? Theme.inkPrimaryContainer : Theme.outline
                            Behavior on color { ColorAnimation { duration: Theme.medium } }
                            Sym {
                                anchors.centerIn: parent
                                text: parent.parent.done ? "check" : parent.parent.modelData.icon
                                size: 17
                                fill: parent.parent.current ? 1 : 0
                                color: parent.parent.done ? Theme.inkPrimary : parent.parent.current ? Theme.inkPrimaryContainer : Theme.textVariant
                            }
                        }
                        Text {
                            x: 54
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.label
                            color: parent.current ? Theme.inkPrimaryContainer : parent.done ? Theme.text : Theme.textVariant
                            font.pixelSize: 15
                            font.weight: parent.current ? Font.DemiBold : Font.Medium
                        }
                    }
                }
            }

            Column {
                x: 28
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26
                spacing: 4
                Text { text: backend.uefi ? "UEFI system" : "BIOS system"; color: Theme.textVariant; font.pixelSize: 12 }
                Text { text: backend.dryRun ? "Preview mode, nothing is written" : "Fiordland 1"; color: backend.dryRun ? Theme.primary : Theme.textVariant; font.pixelSize: 12 }
            }
        }

        Item {
            id: content
            anchors.left: rail.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: bar.top
            anchors.leftMargin: 44
            anchors.rightMargin: 44
            anchors.topMargin: 40
            clip: false

            Page {
                index: 1
                PageHeader { id: h1; icon: "public"; title: "Where are you?"; subtitle: "Pick your time zone and keyboard layout." }
                RowLayout {
                    anchors.top: h1.bottom
                    anchors.topMargin: 28
                    anchors.bottom: parent.bottom
                    width: parent.width
                    spacing: 16
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        spacing: 10
                        Text { text: "Time zone"; color: Theme.textVariant; font.pixelSize: 13; font.weight: Font.DemiBold; leftPadding: 4 }
                        Chooser {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            items: backend.timezones
                            primaryOf: (z) => win.zoneCity(z)
                            secondaryOf: (z) => win.zoneRegion(z)
                            current: win.timezone
                            placeholder: "Search cities"
                            onPicked: (k) => win.timezone = k
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        spacing: 10
                        Text { text: "Keyboard"; color: Theme.textVariant; font.pixelSize: 13; font.weight: Font.DemiBold; leftPadding: 4 }
                        Chooser {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            items: backend.keymaps
                            primaryOf: (k) => k.name
                            secondaryOf: (k) => k.code
                            keyOf: (k) => k.code
                            current: win.keymap
                            placeholder: "Search layouts"
                            onPicked: (k) => win.keymap = k
                        }
                        M3Field { Layout.fillWidth: true; label: "Type here to test your keyboard"; icon: "keyboard" }
                    }
                }
            }

            Page {
                index: 2
                PageHeader { id: h2; icon: "hard_drive"; title: "Where should it go?"; subtitle: "Fiordland will use the whole disk you choose." }
                Flickable {
                    anchors.top: h2.bottom
                    anchors.topMargin: 28
                    anchors.bottom: parent.bottom
                    width: parent.width
                    contentHeight: diskCol.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: diskCol
                        width: parent.width
                        spacing: 10
                        Repeater {
                            model: backend.disks
                            delegate: Rectangle {
                                id: dcard
                                required property var modelData
                                readonly property bool selected: win.disk === modelData.path
                                width: diskCol.width
                                height: 84
                                radius: 24
                                color: selected ? Theme.primaryContainer : dmouse.containsMouse && modelData.big ? Theme.surface3 : Theme.surface2
                                border.width: selected ? 2 : 0
                                border.color: Theme.primary
                                opacity: modelData.big ? 1 : 0.5
                                Behavior on color { ColorAnimation { duration: Theme.fast } }
                                Rectangle {
                                    x: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 48; height: 48; radius: 16
                                    color: dcard.selected ? Theme.primary : Theme.surface4
                                    Sym {
                                        anchors.centerIn: parent
                                        text: dcard.modelData.kind === "usb" ? "usb" : dcard.modelData.kind === "nvme" ? "memory" : "hard_drive"
                                        fill: 1
                                        color: dcard.selected ? Theme.inkPrimary : Theme.text
                                    }
                                }
                                Column {
                                    x: 82
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3
                                    Text { text: dcard.modelData.model; color: dcard.selected ? Theme.inkPrimaryContainer : Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                                    Text {
                                        text: dcard.modelData.path + "  ·  " + (dcard.modelData.big ? (dcard.modelData.parts > 0 ? dcard.modelData.parts + " partition" + (dcard.modelData.parts > 1 ? "s" : "") : "Empty") : "Too small, needs 20 GB")
                                        color: Theme.textVariant
                                        font.pixelSize: 13
                                    }
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: dcard.modelData.sizeText
                                    color: dcard.selected ? Theme.inkPrimaryContainer : Theme.text
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    id: dmouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: dcard.modelData.big ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                    onClicked: if (dcard.modelData.big) { win.disk = dcard.modelData.path; win.understood = false }
                                }
                            }
                        }
                        Text {
                            visible: backend.disks.length === 0
                            text: "No disks found. Plug one in and it will show up here."
                            color: Theme.textVariant
                            font.pixelSize: 15
                        }
                        Item { width: 1; height: 8 }
                        Row {
                            spacing: 8
                            Repeater {
                                model: [["bolt", "Btrfs, compressed"], ["history", "Automatic snapshots"], ["memory_alt", "zram swap"], [backend.uefi ? "verified_user" : "settings", backend.uefi ? "systemd-boot" : "GRUB"]]
                                delegate: Rectangle {
                                    required property var modelData
                                    height: 34
                                    width: chipRow.implicitWidth + 28
                                    radius: 10
                                    color: "transparent"
                                    border.color: Theme.outline
                                    Row {
                                        id: chipRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Sym { text: modelData[0]; size: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: modelData[1]; color: Theme.textVariant; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                }
                            }
                        }
                        Item { width: 1; height: 8 }
                        Rectangle {
                            visible: win.disk !== ""
                            width: diskCol.width
                            height: 76
                            radius: 24
                            color: Theme.dangerContainer
                            Sym { x: 22; anchors.verticalCenter: parent.verticalCenter; text: "warning"; fill: 1; color: Theme.danger }
                            Text {
                                x: 60
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 60 - understandRow.width - 30
                                wrapMode: Text.WordWrap
                                text: "Everything on " + (win.diskInfo ? win.diskInfo.model + " (" + win.diskInfo.sizeText + ")" : "") + " will be erased."
                                color: Theme.text
                                font.pixelSize: 14
                            }
                            Row {
                                id: understandRow
                                anchors.right: parent.right
                                anchors.rightMargin: 20
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10
                                Rectangle {
                                    width: 24; height: 24; radius: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: win.understood ? Theme.danger : "transparent"
                                    border.width: win.understood ? 0 : 2
                                    border.color: Theme.danger
                                    Sym { anchors.centerIn: parent; visible: win.understood; text: "check"; size: 18; color: Theme.dangerContainer }
                                }
                                Text { text: "I understand"; color: Theme.text; font.pixelSize: 14; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea {
                                anchors.fill: understandRow
                                anchors.margins: -10
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.understood = !win.understood
                            }
                        }
                    }
                }
            }

            Page {
                index: 3
                PageHeader { id: h3; icon: "person"; title: "Who are you?"; subtitle: "This is the account you'll use every day." }
                GridLayout {
                    anchors.top: h3.bottom
                    anchors.topMargin: 32
                    width: Math.min(parent.width, 680)
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 14
                    M3Field {
                        Layout.fillWidth: true
                        Layout.columnSpan: 2
                        label: "Your name"
                        icon: "badge"
                        text: win.fullname
                        onEdited: win.fullname = text
                    }
                    M3Field {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        label: "Username"
                        icon: "alternate_email"
                        text: win.username
                        error: win.usernameError
                        onEdited: { win.usernameTouched = true; win.username = text }
                    }
                    M3Field {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        label: "Computer name"
                        icon: "computer"
                        text: win.hostname
                        error: win.hostnameError
                        onEdited: win.hostname = text
                    }
                    M3Field {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        label: "Password"
                        icon: "lock"
                        password: true
                        hint: win.password !== "" && win.password.length < 6 ? "Short passwords are easy to guess" : ""
                        onEdited: win.password = text
                    }
                    M3Field {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        label: "Confirm password"
                        icon: "lock_reset"
                        password: true
                        error: win.passwordError
                        onEdited: win.password2 = text
                    }
                    Rectangle {
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        height: 72
                        radius: 24
                        color: Theme.surface2
                        Sym { x: 20; anchors.verticalCenter: parent.verticalCenter; text: "login"; color: Theme.primary }
                        Column {
                            x: 58
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "Log in automatically"; color: Theme.text; font.pixelSize: 15; font.weight: Font.Medium }
                            Text { text: "Skip the login screen when the computer starts"; color: Theme.textVariant; font.pixelSize: 13 }
                        }
                        Rectangle {
                            id: sw
                            anchors.right: parent.right
                            anchors.rightMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            width: 52; height: 32; radius: 16
                            color: win.autologin ? Theme.primary : Theme.surface4
                            border.width: win.autologin ? 0 : 2
                            border.color: Theme.outline
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                            Rectangle {
                                width: win.autologin ? 24 : 16
                                height: width
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: win.autologin ? parent.width - width - 4 : 8
                                color: win.autologin ? Theme.inkPrimary : Theme.textVariant
                                Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                                Behavior on width { NumberAnimation { duration: Theme.fast } }
                                Sym { anchors.centerIn: parent; visible: win.autologin; text: "check"; size: 16; color: Theme.primary }
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.autologin = !win.autologin }
                    }
                }
            }

            Page {
                index: 4
                PageHeader { id: h4; icon: "checklist"; title: "Ready when you are"; subtitle: "Check everything looks right, then press Install." }
                Card {
                    anchors.top: h4.bottom
                    anchors.topMargin: 28
                    width: parent.width
                    height: reviewCol.height + 16
                    Column {
                        id: reviewCol
                        y: 8
                        width: parent.width
                        ReviewRow { icon: "translate"; label: "Language"; value: win.localeName(win.sysLocale); target: 0 }
                        ReviewRow { icon: "schedule"; label: "Time zone"; value: win.timezone.replace(/_/g, " "); target: 1 }
                        ReviewRow { icon: "keyboard"; label: "Keyboard"; value: win.keymapName(win.keymap); target: 1 }
                        ReviewRow { icon: "hard_drive"; label: "Disk (will be erased)"; value: win.diskInfo ? win.diskInfo.model + "  ·  " + win.diskInfo.path + "  ·  " + win.diskInfo.sizeText : ""; target: 2 }
                        ReviewRow { icon: "person"; label: "Account"; value: (win.fullname ? win.fullname + "  ·  " : "") + win.username + "@" + win.hostname + (win.autologin ? "  ·  logs in automatically" : ""); target: 3 }
                        ReviewRow { icon: "deployed_code"; label: "Software"; value: "Fiordland desktop, Firefox, tawaki, Flathub" }
                    }
                }
            }

            Page {
                index: 5
                Column {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: logPane.visible ? -150 : -20
                    Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic } }
                    width: Math.min(parent.width, 560)
                    spacing: 0
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: "logo.svg"; width: 84; height: 84; sourceSize: Qt.size(168, 168)
                        SequentialAnimation on y {
                            running: win.step === 5
                            loops: Animation.Infinite
                            NumberAnimation { from: 0; to: -8; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { from: -8; to: 0; duration: 900; easing.type: Easing.InOutSine }
                        }
                    }
                    Item { width: 1; height: 26 }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Installing Fiordland"
                        color: Theme.text
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                    }
                    Item { width: 1; height: 6 }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: backend.status || "Getting ready"
                        color: Theme.textVariant
                        font.pixelSize: 15
                    }
                    Item { width: 1; height: 26 }
                    Rectangle {
                        width: parent.width
                        height: 12
                        radius: 6
                        color: Theme.surface3
                        Rectangle {
                            height: parent.height
                            radius: 6
                            width: Math.max(12, parent.width * backend.progress)
                            color: Theme.primary
                            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                        }
                    }
                    Item { width: 1; height: 10 }
                    Text {
                        anchors.right: parent.right
                        text: Math.round(backend.progress * 100) + "%"
                        color: Theme.textVariant
                        font.pixelSize: 13
                        font.features: { "tnum": 1 }
                    }
                    Item { width: 1; height: 22 }
                    Card {
                        id: tipCard
                        width: parent.width
                        height: 92
                        color: Theme.surface2
                        property int tip: 0
                        readonly property var tips: [
                            ["deployed_code", "One command for every app", "tawaki install spotify finds the cleanest source for you: pacman, Flathub or the AUR."],
                            ["history", "Undo almost anything", "Your system takes Btrfs snapshots automatically, so a bad update is never the end."],
                            ["keyboard_command_key", "Super + Space", "Opens the app launcher. Super + Return opens a terminal, Super + Q closes a window."],
                            ["update", "Stay fresh", "tawaki update updates system packages, Flatpaks and AUR packages in one go."],
                            ["pets", "Why a penguin?", "The tawaki is a crested penguin that lives in the rainforests of Fiordland, New Zealand."]
                        ]
                        Timer { interval: 6500; running: win.step === 5; repeat: true; onTriggered: { tipBody.opacity = 0; tipSwap.start() } }
                        Timer { id: tipSwap; interval: 220; onTriggered: { tipCard.tip = (tipCard.tip + 1) % tipCard.tips.length; tipBody.opacity = 1 } }
                        Row {
                            id: tipBody
                            anchors.verticalCenter: parent.verticalCenter
                            x: 20
                            spacing: 16
                            Behavior on opacity { NumberAnimation { duration: 220 } }
                            Rectangle {
                                width: 48; height: 48; radius: 16
                                color: Theme.primaryContainer
                                anchors.verticalCenter: parent.verticalCenter
                                Sym { anchors.centerIn: parent; text: tipCard.tips[tipCard.tip][0]; color: Theme.inkPrimaryContainer; fill: 1 }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: tipCard.width - 104
                                spacing: 3
                                Text { text: tipCard.tips[tipCard.tip][1]; color: Theme.text; font.pixelSize: 15; font.weight: Font.DemiBold }
                                Text { text: tipCard.tips[tipCard.tip][2]; color: Theme.textVariant; font.pixelSize: 13; wrapMode: Text.WordWrap; width: parent.width }
                            }
                        }
                    }
                    Item { width: 1; height: 12 }
                    M3Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        kind: "text"
                        icon: logPane.visible ? "expand_less" : "terminal"
                        text: logPane.visible ? "Hide details" : "Show details"
                        onClicked: logPane.visible = !logPane.visible
                    }
                }
                Rectangle {
                    id: logPane
                    visible: false
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    width: parent.width
                    height: 230
                    radius: 20
                    color: "#0a0e12"
                    border.color: Theme.outlineVariant
                    ListView {
                        id: logView
                        anchors.fill: parent
                        anchors.margins: 14
                        model: logModel
                        clip: true
                        onCountChanged: Qt.callLater(positionViewAtEnd)
                        delegate: Text {
                            required property string line
                            width: ListView.view.width
                            text: line
                            color: line.startsWith("$ ") ? Theme.primary : line.startsWith("error") ? Theme.danger : Theme.textVariant
                            font.family: Theme.mono
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Page {
                index: 6
                Column {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 20
                    width: Math.min(parent.width, 520)
                    spacing: 0
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 104; height: 104; radius: 52
                        color: win.failed ? Theme.dangerContainer : Theme.primaryContainer
                        scale: win.step === 6 ? 1 : 0.6
                        Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }
                        Sym { anchors.centerIn: parent; text: win.failed ? "error" : "check_circle"; size: 54; fill: 1; color: win.failed ? Theme.danger : Theme.primary }
                    }
                    Item { width: 1; height: 28 }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.failed ? "That didn't work" : "Fiordland is ready"
                        color: Theme.text
                        font.pixelSize: 32
                        font.weight: Font.Bold
                    }
                    Item { width: 1; height: 10 }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: win.failed
                            ? (win.errorText + "\nYour disk may be partly set up. You can try again, or save the log and ask for help.")
                            : "Restart your computer and remove the install media. Welcome to the colony, " + (win.fullname.split(" ")[0] || win.username) + "."
                        color: Theme.textVariant
                        font.pixelSize: 15
                        lineHeight: 1.35
                    }
                    Item { width: 1; height: 32 }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12
                        M3Button {
                            visible: !win.failed
                            text: "Restart now"; icon: "restart_alt"; implicitHeight: 52
                            onClicked: backend.reboot()
                        }
                        M3Button {
                            visible: !win.failed
                            text: "Keep exploring"; kind: "outlined"; implicitHeight: 52
                            onClicked: backend.quit()
                        }
                        M3Button {
                            visible: win.failed
                            text: "Try again"; icon: "refresh"; implicitHeight: 52
                            onClicked: win.step = 4
                        }
                        M3Button {
                            visible: win.failed
                            text: "Save log"; kind: "outlined"; icon: "save"; implicitHeight: 52
                            onClicked: { backend.saveLog(); text = "Saved to ~/rawaru.log" }
                        }
                    }
                }
            }
        }

        Item {
            id: bar
            anchors.left: rail.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 92
            visible: win.step >= 1 && win.step <= 4
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 44
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                M3Button { kind: "text"; text: "Back"; onClicked: win.step-- }
                M3Button {
                    text: win.step === 4 ? "Install" : "Next"
                    icon: win.step === 4 ? "download" : "arrow_forward"
                    enabled: win.canNext
                    implicitHeight: 48
                    onClicked: win.next()
                }
            }
        }
    }

    Shortcut { sequences: ["Return", "Enter"]; enabled: win.step >= 1 && win.step <= 3; onActivated: win.next() }
}
