pragma Singleton
import QtQuick
import QtCore

// The look and the saved preferences, shared by every file. Colors follow
// Notepads' Fluent look: neutral greys under a translucent tint that lets
// Hyprland's blur through, with the Omarchy accent standing in for the
// Windows accent color.
QtObject {
    id: style

    readonly property Settings prefs: Settings {
        category: "preferences"

        property bool wrapWord: false
        property bool highlightLine: true
        property string fontFamily: "monospace"
        property int fontSize: 13
        property string defaultLineEnding: "lf"
        property string defaultEncoding: "utf-8"
        // 0 inserts a tab character; otherwise this many spaces.
        property int tabSize: 0
        property string searchEngine: "google"
        // "system" follows Omarchy's light or dark theme.
        property string themeMode: "system"
        property bool omarchyColors: true
        property real tintOpacity: 0.8
        property bool omarchyAccent: true
        property string customAccent: "#0078d4"
        property bool showStatusBar: true
        property bool sessionSnapshot: true
        // The space between words, as a share of the font's own space.
        property int wordSpacingPercent: 100
        property bool lineNumbers: true
        property bool proportionalRtl: true
        // The desktop-wide key that opens Notepads, and the one last written
        // to Hyprland; they differ until it has been applied.
        property string globalShortcut: "SUPER + ALT + N"
        property string appliedShortcut: ""
        property var recentFiles: []
    }

    readonly property bool dark: prefs.themeMode === "dark"
                                 || (prefs.themeMode === "system" && theme.mode !== "light")

    readonly property color base: prefs.omarchyColors ? theme.background : (dark ? "#202020" : "#f3f3f3")
    readonly property color text: prefs.omarchyColors ? theme.foreground : (dark ? "#ececec" : "#1b1b1b")
    readonly property color accent: prefs.omarchyAccent ? theme.accent : prefs.customAccent
    readonly property color accentText: luminance(accent) > 0.5 ? "#000000" : "#ffffff"

    readonly property real opacity: Math.max(0.2, Math.min(1, prefs.tintOpacity))
    readonly property color tint: withAlpha(base, opacity)
    readonly property color activeTab: withAlpha(mix(base, text, dark ? 0.07 : 0.0), dark ? opacity : 1)
    readonly property color tabHover: withAlpha(mix(base, text, 0.035), opacity)
    readonly property color strip: withAlpha(dark ? base : mix(base, "#000000", 0.05), opacity)
    readonly property color status: withAlpha(themed(theme.darkBackground, mix(base, "#000000", dark ? 0.18 : 0.04)), opacity)
    readonly property color panel: withAlpha(themed(theme.lighterBackground, mix(base, text, dark ? 0.06 : 0.0)), 0.985)
    readonly property color menu: withAlpha(themed(theme.lighterBackground, mix(base, text, dark ? 0.08 : 0.02)), 0.99)
    // A step above the panel it sits on, so a field still reads as one.
    readonly property color field: themed(theme.lighterBackground, "") ? mix(theme.lighterBackground, text, 0.04)
                                                                      : mix(base, text, dark ? 0.1 : 0.0)

    readonly property color muted: withAlpha(text, 0.64)
    readonly property color faint: themed(theme.muted, withAlpha(text, 0.36))
    readonly property color border: themed(theme.muted, withAlpha(text, dark ? 0.1 : 0.14))
    readonly property color hover: withAlpha(text, 0.08)
    readonly property color pressed: withAlpha(text, 0.13)
    readonly property color lineHighlight: withAlpha(text, dark ? 0.05 : 0.06)
    readonly property color danger: themed(theme.red, dark ? "#ff6b78" : "#c42b1c")
    // Selected text: the theme's selection under plain text, else the accent.
    readonly property color selection: themed(theme.selection, accent)
    readonly property color selectionText: themed(theme.selection, "") ? text : accentText

    readonly property var rtlFamilies: backend.rightToLeftFamilies()
    readonly property var editorFamilies: prefs.proportionalRtl ? rtlFamilies.concat([prefs.fontFamily]) : [prefs.fontFamily]

    readonly property int radius: theme.radius
    readonly property int smallRadius: Math.min(4, theme.radius)

    // The theme's own color for a role, when theme colors are on and the
    // theme has one; otherwise the fallback.
    function themed(value, fallback) {
        return prefs.omarchyColors && value ? value : fallback
    }

    // Takes a color or a "#rrggbb" string, as the theme's roles are.
    function withAlpha(c, a) {
        const x = Qt.color(c)
        return Qt.rgba(x.r, x.g, x.b, a)
    }

    function mix(a, b, t) {
        const x = Qt.color(a), y = Qt.color(b)
        return Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, 1)
    }

    function luminance(c) {
        const x = Qt.color(c)
        return 0.2126 * x.r + 0.7152 * x.g + 0.0722 * x.b
    }

    readonly property var encodings: [
        { key: "utf-8", name: "UTF-8" },
        { key: "utf-8-bom", name: "UTF-8-BOM" },
        { key: "utf-16le", name: "UTF-16 LE BOM" },
        { key: "utf-16be", name: "UTF-16 BE BOM" },
        { key: "latin1", name: "ISO-8859-1" }
    ]

    function encodingName(key) {
        for (const e of encodings)
            if (e.key === key)
                return e.name
        return key
    }

    function lineEndingName(key) {
        return key === "crlf" ? qsTr("Windows (CRLF)") : key === "cr" ? qsTr("Macintosh (CR)") : qsTr("Unix (LF)")
    }
}
