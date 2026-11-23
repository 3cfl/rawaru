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
    Material.accent: Theme.accent
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
    property string kernel: "cachyos"
    property string desktop: "plasma"
    property string dots: ""
    property bool wmTab: false
    property bool failed: false
    property string errorText: ""

    readonly property var steps: [
        { label: "Region", title: "Where are you?", sub: "Time zone and keyboard layout." },
        { label: "Disk", title: "Choose a disk", sub: "Fiordland takes the whole disk." },
        { label: "Account", title: "Your account", sub: "The user you'll log in as every day." },
        { label: "Desktop", title: "Pick a desktop", sub: "You can install others later with tawaki." },
        { label: "Review", title: "Review", sub: "Nothing has been changed yet." },
        { label: "Install", title: "", sub: "" }
    ]
    readonly property var reserved: ["root", "bin", "daemon", "mail", "ftp", "http", "nobody", "dbus", "systemd-network",
        "systemd-resolve", "systemd-timesync", "systemd-coredump", "uuidd", "greeter", "polkitd", "rtkit", "git", "avahi"]
    readonly property string usernameError: username === "" ? ""
        : !/^[a-z_][a-z0-9_-]{0,31}$/.test(username) ? "Lowercase letters, numbers, - and _ only"
        : reserved.indexOf(username) >= 0 ? "That name is used by the system" : ""
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
        : step === 4 ? desktopSel !== null
        : true

    function desktopInfo(id) {
        for (const d of backend.desktops) if (d.id === id) return d
        return null
    }
    function shellInfo(d, id) {
        if (!d) return null
        for (let i = 0; i < d.shells.length; i++) if (d.shells[i].id === id) return d.shells[i]
        return null
    }
    function pickDesktop(d) {
        desktop = d.id
        dots = d.shells.length ? d.shells[0].id : ""
    }
    readonly property var desktopSel: desktopInfo(desktop)
    readonly property var shellSel: shellInfo(desktopSel, dots)

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
        if (step < 1 || step > 5 || !canNext) return
        if (step === 5) { startInstall(); return }
        step++
    }
    function startInstall() {
        failed = false
        errorText = ""
        logModel.clear()
        step = 6
        backend.install({
            disk: disk, locale: sysLocale, timezone: timezone, keymap: keymap, fullname: fullname,
            username: username, hostname: hostname, password: password, autologin: autologin, kernel: kernel,
            desktop: desktop, shell: dots
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
            win.step = 7
        }
    }
    ListModel { id: logModel }

    component Label: Text {
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: 13
    }

    component Page: Item {
        property int index
        readonly property bool active: win.step === index
        anchors.fill: parent
        opacity: active ? 1 : 0
        visible: opacity > 0
        enabled: active
        transform: Translate { y: active ? 0 : 12; Behavior on y { NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic } }
    }

    component Header: Column {
        property int index
        spacing: 6
        Text { text: "Step " + parent.index + " of 5"; color: Theme.faint; font.pixelSize: 12; font.weight: Font.Medium }
        Text { text: win.steps[parent.index - 1].title; color: Theme.text; font.pixelSize: 26; font.weight: Font.DemiBold; font.letterSpacing: -0.4 }
        Text { text: win.steps[parent.index - 1].sub; color: Theme.muted; font.pixelSize: 14 }
    }

    component Check: Rectangle {
        property bool on: false
        property color tint: Theme.accent
        width: 18; height: 18; radius: 4
        color: on ? tint : "transparent"
        border.width: on ? 0 : 1.5
        border.color: Theme.lineStrong
        Glyph { anchors.centerIn: parent; visible: parent.on; kind: "check"; width: 14; height: 14; stroke: 2; color: Theme.accentInk }
    }

    component Radio: Rectangle {
        property bool on: false
        width: 18; height: 18; radius: 9
        color: "transparent"
        border.width: 1.5
        border.color: on ? Theme.accent : Theme.lineStrong
        Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Theme.accent; visible: parent.on }
    }

    component ReviewRow: Item {
        property string label
        property string value
        property int target: -1
        property bool last: false
        width: parent.width
        height: 40
        Text { x: 18; width: 150; anchors.verticalCenter: parent.verticalCenter; text: parent.label; color: Theme.muted; font.pixelSize: 13 }
        Text {
            x: 170
            width: parent.width - 170 - 90
            anchors.verticalCenter: parent.verticalCenter
            text: parent.value
            color: Theme.text
            font.pixelSize: 14
            elide: Text.ElideRight
        }
        FButton {
            visible: parent.target >= 0
            kind: "link"; text: "Change"
            anchors.right: parent.right; anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            onClicked: win.step = parent.target
        }
        Rectangle { visible: !parent.last; anchors.bottom: parent.bottom; x: 18; width: parent.width - 36; height: 1; color: Theme.line }
    }

    Item {
        id: welcome
        anchors.fill: parent
        opacity: win.step === 0 ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }

        Image {
            anchors.fill: parent
            source: backend.wallpaper
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 2080
            asynchronous: true
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.063, 0.067, 0.075, 0.35) }
                GradientStop { position: 0.5; color: Qt.rgba(0.063, 0.067, 0.075, 0.55) }
                GradientStop { position: 1.0; color: Qt.rgba(0.063, 0.067, 0.075, 0.96) }
            }
        }

        Row {
            id: langRow
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 28
            spacing: 4
            Text { text: win.localeName(win.sysLocale); color: Theme.text; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            Glyph { kind: "chevron"; width: 16; height: 16; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { anchors.fill: langRow; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: langPopup.open() }

        Column {
            x: 64
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 64
            spacing: 0
            Text { text: "Fiordland"; color: Theme.text; font.pixelSize: 76; font.weight: Font.Bold; font.letterSpacing: -2.5 }
            Item { width: 1; height: 12 }
            Text {
                width: 460
                wrapMode: Text.WordWrap
                text: "Install it on this computer, or keep using the live session. Your disk isn't touched until the last step."
                color: Theme.muted
                font.pixelSize: 16
                lineHeight: 1.3
            }
            Item { width: 1; height: 28 }
            Row {
                spacing: 10
                FButton { text: "Install"; implicitWidth: 120; implicitHeight: 42; onClicked: win.step = 1 }
                FButton { text: "Keep trying it"; kind: "ghost"; implicitHeight: 42; onClicked: backend.quit() }
            }
        }
        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 28
            text: backend.dryRun ? "Preview mode" : "Fiordland 1"
            color: Theme.faint
            font.pixelSize: 12
        }
    }

    Popup {
        id: langPopup
        anchors.centerIn: parent
        width: 440
        height: 500
        modal: true
        padding: 20
        background: Rectangle { radius: 12; color: Theme.raised; border.color: Theme.line }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.fast } }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.fast } }
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.55) }
        Column {
            anchors.fill: parent
            spacing: 14
            Text { text: "Language"; color: Theme.text; font.pixelSize: 18; font.weight: Font.DemiBold }
            Chooser {
                width: parent.width
                height: parent.height - 40
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
        Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }

        Rectangle {
            id: rail
            width: 220
            height: parent.height
            color: Theme.panel
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.line }

            Text { x: 28; y: 30; text: "Fiordland"; color: Theme.text; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: -0.3 }

            Column {
                x: 0; y: 92
                width: parent.width - 1
                Repeater {
                    model: win.steps
                    delegate: Item {
                        required property var modelData
                        required property int index
                        readonly property int num: index + 1
                        readonly property bool current: win.step === num || (win.step === 7 && num === 6)
                        readonly property bool done: win.step > num && !(win.step === 7 && num === 6)
                        width: parent.width
                        height: 38
                        Rectangle {
                            width: 2; height: 18
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.accent
                            opacity: parent.current ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                        }
                        Text {
                            x: 28; width: 18
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !parent.done
                            text: parent.num
                            color: parent.current ? Theme.accent : Theme.faint
                            font.pixelSize: 13
                            font.features: { "tnum": 1 }
                        }
                        Glyph {
                            x: 27
                            anchors.verticalCenter: parent.verticalCenter
                            visible: parent.done
                            kind: "check"; width: 14; height: 14; color: Theme.muted
                        }
                        Text {
                            x: 50
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.label
                            color: parent.current ? Theme.text : parent.done ? Theme.muted : Theme.faint
                            font.pixelSize: 14
                            font.weight: parent.current ? Font.Medium : Font.Normal
                        }
                    }
                }
            }

            Column {
                x: 28
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26
                spacing: 3
                Text { text: backend.uefi ? "UEFI system" : "BIOS system"; color: Theme.faint; font.pixelSize: 12 }
                Text { visible: backend.dryRun; text: "Preview, nothing is written"; color: Theme.accent; font.pixelSize: 12 }
            }
        }

        Item {
            id: content
            anchors.left: rail.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: bar.top
            anchors.leftMargin: 48
            anchors.rightMargin: 48
            anchors.topMargin: 44

            Page {
                index: 1
                Header { id: h1; index: 1 }
                RowLayout {
                    anchors.top: h1.bottom
                    anchors.topMargin: 28
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    width: parent.width
                    spacing: 20
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        spacing: 8
                        Label { text: "Time zone" }
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
                        spacing: 8
                        Label { text: "Keyboard" }
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
                        Field { Layout.fillWidth: true; Layout.topMargin: 6; placeholder: "Type here to test the layout" }
                    }
                }
            }

            Page {
                index: 2
                Header { id: h2; index: 2 }
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
                        spacing: 16
                        Rectangle {
                            width: parent.width
                            height: Math.max(diskList.height, 64)
                            radius: Theme.radius
                            color: Theme.panel
                            border.color: Theme.line
                            Column {
                                id: diskList
                                width: parent.width
                                Repeater {
                                    model: backend.disks
                                    delegate: Item {
                                        id: drow
                                        required property var modelData
                                        required property int index
                                        readonly property bool selected: win.disk === modelData.path
                                        width: diskList.width
                                        height: 64
                                        opacity: modelData.big ? 1 : 0.45
                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            radius: Theme.radius - 1
                                            color: dmouse.containsMouse && drow.modelData.big ? Theme.hover : "transparent"
                                        }
                                        Radio { x: 18; anchors.verticalCenter: parent.verticalCenter; on: drow.selected }
                                        Column {
                                            x: 50
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 3
                                            Text { text: drow.modelData.model; color: Theme.text; font.pixelSize: 14; font.weight: Font.Medium }
                                            Text {
                                                text: drow.modelData.path + "   " + (drow.modelData.big
                                                    ? (drow.modelData.parts > 0 ? drow.modelData.parts + " partition" + (drow.modelData.parts > 1 ? "s" : "") : "empty")
                                                    : "too small, needs 20 GB")
                                                color: Theme.faint
                                                font.pixelSize: 12
                                                font.family: Theme.mono
                                            }
                                        }
                                        Text {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 18
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: drow.modelData.sizeText
                                            color: Theme.text
                                            font.pixelSize: 14
                                            font.features: { "tnum": 1 }
                                        }
                                        Rectangle {
                                            visible: drow.index < backend.disks.length - 1
                                            anchors.bottom: parent.bottom
                                            x: 18; width: parent.width - 36; height: 1
                                            color: Theme.line
                                        }
                                        MouseArea {
                                            id: dmouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: drow.modelData.big ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                            onClicked: if (drow.modelData.big && win.disk !== drow.modelData.path) { win.disk = drow.modelData.path; win.understood = false }
                                        }
                                    }
                                }
                            }
                            Text {
                                visible: backend.disks.length === 0
                                anchors.centerIn: parent
                                text: "No disks found. Plug one in and it shows up here."
                                color: Theme.muted
                                font.pixelSize: 14
                            }
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: "Btrfs with compression and automatic snapshots, zram swap, " + (backend.uefi ? "systemd-boot." : "GRUB.")
                            color: Theme.faint
                            font.pixelSize: 13
                        }
                        Item {
                            visible: win.disk !== ""
                            width: parent.width
                            height: 40
                            Row {
                                id: eraseRow
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12
                                Check { on: win.understood; tint: Theme.danger; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Erase everything on " + (win.diskInfo ? win.diskInfo.model + " (" + win.diskInfo.sizeText + ")" : "")
                                    color: win.understood ? Theme.danger : Theme.text
                                    font.pixelSize: 14
                                }
                            }
                            MouseArea { anchors.fill: eraseRow; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: win.understood = !win.understood }
                        }
                    }
                }
            }

            Page {
                index: 3
                Header { id: h3; index: 3 }
                GridLayout {
                    anchors.top: h3.bottom
                    anchors.topMargin: 28
                    width: Math.min(parent.width, 620)
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 16
                    Field {
                        Layout.fillWidth: true
                        Layout.columnSpan: 2
                        label: "Name"
                        text: win.fullname
                        onEdited: win.fullname = text
                    }
                    Field {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        label: "Username"
                        text: win.username
                        error: win.usernameError
                        onEdited: { win.usernameTouched = true; win.username = text }
                    }
                    Field {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        label: "Computer name"
                        text: win.hostname
                        error: win.hostnameError
                        onEdited: win.hostname = text
                    }
                    Field {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        label: "Password"
                        password: true
                        hint: win.password !== "" && win.password.length < 6 ? "Short passwords are easy to guess" : ""
                        onEdited: win.password = text
                    }
                    Field {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        label: "Confirm password"
                        password: true
                        error: win.passwordError
                        onEdited: win.password2 = text
                    }
                    Item {
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        implicitHeight: 44
                        Row {
                            id: autoRow
                            spacing: 12
                            Check { on: win.autologin; y: 2 }
                            Column {
                                spacing: 3
                                Text { text: "Log in automatically"; color: Theme.text; font.pixelSize: 14 }
                                Text { text: "Skip the login screen when the computer starts."; color: Theme.faint; font.pixelSize: 12 }
                            }
                        }
                        MouseArea { anchors.fill: autoRow; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: win.autologin = !win.autologin }
                    }
                }
            }

            Page {
                index: 4
                Header { id: h4; index: 4 }
                Row {
                    id: dtabs
                    anchors.top: h4.bottom
                    anchors.topMargin: 24
                    spacing: 8
                    Repeater {
                        model: [[false, "Desktops"], [true, "Window managers"]]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool on: win.wmTab === modelData[0]
                            width: tabText.implicitWidth + 32
                            height: 34
                            radius: 17
                            color: on ? Theme.accent : tabMouse.containsMouse ? Theme.hover : Theme.panel
                            border.color: on ? Theme.accent : Theme.line
                            Text { id: tabText; anchors.centerIn: parent; text: parent.modelData[1]; color: parent.on ? Theme.accentInk : Theme.text; font.pixelSize: 13; font.weight: Font.Medium }
                            MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.wmTab = parent.modelData[0] }
                        }
                    }
                }
                Rectangle {
                    id: dlist
                    anchors.top: dtabs.bottom
                    anchors.topMargin: 16
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 20
                    width: win.wmTab && win.desktopSel && win.desktopSel.kind === "wm" && win.desktopSel.shells.length ? (parent.width - 16) * 0.42 : parent.width
                    radius: Theme.radius
                    color: Theme.panel
                    border.color: Theme.line
                    clip: true
                    ListView {
                        id: dview
                        anchors.fill: parent
                        anchors.margins: 1
                        boundsBehavior: Flickable.StopAtBounds
                        model: backend.desktops.filter(d => (d.kind === "wm") === win.wmTab)
                        delegate: Item {
                            id: drow
                            required property var modelData
                            required property int index
                            width: dview.width
                            height: 60
                            Rectangle { anchors.fill: parent; radius: Theme.radius - 1; color: dmouse.containsMouse ? Theme.hover : "transparent" }
                            Radio { x: 18; anchors.verticalCenter: parent.verticalCenter; on: win.desktop === drow.modelData.id }
                            Column {
                                x: 50
                                width: parent.width - 70
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3
                                Row {
                                    spacing: 8
                                    Text { text: drow.modelData.name; color: Theme.text; font.pixelSize: 14 }
                                    Text { visible: drow.modelData.recommended; text: "Recommended"; color: Theme.accent; font.pixelSize: 12; anchors.baseline: parent.children[0].baseline }
                                }
                                Text { text: drow.modelData.desc; color: Theme.faint; font.pixelSize: 12; width: parent.width; elide: Text.ElideRight }
                            }
                            Rectangle { visible: drow.index < dview.count - 1; anchors.bottom: parent.bottom; x: 18; width: parent.width - 36; height: 1; color: Theme.line }
                            MouseArea { id: dmouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.pickDesktop(drow.modelData) }
                        }
                    }
                }
                Column {
                    anchors.top: dlist.top
                    anchors.left: dlist.right
                    anchors.leftMargin: 16
                    anchors.right: parent.right
                    spacing: 8
                    visible: dlist.width < content.width - 1
                    Label { text: "Shell for " + (win.desktopSel ? win.desktopSel.name : "") }
                    Rectangle {
                        width: parent.width
                        height: Math.min(scol.implicitHeight + 2, dlist.height - 26)
                        radius: Theme.radius
                        color: Theme.panel
                        border.color: Theme.line
                        clip: true
                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 1
                            contentHeight: scol.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            Column {
                                id: scol
                                width: parent.width
                                Repeater {
                                    model: win.desktopSel ? win.desktopSel.shells : []
                                    delegate: Item {
                                        id: srow
                                        required property var modelData
                                        required property int index
                                        width: scol.width
                                        height: scell.implicitHeight + 24
                                        Rectangle { anchors.fill: parent; radius: Theme.radius - 1; color: smouse.containsMouse ? Theme.hover : "transparent" }
                                        Radio { x: 18; anchors.verticalCenter: parent.verticalCenter; on: win.dots === srow.modelData.id }
                                        Column {
                                            id: scell
                                            x: 50
                                            width: parent.width - 66
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 3
                                            Row {
                                                spacing: 8
                                                Text { text: srow.modelData.name; color: Theme.text; font.pixelSize: 14 }
                                                Text { visible: srow.modelData.by !== ""; text: srow.modelData.by; color: Theme.faint; font.pixelSize: 12; anchors.baseline: parent.children[0].baseline }
                                            }
                                            Text { text: srow.modelData.desc; color: Theme.faint; font.pixelSize: 12; width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                                            Text { visible: srow.modelData.script; text: "Installs on first login with its own setup script"; color: Theme.accent; font.pixelSize: 11 }
                                        }
                                        Rectangle { visible: srow.index < (win.desktopSel ? win.desktopSel.shells.length : 0) - 1; anchors.bottom: parent.bottom; x: 18; width: parent.width - 36; height: 1; color: Theme.line }
                                        MouseArea { id: smouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.dots = srow.modelData.id }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Page {
                index: 5
                Header { id: h5; index: 5 }
                Column {
                    anchors.top: h5.bottom
                    anchors.topMargin: 28
                    width: parent.width
                    spacing: 20
                    Rectangle {
                        width: parent.width
                        height: reviewCol.height
                        radius: Theme.radius
                        color: Theme.panel
                        border.color: Theme.line
                        Column {
                            id: reviewCol
                            width: parent.width
                            ReviewRow { label: "Language"; value: win.localeName(win.sysLocale); target: 0 }
                            ReviewRow { label: "Time zone"; value: win.timezone.replace(/_/g, " "); target: 1 }
                            ReviewRow { label: "Keyboard"; value: win.keymapName(win.keymap); target: 1 }
                            ReviewRow { label: "Disk"; value: win.diskInfo ? win.diskInfo.model + ", " + win.diskInfo.sizeText + ", will be erased" : ""; target: 2 }
                            ReviewRow { label: "Account"; value: (win.fullname ? win.fullname + ", " : "") + win.username + "@" + win.hostname + (win.autologin ? ", automatic login" : ""); target: 3 }
                            ReviewRow { label: "Desktop"; value: win.desktopSel ? win.desktopSel.name + (win.shellSel && win.shellSel.id !== "none" ? " with " + win.shellSel.name : "") : ""; target: 4 }
                            ReviewRow { label: "Graphics"; value: backend.graphics; last: true }
                        }
                    }
                    Column {
                        width: parent.width
                        spacing: 8
                        Label { text: "Kernel" }
                        Rectangle {
                            width: parent.width
                            height: kcol.height
                            radius: Theme.radius
                            color: Theme.panel
                            border.color: Theme.line
                            Column {
                                id: kcol
                                width: parent.width
                                Repeater {
                                    model: [
                                        ["cachyos", "CachyOS kernel", "Tuned for responsiveness and games. The Arch kernel stays installed as a backup boot option."],
                                        ["arch", "Arch kernel", "The stock Arch Linux kernel, nothing else added."]
                                    ]
                                    delegate: Item {
                                        id: krow
                                        required property var modelData
                                        required property int index
                                        width: kcol.width
                                        height: 60
                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            radius: Theme.radius - 1
                                            color: kmouse.containsMouse ? Theme.hover : "transparent"
                                        }
                                        Radio { x: 18; anchors.verticalCenter: parent.verticalCenter; on: win.kernel === krow.modelData[0] }
                                        Column {
                                            x: 50
                                            width: parent.width - 70
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 3
                                            Text { text: krow.modelData[1]; color: Theme.text; font.pixelSize: 14 }
                                            Text { text: krow.modelData[2]; color: Theme.faint; font.pixelSize: 12; width: parent.width; elide: Text.ElideRight }
                                        }
                                        Rectangle {
                                            visible: krow.index === 0
                                            anchors.bottom: parent.bottom
                                            x: 18; width: parent.width - 36; height: 1
                                            color: Theme.line
                                        }
                                        MouseArea { id: kmouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.kernel = krow.modelData[0] }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Page {
                index: 6
                Column {
                    id: prog
                    y: logPane.visible ? 40 : Math.max(40, (parent.height - height) / 2 - 20)
                    Behavior on y { NumberAnimation { duration: Theme.medium; easing.type: Easing.OutCubic } }
                    width: Math.min(parent.width, 560)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0
                    Text { text: "Installing Fiordland"; color: Theme.text; font.pixelSize: 26; font.weight: Font.DemiBold; font.letterSpacing: -0.4 }
                    Item { width: 1; height: 8 }
                    Item {
                        width: parent.width
                        height: 20
                        Text {
                            width: parent.width - 50
                            elide: Text.ElideRight
                            text: backend.status || "Getting ready"
                            color: Theme.muted
                            font.pixelSize: 14
                        }
                        Text {
                            anchors.right: parent.right
                            text: Math.round(backend.progress * 100) + "%"
                            color: Theme.muted
                            font.pixelSize: 14
                            font.features: { "tnum": 1 }
                        }
                    }
                    Item { width: 1; height: 16 }
                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Theme.line
                        Rectangle {
                            height: parent.height
                            radius: 2
                            width: parent.width * backend.progress
                            color: Theme.accent
                            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                        }
                    }
                    Item { width: 1; height: 36 }
                    Item {
                        id: tip
                        width: parent.width
                        height: 64
                        property int n: 0
                        readonly property var tips: [
                            ["tawaki install spotify", "One command for every app. tawaki picks pacman, Flathub or the AUR for you."],
                            ["tawaki update", "Updates system packages, Flatpaks and AUR packages together."],
                            ["Snapshots", "Btrfs snapshots are taken before every update, so a bad one can be rolled back."],
                            ["Flatpak and AUR", "Flathub and the AUR are set up already. tawaki search finds apps in both."]
                        ]
                        Timer { interval: 7000; running: win.step === 6; repeat: true; onTriggered: { tipBody.opacity = 0; tipSwap.start() } }
                        Timer { id: tipSwap; interval: 200; onTriggered: { tip.n = (tip.n + 1) % tip.tips.length; tipBody.opacity = 1 } }
                        Column {
                            id: tipBody
                            width: parent.width
                            spacing: 4
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Text { text: tip.tips[tip.n][0]; color: Theme.text; font.pixelSize: 13; font.family: Theme.mono }
                            Text { text: tip.tips[tip.n][1]; color: Theme.faint; font.pixelSize: 13; wrapMode: Text.WordWrap; width: parent.width }
                        }
                    }
                    Item { width: 1; height: 8 }
                    FButton {
                        kind: "link"
                        text: logPane.visible ? "Hide details" : "Show details"
                        onClicked: logPane.visible = !logPane.visible
                    }
                }
                Rectangle {
                    id: logPane
                    visible: false
                    anchors.top: prog.bottom
                    anchors.topMargin: 20
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 32
                    width: parent.width
                    radius: Theme.radius
                    color: "#0b0c0e"
                    border.color: Theme.line
                    ListView {
                        anchors.fill: parent
                        anchors.margins: 14
                        model: logModel
                        clip: true
                        onCountChanged: Qt.callLater(positionViewAtEnd)
                        delegate: Text {
                            required property string line
                            width: ListView.view.width
                            text: line
                            color: line.startsWith("$ ") ? Theme.accent : line.startsWith("error") ? Theme.danger : Theme.faint
                            font.family: Theme.mono
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Page {
                index: 7
                Column {
                    y: Math.max(40, (parent.height - height) / 2 - 20)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width, 560)
                    spacing: 0
                    Text {
                        text: win.failed ? "Installation failed" : "Done"
                        color: win.failed ? Theme.danger : Theme.text
                        font.pixelSize: 34
                        font.weight: Font.DemiBold
                        font.letterSpacing: -0.6
                    }
                    Item { width: 1; height: 10 }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: win.failed
                            ? win.errorText + "\n\nThe disk may be partly set up. Try again, or save the log and ask for help."
                            : "Fiordland is installed. Restart and remove the install media, then log in as " + win.username + "."
                        color: Theme.muted
                        font.pixelSize: 15
                        lineHeight: 1.3
                    }
                    Item { width: 1; height: 28 }
                    Row {
                        spacing: 10
                        FButton { visible: !win.failed; text: "Restart now"; implicitHeight: 42; onClicked: backend.reboot() }
                        FButton { visible: !win.failed; text: "Keep exploring"; kind: "ghost"; implicitHeight: 42; onClicked: backend.quit() }
                        FButton { visible: win.failed; text: "Try again"; implicitHeight: 42; onClicked: win.step = 5 }
                        FButton {
                            visible: win.failed
                            text: "Save log"; kind: "ghost"; implicitHeight: 42
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
            height: 76
            visible: win.step >= 1 && win.step <= 5
            Rectangle { width: parent.width; height: 1; color: Theme.line }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 48
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                FButton { kind: "ghost"; text: "Back"; onClicked: win.step-- }
                FButton {
                    text: win.step === 5 ? "Install" : "Continue"
                    implicitWidth: 112
                    enabled: win.canNext
                    onClicked: win.next()
                }
            }
        }
    }

    Shortcut { sequences: ["Return", "Enter"]; enabled: win.step >= 1 && win.step <= 4; onActivated: win.next() }
}
