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

                    Heading { text: qsTr("Line Highlighter") }
                    Toggle {
                        text: qsTr("Highlight the current line")
                        checked: Style.prefs.highlightLine
                        onToggled: Style.prefs.highlightLine = checked
                    }

                    Heading { text: qsTr("Font") }
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
