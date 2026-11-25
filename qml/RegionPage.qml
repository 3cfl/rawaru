import QtQuick
import QtQuick.Layouts

StepPage {
    id: page

    index: 1
    overline: "Step 1 of 5"
    title: "where are you"
    subtitle: "Language, time zone and keyboard. All of these can be changed later."

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            radius: Theme.xl
            interactive: true
            onClicked: page.app.openLanguage()
            ListItem {
                anchors.fill: parent
                interactive: false
                icon: "translate"
                headline: page.app.localeName(page.app.sysLocale)
                supporting: ""
                Txt {
                    text: "Language"
                    role: Theme.labelL
                    color: Theme.primary
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                spacing: 10
                Row {
                    spacing: 8
                    Icon { name: "schedule"; size: 20; color: Theme.primary }
                    Txt { text: "Time zone"; role: Theme.titleS; anchors.verticalCenter: parent.verticalCenter }
                }
                SearchList {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    items: page.app.backend.timezones
                    primaryOf: (z) => page.app.zoneCity(z)
                    secondaryOf: (z) => page.app.zoneRegion(z)
                    current: page.app.timezone
                    placeholder: "Search cities"
                    onPicked: (k) => page.app.timezone = k
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                spacing: 10
                Row {
                    spacing: 8
                    Icon { name: "keyboard"; size: 20; color: Theme.primary }
                    Txt { text: "Keyboard"; role: Theme.titleS; anchors.verticalCenter: parent.verticalCenter }
                }
                SearchList {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    items: page.app.backend.keymaps
                    primaryOf: (k) => k.name
                    secondaryOf: (k) => k.code
                    keyOf: (k) => k.code
                    current: page.app.keymap
                    placeholder: "Search layouts"
                    onPicked: (k) => page.app.keymap = k
                }
                TextField {
                    Layout.fillWidth: true
                    icon: "keyboard"
                    label: ""
                    placeholder: "Type here to test the layout"
                }
            }
        }
    }
}
