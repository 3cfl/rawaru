import QtQuick
import QtQuick.Layouts

StepPage {
    id: page

    index: 3
    overline: "Step 3 of 5"
    title: "make your account"
    subtitle: "The user you log in as every day. It can run admin tasks with your password."

    readonly property bool wide: width >= 720
    readonly property string initial: {
        const s = (app.fullname.trim() || app.username || "?")
        return s.charAt(0).toUpperCase()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 24

        Card {
            visible: page.wide
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            Layout.maximumHeight: 300
            Layout.alignment: Qt.AlignTop
            Column {
                anchors.centerIn: parent
                width: parent.width - 32
                spacing: 14
                ExpressiveShape {
                    id: avatar
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 112
                    height: 112
                    lobes: 9
                    depth: 0.06
                    color: Theme.primaryContainer
                    spin: 0
                    Txt {
                        anchors.centerIn: parent
                        text: page.initial
                        role: Theme.displayS
                        emphasized: true
                        color: Theme.onPrimaryContainer
                    }
                }
                Txt {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: page.app.fullname.trim() || "Your name"
                    role: Theme.titleM
                    elide: Text.ElideRight
                    color: page.app.fullname.trim() ? Theme.onSurface : Theme.onSurfaceVariant
                }
                Txt {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: (page.app.username || "you") + "@" + (page.app.hostname || "fiordland")
                    role: Theme.bodyS
                    font.family: Theme.mono
                    elide: Text.ElideMiddle
                    color: Theme.onSurfaceVariant
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumWidth: 640
            spacing: 14

            TextField {
                Layout.fillWidth: true
                icon: "badge"
                label: "Your name"
                text: page.app.fullname
                error: page.app.fullnameError
                onEdited: page.app.fullname = text
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                TextField {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    icon: "person"
                    label: "Username"
                    text: page.app.username
                    error: page.app.usernameError
                    onEdited: { page.app.usernameTouched = true; page.app.username = text }
                }
                TextField {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    icon: "computer"
                    label: "Computer name"
                    text: page.app.hostname
                    error: page.app.hostnameError
                    onEdited: page.app.hostname = text
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                TextField {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    icon: "lock"
                    label: "Password"
                    password: true
                    text: page.app.password
                    error: page.app.passwordRuleError
                    supporting: page.app.password !== "" && page.app.password.length < 6 ? "Short passwords are easy to guess" : ""
                    onEdited: page.app.password = text
                }
                TextField {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    icon: "lock_reset"
                    label: "Confirm password"
                    password: true
                    text: page.app.password2
                    error: page.app.passwordError
                    onEdited: page.app.password2 = text
                }
            }
            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                Layout.topMargin: 4
                interactive: true
                onClicked: page.app.autologin = !page.app.autologin
                ListItem {
                    anchors.fill: parent
                    interactive: false
                    icon: "login"
                    headline: "Log in automatically"
                    supporting: "Skip the login screen when the computer starts."
                    supportingLines: 1
                    Switch {
                        checked: page.app.autologin
                        onToggled: (v) => page.app.autologin = v
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
