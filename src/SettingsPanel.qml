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
    property bool recording: false
    property string shortcutError: ""

    onClosed: recording = false

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
            recording = false
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
        recording = false
        setShortcut(parts.concat([key]).join(" + "))
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

    // A group of settings: a small label over its rows.
    component Section: Text {
        color: Style.muted
        font.pixelSize: 12
        font.weight: Font.DemiBold
        Layout.topMargin: 28
        Layout.bottomMargin: 4
        Layout.leftMargin: 8
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }

    component Note: Text {
        color: Style.muted
        font.pixelSize: 12
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }

    // A setting's name on the left and its control on the right; the
    // control is the row's child.
    component SettingRow: RowLayout {
        property alias label: rowLabel.text
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.minimumHeight: 44
        spacing: 12
        Text {
            id: rowLabel
            Layout.fillWidth: true
            color: Style.text
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }
    }

    component Combo: ComboBox {
        Layout.preferredWidth: 160
        implicitHeight: 40
        font.pixelSize: 13
        Material.accent: Style.accent
        Material.foreground: Style.text
    }

    // A whole row that flips a setting: the name and an optional note on
    // the left, a small switch on the right.
    component Toggle: Switch {
        id: toggle
        property string note: ""
        Layout.fillWidth: true
        implicitHeight: Math.max(44, implicitContentHeight + topPadding + bottomPadding)
        leftPadding: 8
        rightPadding: 8 + indicator.width + 12
        topPadding: 8
        bottomPadding: 8
        font.pixelSize: 13

        background: Rectangle {
            radius: Style.smallRadius
            color: toggle.pressed ? Style.pressed : toggle.hovered ? Style.hover : "transparent"
            border.width: toggle.visualFocus ? 1 : 0
            border.color: Style.accent
        }

        indicator: Rectangle {
            x: toggle.width - width - 8
            y: (toggle.height - height) / 2
            implicitWidth: 32
            implicitHeight: 18
            radius: height / 2
            color: toggle.checked ? Style.accent : "transparent"
            border.width: toggle.checked ? 0 : 1
            border.color: Style.muted

            Rectangle {
                x: toggle.checked ? parent.width - width - 4 : 4
                y: (parent.height - height) / 2
                width: 10
                height: 10
                radius: 5
                color: toggle.checked ? Style.accentText : Style.muted
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
        }

        contentItem: ColumnLayout {
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: toggle.text
                color: Style.text
                font: toggle.font
                wrapMode: Text.Wrap
            }
            Text {
                Layout.fillWidth: true
                visible: toggle.note !== ""
                text: toggle.note
                color: Style.muted
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
        }
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
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }

                // Text & Editor
                ColumnLayout {
                    visible: panel.page === 0
                    Layout.fillWidth: true
                    spacing: 8

                    Section { text: qsTr("Editor") }
                    Toggle {
                        text: qsTr("Wrap words")
                        note: qsTr("Documents with Hebrew always wrap, so right-to-left lines stay in view.")
                        checked: Style.prefs.wrapWord
                        onToggled: Style.prefs.wrapWord = checked
                    }
                    Toggle {
                        text: qsTr("Show line numbers")
                        note: qsTr("Hebrew lines are numbered on the right.")
                        checked: Style.prefs.lineNumbers
                        onToggled: Style.prefs.lineNumbers = checked
                    }
                    Toggle {
                        text: qsTr("Highlight the current line")
                        checked: Style.prefs.highlightLine
                        onToggled: Style.prefs.highlightLine = checked
                    }
                    SettingRow {
                        label: qsTr("Indent with")
                        Combo {
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
                    }
                    SettingRow {
                        label: qsTr("Search the web with")
                        Combo {
                            textRole: "name"
                            valueRole: "key"
                            model: [
                                { key: "google", name: "Google" },
                                { key: "bing", name: "Bing" },
                                { key: "duckduckgo", name: "DuckDuckGo" }
                            ]
                            currentIndex: Math.max(0, indexOfValue(Style.prefs.searchEngine))
                            onActivated: Style.prefs.searchEngine = currentValue
                        }
                    }

                    Section { text: qsTr("Font") }
                    SettingRow {
                        label: qsTr("Family")
                        Combo {
                            Layout.preferredWidth: 200
                            model: ["monospace"].concat(Qt.fontFamilies())
                            currentIndex: Math.max(0, model.indexOf(Style.prefs.fontFamily))
                            displayText: currentText === "monospace" ? qsTr("Omarchy monospace") : currentText
                            onActivated: index => Style.prefs.fontFamily = model[index]
                        }
                    }
                    SettingRow {
                        label: qsTr("Size")
                        Combo {
                            Layout.preferredWidth: 90
                            model: [8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 24, 28, 32, 36, 48, 72]
                            currentIndex: Math.max(0, model.indexOf(Style.prefs.fontSize))
                            displayText: Style.prefs.fontSize
                            onActivated: index => Style.prefs.fontSize = model[index]
                        }
                    }
                    Toggle {
                        visible: Style.rtlFamilies.length > 0
                        text: qsTr("Proportional font for Hebrew")
                        checked: Style.prefs.proportionalRtl
                        onToggled: Style.prefs.proportionalRtl = checked
                    }
                    SettingRow {
                        label: qsTr("Word spacing")
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
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
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
                    Note { text: qsTr("100% is the font's own space. Below 100% brings words closer. Spaces used for indentation change too.") }

                    Section { text: qsTr("New documents") }
                    SettingRow {
                        label: qsTr("Line ending")
                        Combo {
                            model: ["lf", "crlf", "cr"]
                            currentIndex: Math.max(0, model.indexOf(Style.prefs.defaultLineEnding))
                            displayText: Style.lineEndingName(currentText)
                            delegate: MenuItem {
                                required property string modelData
                                required property int index
                                width: ListView.view.width
                                text: Style.lineEndingName(modelData)
                                highlighted: ListView.view.currentIndex === index
                            }
                            onActivated: index => Style.prefs.defaultLineEnding = model[index]
                        }
                    }
                    SettingRow {
                        label: qsTr("Encoding")
                        Combo {
                            textRole: "name"
                            valueRole: "key"
                            model: Style.encodings
                            currentIndex: Math.max(0, indexOfValue(Style.prefs.defaultEncoding))
                            onActivated: Style.prefs.defaultEncoding = currentValue
                        }
                    }
                    Item { implicitHeight: 16 }
                }

                // Personalization
                ColumnLayout {
                    visible: panel.page === 1
                    Layout.fillWidth: true
                    spacing: 8

                    Section { text: qsTr("Theme") }
                    SettingRow {
                        label: qsTr("Mode")
                        Combo {
                            textRole: "name"
                            valueRole: "key"
                            model: [
                                { key: "system", name: qsTr("Follow Omarchy") },
                                { key: "light", name: qsTr("Light") },
                                { key: "dark", name: qsTr("Dark") }
                            ]
                            currentIndex: Math.max(0, indexOfValue(Style.prefs.themeMode))
                            onActivated: Style.prefs.themeMode = currentValue
                        }
                    }
                    Toggle {
                        text: qsTr("Use Omarchy theme colors")
                        checked: Style.prefs.omarchyColors
                        onToggled: Style.prefs.omarchyColors = checked
                    }

                    Section { text: qsTr("Accent color") }
                    Toggle {
                        text: qsTr("Use Omarchy accent color")
                        checked: Style.prefs.omarchyAccent
                        onToggled: Style.prefs.omarchyAccent = checked
                    }
                    Flow {
                        visible: !Style.prefs.omarchyAccent
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
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

                    Section { text: qsTr("Window") }
                    SettingRow {
                        label: qsTr("Background tint")
                        Text {
                            text: Math.round(Style.prefs.tintOpacity * 100) + "%"
                            color: Style.muted
                            font.pixelSize: 12
                        }
                    }
                    Slider {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        Material.accent: Style.accent
                        from: 0.2
                        to: 1
                        stepSize: 0.01
                        value: Style.prefs.tintOpacity
                        onMoved: Style.prefs.tintOpacity = value
                    }
                    Note { text: qsTr("Lower values let more of the blurred wallpaper through.") }
                    Item { implicitHeight: 16 }
                }

                // Advanced
                ColumnLayout {
                    visible: panel.page === 2
                    Layout.fillWidth: true
                    spacing: 8

                    Section { text: qsTr("Window") }
                    Toggle {
                        text: qsTr("Show status bar")
                        checked: Style.prefs.showStatusBar
                        onToggled: Style.prefs.showStatusBar = checked
                    }
                    Toggle {
                        text: qsTr("Restore tabs and unsaved changes")
                        note: qsTr("When on, closing Notepads keeps unsaved work for next time instead of asking.")
                        checked: Style.prefs.sessionSnapshot
                        onToggled: Style.prefs.sessionSnapshot = checked
                    }

                    Section { text: qsTr("Global shortcut") }
                    Note { text: qsTr("Opens a new Notepads window from anywhere, the way the terminal does.") }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        Layout.topMargin: 6
                        spacing: 8

                        Rectangle {
                            id: shortcutBox
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Style.smallRadius
                            color: Style.field
                            border.color: panel.recording ? Style.accent : Style.border
                            focus: panel.recording

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                color: panel.recording || !Style.prefs.globalShortcut ? Style.muted : Style.text
                                text: panel.recording ? qsTr("Press the new shortcut… (Esc cancels)")
                                      : Style.prefs.globalShortcut ? globalShortcut.displayName(Style.prefs.globalShortcut)
                                      : qsTr("None")
                            }

                            Keys.onPressed: event => panel.recordShortcut(event)
                        }
                        FlatButton {
                            text: panel.recording ? qsTr("Cancel") : qsTr("Change")
                            onClicked: {
                                panel.shortcutError = ""
                                panel.recording = !panel.recording
                                if (panel.recording)
                                    shortcutBox.forceActiveFocus()
                            }
                        }
                        IconButton {
                            implicitWidth: 32
                            icon: "close"
                            tip: qsTr("Remove the shortcut")
                            visible: Style.prefs.globalShortcut !== "" && !panel.recording
                            onClicked: panel.setShortcut("")
                        }
                    }
                    Note {
                        visible: panel.shortcutError !== ""
                        text: panel.shortcutError
                        color: Style.danger
                    }
                    Note { text: qsTr("Saved as a Hyprland binding in ~/.config/hypr/notepads.lua.") }
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
