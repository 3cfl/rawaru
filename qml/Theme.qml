pragma Singleton
import QtQuick

QtObject {
    id: theme

    property bool dark: true
    property bool lowEnd: false

    readonly property color primary: dark ? "#9ECAFF" : "#2C6197"
    readonly property color inkPrimary: dark ? "#00325A" : "#FFFFFF"
    readonly property color primaryContainer: dark ? "#1D4A74" : "#D2E4FF"
    readonly property color inkPrimaryContainer: dark ? "#D2E4FF" : "#001C37"
    readonly property color secondary: dark ? "#BAC8DB" : "#535F70"
    readonly property color secondaryContainer: dark ? "#3A4857" : "#D6E4F7"
    readonly property color inkSecondaryContainer: dark ? "#D6E4F7" : "#101C2B"
    readonly property color tertiary: dark ? "#86D6CB" : "#006A62"
    readonly property color tertiaryContainer: dark ? "#00504A" : "#A2F2E6"
    readonly property color inkTertiaryContainer: dark ? "#A2F2E6" : "#00201D"
    readonly property color error: dark ? "#FFB4AB" : "#BA1A1A"
    readonly property color errorContainer: dark ? "#93000A" : "#FFDAD6"
    readonly property color inkErrorContainer: dark ? "#FFDAD6" : "#410002"
    readonly property color surface: dark ? "#0E1217" : "#F8F9FF"
    readonly property color surfaceDim: dark ? "#0E1217" : "#D8DAE0"
    readonly property color surfaceBright: dark ? "#34383E" : "#F8F9FF"
    readonly property color surfaceContainerLowest: dark ? "#090D12" : "#FFFFFF"
    readonly property color surfaceContainerLow: dark ? "#161B21" : "#F2F3F9"
    readonly property color surfaceContainer: dark ? "#1A1F25" : "#ECEEF4"
    readonly property color surfaceContainerHigh: dark ? "#252A30" : "#E6E8EE"
    readonly property color surfaceContainerHighest: dark ? "#30353B" : "#E1E2E8"
    readonly property color inkSurface: dark ? "#E1E2E8" : "#191C20"
    readonly property color inkSurfaceVariant: dark ? "#C1C7D0" : "#41474F"
    readonly property color outline: dark ? "#8B919A" : "#717880"
    readonly property color outlineVariant: dark ? "#41474F" : "#C1C7D0"
    readonly property color scrim: "#000000"

    readonly property color inkError: dark ? "#690005" : "#FFFFFF"

    readonly property color glass: alpha(surfaceContainer, lowEnd ? 0.94 : 0.72)
    readonly property color glassHigh: alpha(surfaceContainerHigh, lowEnd ? 0.96 : 0.78)
    readonly property color cardFill: alpha(surfaceContainerHighest, lowEnd ? 0.5 : 0.42)
    readonly property color cardSelected: alpha(primaryContainer, 0.78)
    readonly property color iceStroke: alpha(inkSurface, 0.08)

    readonly property int none: 0
    readonly property int xs: 4
    readonly property int sm: 8
    readonly property int md: 12
    readonly property int lg: 16
    readonly property int lgInc: 20
    readonly property int xl: 28
    readonly property int xlInc: 32
    readonly property int xxl: 48

    readonly property string font: "Inter"
    readonly property string display: Qt.fontFamilies().indexOf("Inter Display") >= 0 ? "Inter Display" : "Inter"
    readonly property string mono: "JetBrains Mono"
    readonly property string symbols: "Material Symbols Rounded"
    readonly property bool hasSymbols: Qt.fontFamilies().indexOf(symbols) >= 0

    readonly property var displayL: ({ size: 57, line: 64, weight: 400 })
    readonly property var displayM: ({ size: 45, line: 52, weight: 400 })
    readonly property var displayS: ({ size: 36, line: 44, weight: 400 })
    readonly property var headlineL: ({ size: 32, line: 40, weight: 500 })
    readonly property var headlineM: ({ size: 28, line: 36, weight: 500 })
    readonly property var headlineS: ({ size: 24, line: 32, weight: 500 })
    readonly property var titleL: ({ size: 22, line: 28, weight: 600 })
    readonly property var titleM: ({ size: 16, line: 24, weight: 600 })
    readonly property var titleS: ({ size: 14, line: 20, weight: 600 })
    readonly property var bodyL: ({ size: 16, line: 24, weight: 400 })
    readonly property var bodyM: ({ size: 14, line: 20, weight: 400 })
    readonly property var bodyS: ({ size: 12, line: 16, weight: 400 })
    readonly property var labelL: ({ size: 14, line: 20, weight: 600 })
    readonly property var labelM: ({ size: 12, line: 16, weight: 600 })
    readonly property var labelS: ({ size: 11, line: 16, weight: 600 })

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
    }

    function layer(base, content, state) {
        return mix(base, content, state)
    }
}
