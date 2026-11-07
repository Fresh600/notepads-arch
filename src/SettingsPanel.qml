import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Templates as T
import "."

// The settings pane that slides over the right side of the editor, with an
// icon rail for its pages, as in Notepads.
Popup {
    id: panel

    property int page: 0
    // Which shortcut is waiting for a key: "global", "correction", or "".
    property string recordingTarget: ""
    readonly property bool recording: recordingTarget !== ""
    property string shortcutError: ""
    property string correctionError: ""

    onClosed: recordingTarget = ""

    // Hyprland's names for the keys Qt reports.
    function keyName(event) {
        const k = event.key
        if ((k >= Qt.Key_A && k <= Qt.Key_Z) || (k >= Qt.Key_0 && k <= Qt.Key_9))
            return String.fromCharCode(k)
        if (k >= Qt.Key_F1 && k <= Qt.Key_F24)
            return "F" + (k - Qt.Key_F1 + 1)
        const names = {}
        names[Qt.Key_Space] = "SPACE"; names[Qt.Key_Return] = "RETURN"; names[Qt.Key_Enter] = "RETURN"
        names[Qt.Key_Tab] = "TAB"; names[Qt.Key_Backspace] = "BACKSPACE"; names[Qt.Key_Delete] = "DELETE"
        names[Qt.Key_Insert] = "INSERT"; names[Qt.Key_Home] = "HOME"; names[Qt.Key_End] = "END"
        names[Qt.Key_PageUp] = "PAGE_UP"; names[Qt.Key_PageDown] = "PAGE_DOWN"
        names[Qt.Key_Left] = "LEFT"; names[Qt.Key_Right] = "RIGHT"; names[Qt.Key_Up] = "UP"; names[Qt.Key_Down] = "DOWN"
        names[Qt.Key_Minus] = "MINUS"; names[Qt.Key_Equal] = "EQUAL"; names[Qt.Key_Comma] = "COMMA"
        names[Qt.Key_Period] = "PERIOD"; names[Qt.Key_Slash] = "SLASH"; names[Qt.Key_Semicolon] = "SEMICOLON"
        names[Qt.Key_Apostrophe] = "APOSTROPHE"; names[Qt.Key_BracketLeft] = "BRACKETLEFT"
        names[Qt.Key_BracketRight] = "BRACKETRIGHT"; names[Qt.Key_Backslash] = "BACKSLASH"; names[Qt.Key_QuoteLeft] = "GRAVE"
        return names[k] || ""
    }

    function recordShortcut(event) {
        event.accepted = true
        const modifierKeys = [Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Control, Qt.Key_Shift, Qt.Key_Alt, Qt.Key_AltGr]
        if (modifierKeys.indexOf(event.key) >= 0)
            return
        if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
            recordingTarget = ""
            return
        }
        const key = keyName(event)
        const parts = []
        if (event.modifiers & Qt.MetaModifier) parts.push("SUPER")
        if (event.modifiers & Qt.ControlModifier) parts.push("CTRL")
        if (event.modifiers & Qt.ShiftModifier) parts.push("SHIFT")
        if (event.modifiers & Qt.AltModifier) parts.push("ALT")
        if (!key || parts.length === 0) {
            shortcutError = qsTr("Hold at least one of Super, Ctrl, Alt, or Shift, then press a key.")
            return
        }
        const target = recordingTarget
        recordingTarget = ""
        const combo = parts.concat([key]).join(" + ")
        if (target === "correction")
            setCorrectionShortcut(combo)
        else
            setShortcut(combo)
    }

    // Qt's spelling of a combo recorded in Hyprland's: "CTRL + SHIFT + D"
    // becomes "Ctrl+Shift+D".
    function qtSequence(combo) {
        const keys = { SPACE: "Space", RETURN: "Return", TAB: "Tab", BACKSPACE: "Backspace", DELETE: "Del",
                       INSERT: "Ins", HOME: "Home", END: "End", PAGE_UP: "PgUp", PAGE_DOWN: "PgDown",
                       LEFT: "Left", RIGHT: "Right", UP: "Up", DOWN: "Down", MINUS: "-", EQUAL: "=",
                       COMMA: ",", PERIOD: ".", SLASH: "/", SEMICOLON: ";", APOSTROPHE: "'",
                       BRACKETLEFT: "[", BRACKETRIGHT: "]", BACKSLASH: "\\", GRAVE: "`" }
        const mods = { SUPER: "Meta", CTRL: "Ctrl", SHIFT: "Shift", ALT: "Alt" }
        return combo.split("+").map(part => part.trim()).filter(part => part !== "")
                    .map(part => mods[part] || keys[part] || part).join("+")
    }

    function setCorrectionShortcut(combo) {
        correctionError = ""
        if (combo && combo === Style.prefs.globalShortcut) {
            correctionError = qsTr("%1 is already the shortcut that opens Notepads.").arg(globalShortcut.displayName(combo))
            return
        }
        Style.prefs.correctionShortcut = combo
    }

    function setShortcut(combo) {
        shortcutError = ""
        const taken = combo ? globalShortcut.conflict(combo) : ""
        if (taken) {
            shortcutError = qsTr("%1 is already used by \"%2\".").arg(globalShortcut.displayName(combo)).arg(taken)
            return
        }
        const error = globalShortcut.apply(combo)
        if (error) {
            shortcutError = error
            return
        }
        Style.prefs.globalShortcut = combo
        Style.prefs.appliedShortcut = combo
    }
    readonly property var pages: [
        { icon: "text-editor", title: qsTr("Text & Editor") },
        { icon: "palette", title: qsTr("Personalization") },
        { icon: "sliders", title: qsTr("Advanced") },
        { icon: "info", title: qsTr("About") }
    ]

    x: parent ? parent.width - width : 0
    y: 0
    width: Math.min(400, parent ? parent.width : 400)
    height: parent ? parent.height : 600
    padding: 0
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Material.roundedScale: Style.radius

    background: Rectangle {
        color: Style.panel
        Rectangle {
            width: 1
            height: parent.height
            color: Style.border
        }
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
    }

    component ShortcutField: RowLayout {
        id: field

        property string target
        property string value
        signal cleared

        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8

        Rectangle {
            id: shortcutBox
            Layout.fillWidth: true
            implicitHeight: 34
            radius: Style.smallRadius
            color: Style.field
            border.color: panel.recordingTarget === field.target ? Style.accent : Style.border
            focus: panel.recordingTarget === field.target

            Text {
                anchors.fill: parent
                anchors.leftMargin: 10
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                font.pixelSize: 13
                color: panel.recordingTarget === field.target || !field.value ? Style.muted : Style.text
                text: panel.recordingTarget === field.target ? qsTr("Press the new shortcut… (Esc cancels)")
                      : field.value ? globalShortcut.displayName(field.value)
                      : qsTr("None")
            }

            Keys.onPressed: event => panel.recordShortcut(event)
        }
        FlatButton {
            text: panel.recordingTarget === field.target ? qsTr("Cancel") : qsTr("Change")
            onClicked: {
                panel.shortcutError = ""
                panel.correctionError = ""
                if (panel.recordingTarget === field.target) {
                    panel.recordingTarget = ""
                } else {
                    panel.recordingTarget = field.target
                    shortcutBox.forceActiveFocus()
                }
            }
        }
        IconButton {
            implicitWidth: 32
            icon: "close"
            tip: qsTr("Remove the shortcut")
            visible: field.value !== "" && !panel.recording
            onClicked: field.cleared()
        }
    }

    // A group of related settings under one small heading.
    component Section: Text {
        color: Style.accent
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.6
        Layout.topMargin: 20
        Layout.bottomMargin: 2
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }

    component Note: Text {
        color: Style.muted
        font.pixelSize: 12
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }

    // One setting: its name on the left, its control on the right, and an
    // optional explanation underneath. Children land in the right-hand slot.
    component Setting: ColumnLayout {
        id: setting

        property string label
        property string note
        property bool dimmed: false
        default property alias control: row.data

        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 1
        opacity: dimmed ? 0.45 : 1

        RowLayout {
            id: row
            Layout.fillWidth: true
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: setting.label
                color: Style.text
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }
        }
        Note {
            visible: setting.note !== ""
            text: setting.note
        }
    }

    // A small switch, sized for a 400px pane.
    component Switch: T.Switch {
        id: sw
        implicitWidth: 38
        implicitHeight: 22
        padding: 0
        hoverEnabled: true
        contentItem: Item {}
        indicator: Rectangle {
            width: 36
            height: 20
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            color: sw.checked ? Style.accent : "transparent"
            border.width: sw.checked ? 0 : 1.5
            border.color: sw.hovered ? Style.text : Style.muted
            opacity: sw.enabled ? 1 : 0.5
            Rectangle {
                width: sw.checked ? 14 : 10
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: sw.checked ? parent.width - width - 4 : 5
                color: sw.checked ? Style.accentText : Style.muted
                Behavior on x { NumberAnimation { duration: 100 } }
            }
        }
    }

    // A compact drop-down over { key, name } entries.
    component Select: ComboBox {
        property string current
        signal picked(string key)

        Layout.preferredWidth: 170
        implicitHeight: 32
        font.pixelSize: 13
        Material.accent: Style.accent
        Material.foreground: Style.text
        textRole: "name"
        valueRole: "key"
        currentIndex: Math.max(0, indexOfValue(current))
        onActivated: picked(currentValue)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 1
        spacing: 0

        Column {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 44
            Layout.topMargin: 6
            spacing: 2

            Repeater {
                model: panel.pages
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: 44
                    height: 40

                    Rectangle {
                        width: 3
                        height: 16
                        radius: 1.5
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: Style.accent
                        visible: panel.page === index
                    }
                    IconButton {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        icon: modelData.icon
                        tip: modelData.title
                        onClicked: panel.page = index
                    }
                }
            }
        }

        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: scroll.availableWidth - 24
                x: 8
                spacing: 6

                Text {
                    Layout.topMargin: 14
                    text: panel.pages[panel.page].title
                    color: Style.text
                    font.pixelSize: 28
                    font.weight: Font.Light
                }

                // Text & Editor
                ColumnLayout {
                    visible: panel.page === 0
                    Layout.fillWidth: true
                    spacing: 4

                    Section { text: qsTr("Editing"); Layout.topMargin: 12 }
                    Setting {
                        label: qsTr("Wrap word")
                        note: qsTr("Documents with Hebrew always wrap, so right-to-left lines stay in view.")
                        Switch {
                            checked: Style.prefs.wrapWord
                            onToggled: Style.prefs.wrapWord = checked
                        }
                    }
                    Setting {
                        label: qsTr("Show line numbers")
                        note: qsTr("Hebrew lines are numbered on the right.")
                        Switch {
                            checked: Style.prefs.lineNumbers
                            onToggled: Style.prefs.lineNumbers = checked
                        }
                    }
                    Setting {
                        label: qsTr("Highlight the current line")
                        Switch {
                            checked: Style.prefs.highlightLine
                            onToggled: Style.prefs.highlightLine = checked
                        }
                    }
                    Setting {
                        label: qsTr("Tab key inserts")
                        Select {
                            Layout.preferredWidth: 130
                            model: [
                                { key: "0", name: qsTr("A tab") },
                                { key: "2", name: qsTr("2 spaces") },
                                { key: "4", name: qsTr("4 spaces") },
                                { key: "8", name: qsTr("8 spaces") }
                            ]
                            current: String(Style.prefs.tabSize)
                            onPicked: key => Style.prefs.tabSize = parseInt(key)
                        }
                    }

                    Section { text: qsTr("Font") }
                    Setting {
                        label: qsTr("Font")
                        Select {
                            Layout.preferredWidth: 200
                            model: [{ key: "monospace", name: qsTr("Default monospace (Omarchy font)") }]
                                   .concat(Qt.fontFamilies().map(f => ({ key: f, name: f })))
                            current: Style.prefs.fontFamily
                            onPicked: key => Style.prefs.fontFamily = key
                        }
                    }
                    Setting {
                        label: qsTr("Size")
                        Select {
                            Layout.preferredWidth: 90
                            model: [8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 24, 28, 32, 36, 48, 72]
                                   .map(n => ({ key: String(n), name: String(n) }))
                            current: String(Style.prefs.fontSize)
                            onPicked: key => Style.prefs.fontSize = parseInt(key)
                        }
                    }
                    Setting {
                        visible: Style.rtlFamilies.length > 0
                        label: qsTr("Proportional font for Hebrew")
                        Switch {
                            checked: Style.prefs.proportionalRtl
                            onToggled: Style.prefs.proportionalRtl = checked
                        }
                    }
                    Setting {
                        label: qsTr("Word spacing")
                        note: qsTr("100% is the font's own space. Below 100% brings words closer. Spaces used for indentation change too.")
                        Text {
                            text: Style.prefs.wordSpacingPercent + "%"
                            color: Style.muted
                            font.pixelSize: 12
                        }
                        IconButton {
                            implicitWidth: 28
                            icon: "undo"
                            tip: qsTr("Reset to the font's own spacing")
                            enabled: Style.prefs.wordSpacingPercent !== 100
                            onClicked: Style.prefs.wordSpacingPercent = 100
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        IconButton {
                            implicitWidth: 28
                            icon: "minus"
                            tip: qsTr("Narrower")
                            enabled: Style.prefs.wordSpacingPercent > spacingSlider.from
                            onClicked: Style.prefs.wordSpacingPercent = Math.max(spacingSlider.from, Style.prefs.wordSpacingPercent - 1)
                        }
                        Slider {
                            id: spacingSlider
                            Layout.fillWidth: true
                            Material.accent: Style.accent
                            from: 20
                            to: 300
                            stepSize: 1
                            value: Style.prefs.wordSpacingPercent
                            onMoved: Style.prefs.wordSpacingPercent = Math.round(value)
                        }
                        IconButton {
                            implicitWidth: 28
                            icon: "add"
                            tip: qsTr("Wider")
                            enabled: Style.prefs.wordSpacingPercent < spacingSlider.to
                            onClicked: Style.prefs.wordSpacingPercent = Math.min(spacingSlider.to, Style.prefs.wordSpacingPercent + 1)
                        }
                    }

                    Section { text: qsTr("Spelling") }
                    Setting {
                        label: qsTr("Underline spelling mistakes")
                        dimmed: !spellChecker.available
                        Switch {
                            enabled: spellChecker.available
                            checked: Style.prefs.spellUnderline
                            onToggled: Style.prefs.spellUnderline = checked
                        }
                    }
                    Setting {
                        label: qsTr("Suggest corrections in the right-click menu")
                        dimmed: !spellChecker.available
                        note: spellChecker.available
                              ? qsTr("Dictionaries: %1. Install more with pacman, for example hunspell-he for Hebrew.").arg(spellChecker.languages().join(", "))
                              : qsTr("No dictionaries are installed. Install one with pacman, for example hunspell-en_us.")
                        Switch {
                            enabled: spellChecker.available
                            checked: Style.prefs.spellSuggestions
                            onToggled: Style.prefs.spellSuggestions = checked
                        }
                    }

                    Section { text: qsTr("New documents") }
                    Setting {
                        label: qsTr("Line ending")
                        Select {
                            model: ["crlf", "cr", "lf"].map(k => ({ key: k, name: Style.lineEndingName(k) }))
                            current: Style.prefs.defaultLineEnding
                            onPicked: key => Style.prefs.defaultLineEnding = key
                        }
                    }
                    Setting {
                        label: qsTr("Encoding")
                        note: qsTr("Line ending and encoding only apply to new documents.")
                        Select {
                            model: Style.encodings.map(e => ({ key: e.key, name: e.name }))
                            current: Style.prefs.defaultEncoding
                            onPicked: key => Style.prefs.defaultEncoding = key
                        }
                    }

                    Section { text: qsTr("Search") }
                    Setting {
                        label: qsTr("Search engine")
                        Select {
                            model: [
                                { key: "google", name: "Google" },
                                { key: "bing", name: "Bing" },
                                { key: "duckduckgo", name: "DuckDuckGo" }
                            ]
                            current: Style.prefs.searchEngine
                            onPicked: key => Style.prefs.searchEngine = key
                        }
                    }
                    Item { implicitHeight: 16 }
                }

                // Personalization
                ColumnLayout {
                    visible: panel.page === 1
                    Layout.fillWidth: true
                    spacing: 4

                    Section { text: qsTr("Colors"); Layout.topMargin: 12 }
                    Setting {
                        label: qsTr("Color scheme")
                        note: Style.prefs.omarchyColors
                              ? qsTr("Menus, panels, selection and errors follow the current Omarchy theme.")
                              : qsTr("Neutral greys, without the Omarchy theme's palette.")
                        Select {
                            Layout.preferredWidth: 200
                            model: [
                                { key: "omarchy", name: qsTr("Omarchy theme") },
                                { key: "system", name: qsTr("Neutral, light or dark with Omarchy") },
                                { key: "light", name: qsTr("Neutral light") },
                                { key: "dark", name: qsTr("Neutral dark") }
                            ]
                            current: Style.prefs.omarchyColors ? "omarchy" : Style.prefs.themeMode
                            onPicked: key => {
                                if (key === "omarchy") {
                                    Style.prefs.omarchyColors = true
                                } else {
                                    Style.prefs.themeMode = key
                                    Style.prefs.omarchyColors = false
                                }
                            }
                        }
                    }
                    Setting {
                        label: qsTr("Background tint opacity")
                        note: qsTr("Lower values let more of the blurred wallpaper through.")
                        Text {
                            text: Math.round(Style.prefs.tintOpacity * 100) + "%"
                            color: Style.muted
                            font.pixelSize: 12
                        }
                    }
                    Slider {
                        Layout.fillWidth: true
                        Material.accent: Style.accent
                        from: 0.2
                        to: 1
                        stepSize: 0.01
                        value: Style.prefs.tintOpacity
                        onMoved: Style.prefs.tintOpacity = value
                    }

                    Section { text: qsTr("Accent") }
                    Setting {
                        label: qsTr("Use Omarchy accent color")
                        Switch {
                            checked: Style.prefs.omarchyAccent
                            onToggled: Style.prefs.omarchyAccent = checked
                        }
                    }
                    Flow {
                        visible: !Style.prefs.omarchyAccent
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 6
                        Repeater {
                            model: ["#0078d4", "#0099bc", "#00b294", "#10893e", "#ffb900", "#ca5010",
                                    "#e81123", "#e3008c", "#c239b3", "#8764b8", "#6b69d6", "#767676"]
                            delegate: Rectangle {
                                required property string modelData
                                width: 28
                                height: 28
                                radius: Style.smallRadius
                                color: modelData
                                border.width: Style.prefs.customAccent === modelData ? 2 : 0
                                border.color: Style.text
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Style.prefs.customAccent = parent.modelData
                                }
                            }
                        }
                    }
                    Item { implicitHeight: 16 }
                }

                // Advanced
                ColumnLayout {
                    visible: panel.page === 2
                    Layout.fillWidth: true
                    spacing: 4

                    Section { text: qsTr("Window"); Layout.topMargin: 12 }
                    Setting {
                        label: qsTr("Show status bar")
                        Switch {
                            checked: Style.prefs.showStatusBar
                            onToggled: Style.prefs.showStatusBar = checked
                        }
                    }
                    Setting {
                        label: qsTr("Restore tabs and unsaved changes")
                        note: qsTr("When on, closing Notepads keeps unsaved work for next time instead of asking.")
                        Switch {
                            checked: Style.prefs.sessionSnapshot
                            onToggled: Style.prefs.sessionSnapshot = checked
                        }
                    }

                    Section { text: qsTr("Shortcuts") }
                    Setting {
                        label: qsTr("Open a new Notepads window")
                        note: qsTr("Works from anywhere, the way the terminal does. Saved as a Hyprland binding in ~/.config/hypr/notepads.lua.")
                    }
                    ShortcutField {
                        target: "global"
                        value: Style.prefs.globalShortcut
                        onCleared: panel.setShortcut("")
                    }
                    Text {
                        visible: panel.shortcutError !== ""
                        Layout.fillWidth: true
                        text: panel.shortcutError
                        color: Style.danger
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                    Setting {
                        Layout.topMargin: 10
                        label: qsTr("Accept spelling suggestion")
                        note: qsTr("Replaces the misspelled word at the cursor with the dictionary's first suggestion.")
                    }
                    ShortcutField {
                        target: "correction"
                        value: Style.prefs.correctionShortcut
                        onCleared: panel.setCorrectionShortcut("")
                    }
                    Text {
                        visible: panel.correctionError !== ""
                        Layout.fillWidth: true
                        text: panel.correctionError
                        color: Style.danger
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                    Item { implicitHeight: 16 }
                }

                // About
                ColumnLayout {
                    visible: panel.page === 3
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.topMargin: 18
                        spacing: 14
                        Image {
                            source: "qrc:/notepads.svg"
                            sourceSize: Qt.size(56, 56)
                        }
                        ColumnLayout {
                            spacing: 2
                            Text { text: "Notepads"; color: Style.text; font.pixelSize: 20 }
                            Text { text: qsTr("Version %1").arg(appVersion); color: Style.muted; font.pixelSize: 12 }
                        }
                    }
                    Text {
                        Layout.topMargin: 12
                        Layout.fillWidth: true
                        text: qsTr("A modern, lightweight text editor with a minimalist design, for Omarchy.")
                        color: Style.text
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Inspired by <a href=\"https://github.com/0x7c13/Notepads\">Notepads</a> for Windows by Jackie Liu.")
                        color: Style.muted
                        linkColor: Style.accent
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                        textFormat: Text.StyledText
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                }
            }
        }
    }
}
