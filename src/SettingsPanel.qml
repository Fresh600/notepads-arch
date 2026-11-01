import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
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

    component Heading: Text {
        color: Style.text
        font.pixelSize: 20
        Layout.topMargin: 18
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }

    component Note: Text {
        color: Style.muted
        font.pixelSize: 12
        font.italic: true
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }

    component Choice: RadioButton {
        Layout.fillWidth: true
        Material.accent: Style.accent
        Material.foreground: Style.text
        font.pixelSize: 13
        topPadding: 2
        bottomPadding: 2
    }

    component Toggle: Switch {
        Layout.fillWidth: true
        Material.accent: Style.accent
        Material.foreground: Style.text
        font.pixelSize: 13
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

                    Heading { text: qsTr("Text Wrapping") }
                    Toggle {
                        text: qsTr("Wrap word")
                        checked: Style.prefs.wrapWord
                        onToggled: Style.prefs.wrapWord = checked
                    }

                    Note { text: qsTr("Documents with Hebrew always wrap, so right-to-left lines stay in view.") }

                    Heading { text: qsTr("Line Numbers") }
                    Toggle {
                        text: qsTr("Show line numbers")
                        checked: Style.prefs.lineNumbers
                        onToggled: Style.prefs.lineNumbers = checked
                    }
                    Note { text: qsTr("Hebrew lines are numbered on the right.") }

                    Heading { text: qsTr("Spelling") }
                    Toggle {
                        text: qsTr("Underline spelling mistakes")
                        enabled: spellChecker.available
                        checked: Style.prefs.spellUnderline
                        onToggled: Style.prefs.spellUnderline = checked
                    }
                    Toggle {
                        text: qsTr("Suggest corrections in the right-click menu")
                        enabled: spellChecker.available
                        checked: Style.prefs.spellSuggestions
                        onToggled: Style.prefs.spellSuggestions = checked
                    }
                    Note {
                        text: spellChecker.available
                              ? qsTr("Dictionaries: %1. Install more with pacman, for example hunspell-he for Hebrew.").arg(spellChecker.languages().join(", "))
                              : qsTr("No dictionaries are installed. Install one with pacman, for example hunspell-en_us.")
                    }

                    Heading { text: qsTr("Line Highlighter") }
                    Toggle {
                        text: qsTr("Highlight the current line")
                        checked: Style.prefs.highlightLine
                        onToggled: Style.prefs.highlightLine = checked
                    }

                    Heading { text: qsTr("Font") }
                    Toggle {
                        visible: Style.rtlFamilies.length > 0
                        text: qsTr("Proportional font for Hebrew")
                        checked: Style.prefs.proportionalRtl
                        onToggled: Style.prefs.proportionalRtl = checked
                    }
                    ComboBox {
                        id: fontBox
                        implicitHeight: 40
                        font.pixelSize: 13
                        Layout.fillWidth: true
                        Material.accent: Style.accent
                        Material.foreground: Style.text
                        model: ["monospace"].concat(Qt.fontFamilies())
                        currentIndex: Math.max(0, model.indexOf(Style.prefs.fontFamily))
                        displayText: currentText === "monospace" ? qsTr("Default monospace (Omarchy font)") : currentText
                        onActivated: index => Style.prefs.fontFamily = model[index]
                    }
                    ComboBox {
                        Layout.preferredWidth: 110
                        implicitHeight: 40
                        font.pixelSize: 13
                        Material.accent: Style.accent
                        Material.foreground: Style.text
                        model: [8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 24, 28, 32, 36, 48, 72]
                        currentIndex: Math.max(0, model.indexOf(Style.prefs.fontSize))
                        displayText: Style.prefs.fontSize
                        onActivated: index => Style.prefs.fontSize = model[index]
                    }

                    Heading { text: qsTr("Word Spacing") }
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
                        Text {
                            text: Style.prefs.wordSpacingPercent + "%"
                            color: Style.muted
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: 40
                        }
                        IconButton {
                            implicitWidth: 28
                            icon: "undo"
                            tip: qsTr("Reset to the font's own spacing")
                            enabled: Style.prefs.wordSpacingPercent !== 100
                            onClicked: Style.prefs.wordSpacingPercent = 100
                        }
                    }
                    Note { text: qsTr("100% is the font's own space. Below 100% brings words closer. Spaces used for indentation change too.") }

                    Heading { text: qsTr("Tab Indentation") }
                    ComboBox {
                        Layout.preferredWidth: 160
                        implicitHeight: 40
                        font.pixelSize: 13
                        Material.accent: Style.accent
                        Material.foreground: Style.text
                        textRole: "label"
                        valueRole: "value"
                        model: [
                            { label: qsTr("Tab"), value: 0 },
                            { label: qsTr("2 spaces"), value: 2 },
                            { label: qsTr("4 spaces"), value: 4 },
                            { label: qsTr("8 spaces"), value: 8 }
                        ]
                        currentIndex: Math.max(0, indexOfValue(Style.prefs.tabSize))
                        onActivated: Style.prefs.tabSize = currentValue
                    }

                    Heading { text: qsTr("Default Line Ending") }
                    Repeater {
                        model: ["crlf", "cr", "lf"]
                        delegate: Choice {
                            required property string modelData
                            text: Style.lineEndingName(modelData)
                            checked: Style.prefs.defaultLineEnding === modelData
                            onClicked: Style.prefs.defaultLineEnding = modelData
                        }
                    }
                    Note { text: qsTr("Only applies to new documents") }

                    Heading { text: qsTr("Default Encoding") }
                    Repeater {
                        model: Style.encodings
                        delegate: Choice {
                            required property var modelData
                            text: modelData.name
                            checked: Style.prefs.defaultEncoding === modelData.key
                            onClicked: Style.prefs.defaultEncoding = modelData.key
                        }
                    }
                    Note { text: qsTr("Only applies to new documents") }

                    Heading { text: qsTr("Default Search Engine") }
                    Repeater {
                        model: [
                            { key: "google", name: "Google" },
                            { key: "bing", name: "Bing" },
                            { key: "duckduckgo", name: "DuckDuckGo" }
                        ]
                        delegate: Choice {
                            required property var modelData
                            text: modelData.name
                            checked: Style.prefs.searchEngine === modelData.key
                            onClicked: Style.prefs.searchEngine = modelData.key
                        }
                    }
                    Item { implicitHeight: 16 }
                }

                // Personalization
                ColumnLayout {
                    visible: panel.page === 1
                    Layout.fillWidth: true
                    spacing: 4

                    Heading { text: qsTr("Theme Mode") }
                    Repeater {
                        model: [
                            { key: "light", name: qsTr("Light") },
                            { key: "dark", name: qsTr("Dark") },
                            { key: "system", name: qsTr("Use Omarchy setting") }
                        ]
                        delegate: Choice {
                            required property var modelData
                            text: modelData.name
                            checked: Style.prefs.themeMode === modelData.key
                            onClicked: Style.prefs.themeMode = modelData.key
                        }
                    }
                    Toggle {
                        text: qsTr("Use Omarchy theme colors")
                        checked: Style.prefs.omarchyColors
                        onToggled: Style.prefs.omarchyColors = checked
                    }

                    Heading { text: qsTr("Background Tint Opacity") }
                    RowLayout {
                        Layout.fillWidth: true
                        Slider {
                            Layout.fillWidth: true
                            Material.accent: Style.accent
                            from: 0.2
                            to: 1
                            stepSize: 0.01
                            value: Style.prefs.tintOpacity
                            onMoved: Style.prefs.tintOpacity = value
                        }
                        Text {
                            text: Math.round(Style.prefs.tintOpacity * 100) + "%"
                            color: Style.muted
                            font.pixelSize: 12
                            Layout.preferredWidth: 36
                        }
                    }
                    Note { text: qsTr("Lower values let more of the blurred wallpaper through.") }

                    Heading { text: qsTr("Accent Color") }
                    Toggle {
                        text: qsTr("Use Omarchy accent color")
                        checked: Style.prefs.omarchyAccent
                        onToggled: Style.prefs.omarchyAccent = checked
                    }
                    Flow {
                        visible: !Style.prefs.omarchyAccent
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: ["#0078d4", "#0099bc", "#00b294", "#10893e", "#ffb900", "#ca5010",
                                    "#e81123", "#e3008c", "#c239b3", "#8764b8", "#6b69d6", "#767676"]
                            delegate: Rectangle {
                                required property string modelData
                                width: 32
                                height: 32
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

                    Heading { text: qsTr("Status Bar") }
                    Toggle {
                        text: qsTr("Show status bar")
                        checked: Style.prefs.showStatusBar
                        onToggled: Style.prefs.showStatusBar = checked
                    }

                    Heading { text: qsTr("Global Shortcut") }
                    Note {
                        font.italic: false
                        text: qsTr("Opens a new Notepads window from anywhere, the way the terminal does.")
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
                    Note { text: qsTr("Saved as a Hyprland binding in ~/.config/hypr/notepads.lua.") }

                    Heading { text: qsTr("Accept Spelling Suggestion") }
                    Note {
                        font.italic: false
                        text: qsTr("Replaces the misspelled word at the cursor with the dictionary's first suggestion.")
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

                    Heading { text: qsTr("Session Snapshot") }
                    Toggle {
                        text: qsTr("Restore tabs and unsaved changes")
                        checked: Style.prefs.sessionSnapshot
                        onToggled: Style.prefs.sessionSnapshot = checked
                    }
                    Note { text: qsTr("When on, closing Notepads keeps unsaved work for next time instead of asking.") }
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
