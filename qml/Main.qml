pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as C

C.ApplicationWindow {
    id: win

    required property var backend

    width: Math.min(1180, Screen.desktopAvailableWidth)
    height: Math.min(800, Screen.desktopAvailableHeight)
    minimumWidth: 900
    minimumHeight: 640
    visible: true
    title: "Install Fiordland"
    color: Theme.surface
    font.family: Theme.font

    readonly property bool softwareGfx: shell.GraphicsInfo.api === GraphicsInfo.Software
    readonly property bool lowEndUi: backend.lowEndForced >= 0 ? backend.lowEndForced === 1 : (backend.lowEnd || softwareGfx)

    Binding { target: Theme; property: "lowEnd"; value: win.lowEndUi }
    Binding { target: Motion; property: "reduced"; value: win.lowEndUi }

    property int step: 0
    property string sysLocale: "en_US.UTF-8"
    property string timezone: "UTC"
    property string keymap: "us"
    property string disk: backend.disks.length === 1 && backend.disks[0].big ? backend.disks[0].path : ""
    property bool understood: false
    property string mode: "erase"
    property var probe: null
    property bool probing: false
    property int optIndex: 0
    property real fiordSize: 0
    property string rootPart: ""
    property string espPart: ""
    readonly property var usableParts: probe && probe.parts ? probe.parts.filter(p => p.usable) : []
    readonly property var espParts: probe && probe.parts ? probe.parts.filter(p => p.esp && p.fs === "vfat") : []
    readonly property bool manualOk: rootPart !== "" && rootPart !== espPart
        && (backend.uefi ? espPart !== "" : (!probe || !probe.gpt || probe.biosBoot))
    readonly property var opt: probe && mode === "alongside" && optIndex < probe.options.length ? probe.options[optIndex] : null
    property string fullname: ""
    property string username: ""
    property bool usernameTouched: false
    property string hostname: "fiordland"
    property string password: ""
    property string password2: ""
    property bool autologin: false
    property string kernel: "cachyos"
    property string desktop: backend.defaultDesktop
    property string dots: ""
    property bool wmTab: false
    property bool lowend: backend.ramGb > 0 && backend.ramGb <= 3
    property bool desktopTouched: false
    property string greeter: ""
    property bool failed: false
    property string errorText: ""
    property string errorDetail: ""
    property bool logOpen: false

    readonly property var steps: [
        { label: "Region", icon: "language" },
        { label: "Disk", icon: "hard_drive" },
        { label: "Account", icon: "person" },
        { label: "Desktop", icon: "desktop_windows" },
        { label: "Summary", icon: "checklist" },
        { label: "Install", icon: "download" }
    ]

    readonly property string fullnameError: backend.fullnameError(fullname)
    readonly property string usernameError: username === "" ? "" : backend.usernameError(username)
    readonly property string hostnameError: hostname === "" ? "" : backend.hostnameError(hostname)
    readonly property string passwordRuleError: password === "" ? "" : backend.passwordError(password)
    readonly property string passwordError: password2 !== "" && password !== password2 ? "Passwords do not match" : ""
    readonly property bool youValid: username !== "" && usernameError === "" && hostname !== "" && hostnameError === ""
        && fullnameError === "" && password !== "" && passwordRuleError === "" && password === password2
    readonly property var diskInfo: {
        for (const d of backend.disks) if (d.path === disk) return d
        return null
    }
    readonly property bool canNext: step === 1 ? timezone !== "" && keymap !== ""
        : step === 2 ? disk !== "" && !probing && understood && (mode !== "manual" || manualOk)
        : step === 3 ? youValid
        : step === 4 ? desktopSel !== null
        : true
    readonly property var desktopSel: desktopInfo(desktop)
    readonly property var shellSel: shellInfo(desktopSel, dots)
    readonly property bool greeterOffered: backend.crestGreeter && desktop === "hyprland" && dots === "crest"
    readonly property bool destructive: mode === "erase" || mode === "manual"
    readonly property string confirmText: mode === "erase"
        ? "Erase everything on " + (diskInfo ? diskInfo.model + " (" + diskInfo.sizeText + ")" : "this disk")
        : mode === "manual"
        ? "Erase everything on " + (rootPart ? rootPart.replace("/dev/", "") : "the chosen partition")
        : opt && opt.kind === "shrink"
            ? "I have a backup of my important files"
            : "Use the free space on " + (diskInfo ? diskInfo.model : "this disk")
    readonly property string diskSummary: !diskInfo ? ""
        : mode === "erase" ? "Erase " + diskInfo.model + " (" + diskInfo.sizeText + ")"
        : mode === "manual" ? "Format " + rootPart.replace("/dev/", "") + " on " + diskInfo.model
        : opt ? gb(fiordSize) + " next to " + (opt.kind === "shrink" ? (probe.system || opt.label) : "your files") + " on " + diskInfo.model
        : diskInfo.model

    function desktopInfo(id) {
        for (const d of backend.desktops) if (d.id === id) return d
        return null
    }
    function shellInfo(d, id) {
        if (!d) return null
        for (let i = 0; i < d.shells.length; i++) if (d.shells[i].id === id) return d.shells[i]
        return null
    }
    function setDesktop(d) {
        if (!d) return
        desktop = d.id
        dots = d.shells.length ? d.shells[0].id : ""
        wmTab = d.kind === "wm"
    }
    function pickDesktop(d) {
        desktopTouched = true
        desktop = d.id
        dots = d.shells.length ? d.shells[0].id : ""
    }
    function setLowEnd(v) {
        lowend = v
        if (!desktopTouched) setDesktop(desktopInfo(v ? backend.lightDesktop : backend.defaultDesktop))
    }
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
    function gb(b) { return (b / 1e9).toFixed(b >= 100e9 ? 0 : 1) + " GB" }
    function partText(p) {
        return p.node.replace("/dev/", "") + "  " + gb(p.size) + (p.fs ? "  " + p.fs : "") + (p.label ? "  " + p.label : "")
    }
    function pickDisk(path) {
        const d = backend.disks.find(x => x.path === path)
        if (!d || !d.big || disk === path) return
        disk = path
        understood = false
    }
    function pickManual() {
        if (mode !== "manual") understood = false
        mode = "manual"
        if (!usableParts.some(p => p.node === rootPart)) rootPart = usableParts.length ? usableParts[usableParts.length - 1].node : ""
        if (!espParts.some(p => p.node === espPart)) espPart = espParts.length ? espParts[0].node : ""
    }
    function pickRoot(node) {
        if (rootPart !== node) understood = false
        rootPart = node
    }
    function pickOption(i) {
        if (i < 0) {
            if (mode !== "erase") understood = false
            mode = "erase"
            return
        }
        const o = probe.options[i]
        if (mode !== "alongside" || optIndex !== i) understood = false
        mode = "alongside"
        optIndex = i
        fiordSize = o.kind === "shrink" ? Math.max(o.min, Math.min(o.max, Math.round(o.partSize / 2e9) * 1e9)) : o.max
    }
    function go(n) {
        if (n < 0 || n > 5 || step === 6) return
        step = n
    }
    function next() {
        if (step < 1 || step > 5 || !canNext) return
        if (step === 5) { confirm.open(); return }
        step++
    }
    function openLanguage() { language.open() }
    function closePopups() { language.close(); confirm.close() }
    function startInstall() {
        failed = false
        errorText = ""
        errorDetail = ""
        logOpen = false
        logs.clear()
        step = 6
        backend.install({
            disk: disk, disk_size: diskInfo ? diskInfo.size : 0, locale: sysLocale, timezone: timezone, keymap: keymap,
            fullname: fullname, username: username, hostname: hostname, password: password, autologin: autologin,
            kernel: kernel, desktop: desktop, shell: dots, mode: mode, shrink: opt ? opt.part : "",
            size: opt ? Math.round(fiordSize) : 0, root: mode === "manual" ? rootPart : "",
            esp: mode === "manual" && backend.uefi ? espPart : "", greeter: greeterOffered ? greeter : "", lowend: lowend
        })
    }

    onDiskChanged: {
        probe = null
        mode = "erase"
        rootPart = ""
        espPart = ""
        understood = false
        if (disk === "") { probing = false; return }
        probing = true
        backend.probe(disk)
    }
    onFullnameChanged: if (!usernameTouched) username = fullname.trim().split(/\s+/)[0].toLowerCase().replace(/[^a-z0-9_-]/g, "")
    onKeymapChanged: backend.setKeymap(keymap)
    onGreeterOfferedChanged: if (!greeterOffered) greeter = ""
    onKernelChanged: if (kernel === "fiord" && !backend.fiordKernel) kernel = "cachyos"

    Component.onCompleted: {
        if (lowend) setDesktop(desktopInfo(backend.lightDesktop))
        else setDesktop(desktopInfo(desktop))
        if (disk !== "") { probing = true; backend.probe(disk) }
        backend.guessTimezone()
        backend.detectOptions()
    }

    Connections {
        target: win.backend
        function onTimezoneGuessed(tz) { if (win.timezone === "UTC" && win.step <= 5) win.timezone = tz }
        function onProbed(d, res) {
            if (d !== win.disk) return
            win.probe = res
            win.probing = false
            if (win.mode === "manual") win.pickManual()
            else if (res.options && res.options.length) win.pickOption(0)
        }
        function onEditorClosed() {
            if (win.disk === "") return
            win.probing = true
            win.backend.probe(win.disk)
        }
        function onLogAdded(line) {
            logs.append({ line: line })
            if (logs.count > 1500) logs.remove(0, 300)
        }
        function onInstallFinished(ok, err, detail) {
            win.failed = !ok
            win.errorText = err
            win.errorDetail = detail
            win.step = 7
        }
    }
    ListModel { id: logs }

    Backdrop {
        anchors.fill: parent
        source: win.backend.wallpaper
        blur: win.step > 0 ? 1 : 0
    }

    Welcome {
        anchors.fill: parent
        app: win
    }

    Item {
        id: shell
        anchors.fill: parent
        anchors.margins: win.width >= 1100 ? 20 : 12
        opacity: win.step > 0 ? 1 : 0
        visible: opacity > 0.01
        enabled: win.step > 0
        scale: win.step > 0 || !Motion.animate ? 1 : 0.97
        Behavior on opacity {
            enabled: Motion.animate
            NumberAnimation { duration: Motion.durLong; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedDecel }
        }
        Behavior on scale {
            enabled: Motion.animate
            SpringAnimation { spring: Motion.slowSpring; damping: Motion.slowDamping; epsilon: 0.001 }
        }

        readonly property int railWidth: win.width >= 1100 ? 232 : 200

        Elevation {
            anchors.fill: rail
            radius: Theme.xl
            level: 1
        }
        Rectangle {
            id: rail
            width: shell.railWidth
            height: parent.height
            radius: Theme.xl
            color: Theme.glass
            Rectangle {
                x: Theme.xl
                width: parent.width - Theme.xl * 2
                height: 1
                color: Theme.iceStroke
            }

            Row {
                x: 24
                y: 26
                spacing: 10
                ExpressiveShape {
                    width: 28
                    height: 28
                    lobes: 6
                    depth: 0.1
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "fiordland"
                    role: Theme.titleL
                    emphasized: true
                    font.letterSpacing: -0.4
                }
            }

            Item {
                id: navList
                x: 12
                y: 92
                width: parent.width - 24
                height: win.steps.length * 56
                readonly property int current: Math.min(win.step, 6) - 1

                Rectangle {
                    id: indicator
                    width: parent.width
                    height: 56
                    radius: 28
                    color: Theme.secondaryContainer
                    visible: navList.current >= 0
                    y: Math.max(0, navList.current) * 56
                    Behavior on y {
                        enabled: Motion.animate
                        SpringAnimation { spring: Motion.defaultSpring; damping: Motion.defaultDamping; epsilon: 0.5 }
                    }
                }

                Repeater {
                    model: win.steps
                    Item {
                        id: nav
                        required property var modelData
                        required property int index
                        readonly property int num: index + 1
                        readonly property bool current: navList.current === index
                        readonly property bool done: win.step > num && !current
                        readonly property bool reachable: num <= 5 && win.step >= 1 && win.step <= 5 && num < win.step
                        y: index * 56
                        width: navList.width
                        height: 56

                        Rectangle {
                            anchors.fill: parent
                            radius: 28
                            color: Theme.onSurface
                            opacity: navMouse.containsMouse && nav.reachable ? Motion.stateHover : 0
                        }
                        Item {
                            x: 16
                            width: 28
                            height: parent.height
                            Rectangle {
                                anchors.centerIn: parent
                                width: 26
                                height: 26
                                radius: 13
                                visible: !nav.current
                                color: nav.done ? Theme.primary : "transparent"
                                border.width: nav.done ? 0 : 1.5
                                border.color: Theme.outline
                                Icon {
                                    anchors.centerIn: parent
                                    visible: nav.done
                                    name: "check"
                                    size: 18
                                    weight: 600
                                    color: Theme.onPrimary
                                }
                                Txt {
                                    anchors.centerIn: parent
                                    visible: !nav.done
                                    text: nav.num
                                    role: Theme.labelM
                                    color: Theme.onSurfaceVariant
                                }
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: nav.current
                                name: nav.modelData.icon
                                fill: 1
                                color: Theme.onSecondaryContainer
                            }
                        }
                        Txt {
                            x: 58
                            anchors.verticalCenter: parent.verticalCenter
                            text: nav.modelData.label
                            role: Theme.labelL
                            emphasized: nav.current
                            color: nav.current ? Theme.onSecondaryContainer : (nav.done ? Theme.onSurface : Theme.onSurfaceVariant)
                        }
                        MouseArea {
                            id: navMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: nav.reachable
                            cursorShape: nav.reachable ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: win.go(nav.num)
                        }
                    }
                }
            }

            Flow {
                x: 20
                width: parent.width - 40
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                spacing: 6
                Chip { text: win.backend.uefi ? "UEFI" : "BIOS"; icon: "memory"; glass: true }
                Chip { visible: win.backend.dryRun; text: "Preview"; icon: "visibility"; tonal: true }
                Chip { visible: win.lowEndUi; text: "Light mode"; icon: "eco"; glass: true }
            }
        }

        Elevation {
            anchors.fill: pane
            radius: Theme.xl
            level: 1
        }
        Rectangle {
            id: pane
            anchors.left: rail.right
            anchors.leftMargin: win.width >= 1100 ? 16 : 12
            anchors.right: parent.right
            height: parent.height
            radius: Theme.xl
            color: Theme.glass
            clip: true
            Rectangle {
                x: Theme.xl
                width: parent.width - Theme.xl * 2
                height: 1
                color: Theme.iceStroke
            }

            Item {
                id: pages
                anchors.fill: parent
                anchors.leftMargin: win.width >= 1100 ? 40 : 28
                anchors.rightMargin: win.width >= 1100 ? 40 : 28
                anchors.topMargin: win.height >= 760 ? 36 : 26
                anchors.bottomMargin: actions.visible ? 96 : 28

                RegionPage { anchors.fill: parent; app: win }
                DiskPage { anchors.fill: parent; app: win }
                AccountPage { anchors.fill: parent; app: win }
                DesktopPage { anchors.fill: parent; app: win }
                SummaryPage { anchors.fill: parent; app: win }
                ProgressPage { anchors.fill: parent; app: win; logModel: logs }
                DonePage { anchors.fill: parent; app: win }
            }

            Item {
                id: actions
                visible: win.step >= 1 && win.step <= 5
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 88

                Rectangle {
                    anchors.top: parent.top
                    x: 24
                    width: parent.width - 48
                    height: 1
                    color: Theme.outlineVariant
                    opacity: 0.5
                }
                PillButton {
                    anchors.left: parent.left
                    anchors.leftMargin: win.width >= 1100 ? 32 : 20
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "text"
                    icon: "arrow_back"
                    text: "Back"
                    onClicked: win.step--
                }
                Txt {
                    anchors.centerIn: parent
                    visible: win.step === 2 && !win.canNext && win.disk !== "" && !win.probing
                    text: "Tick the box above to continue"
                    role: Theme.bodyM
                    color: Theme.onSurfaceVariant
                }
                PillButton {
                    anchors.right: parent.right
                    anchors.rightMargin: win.width >= 1100 ? 32 : 20
                    anchors.verticalCenter: parent.verticalCenter
                    size: 56
                    enabled: win.canNext
                    danger: win.step === 5 && win.destructive
                    text: win.step === 5 ? "Install" : "Continue"
                    trailingIcon: win.step === 5 ? "download" : "arrow_forward"
                    onClicked: win.next()
                }
            }
        }
    }

    Dialog {
        id: language
        icon: "translate"
        title: "Language"
        body: "Used for the installed system. The installer stays in English."
        height: Math.min(win.height - 80, 620)
        SearchList {
            width: parent.width
            height: Math.max(200, language.height - 300)
            items: win.backend.locales
            primaryOf: (k) => win.localeName(k)
            secondaryOf: (k) => k
            current: win.sysLocale
            placeholder: "Search languages"
            onPicked: (k) => { win.sysLocale = k; language.close() }
        }
        actions: [
            PillButton { variant: "text"; text: "Close"; onClicked: language.close() }
        ]
    }

    Dialog {
        id: confirm
        icon: win.destructive ? "warning" : "download"
        danger: win.destructive
        title: win.destructive ? "erase and install" : "install fiordland"
        body: win.mode === "erase"
            ? "Everything on " + (win.diskInfo ? win.diskInfo.model + " (" + win.diskInfo.sizeText + ")" : "the disk") + " will be deleted. This cannot be undone."
            : win.mode === "manual"
            ? win.rootPart.replace("/dev/", "") + " will be formatted and everything on it deleted. This cannot be undone."
            : "Fiordland will be installed next to what is already on the disk. Keep the computer plugged in until it finishes."
        actions: [
            PillButton { variant: "text"; text: "Cancel"; onClicked: confirm.close() },
            PillButton {
                danger: win.destructive
                icon: win.destructive ? "delete_forever" : "download"
                text: win.destructive ? "Erase and install" : "Install"
                onClicked: { confirm.close(); win.startInstall() }
            }
        ]
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: win.step >= 1 && win.step <= 4 && !language.visible && !confirm.visible
        onActivated: win.next()
    }
}
