import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// Every keyboard shortcut, shown with F1.
Popup {
    id: overlay

    readonly property var shortcuts: [
        ["Ctrl+N / Ctrl+T", qsTr("New tab")],
        ["Ctrl+O", qsTr("Open files")],
        ["Ctrl+S", qsTr("Save")],
        ["Ctrl+Shift+S", qsTr("Save as")],
        ["Ctrl+Alt+S", qsTr("Save all")],
        ["Ctrl+W", qsTr("Close tab")],
        ["Ctrl+Tab / Ctrl+Shift+Tab", qsTr("Next / previous tab")],
        ["Ctrl+1 … Ctrl+9", qsTr("Go to tab")],
        ["Ctrl+F", qsTr("Find")],
        ["Ctrl+H", qsTr("Replace")],
        ["F3 / Shift+F3", qsTr("Next / previous match")],
        ["Ctrl+Z / Ctrl+Shift+Z", qsTr("Undo / redo")],
        ["Ctrl+D", qsTr("Duplicate line")],
        ["Ctrl+E", qsTr("Search the web for the selection")],
        ["Ctrl+= / Ctrl+- / Ctrl+wheel", qsTr("Zoom in / out")],
        ["Ctrl+0", qsTr("Reset zoom")],
        ["Alt+Z", qsTr("Toggle word wrap")],
        ["Alt+P", qsTr("Toggle Markdown preview")],
        ["Ctrl+,", qsTr("Settings")],
        ["F1", qsTr("Show shortcuts")],
        ["Ctrl+Q", qsTr("Quit")]
    ]

    anchors.centerIn: Overlay.overlay
    width: Math.min(560, (parent ? parent.width : 560) - 40)
    modal: true
    focus: true
    padding: 24

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.35)
    }

    background: Rectangle {
        color: Style.panel
        border.color: Style.border
        radius: Style.radius
    }

    contentItem: ColumnLayout {
        spacing: 14

        Text {
            text: qsTr("Keyboard shortcuts")
            color: Style.text
            font.pixelSize: 22
            font.weight: Font.Light
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 24
            rowSpacing: 6

            Repeater {
                model: overlay.shortcuts.length * 2
                delegate: Text {
                    required property int index
                    readonly property var entry: overlay.shortcuts[Math.floor(index / 2)]
                    Layout.fillWidth: index % 2 === 1
                    text: entry[index % 2]
                    color: index % 2 === 0 ? Style.text : Style.muted
                    font.pixelSize: 13
                    font.family: index % 2 === 0 ? "monospace" : Qt.application.font.family
                }
            }
        }
    }
}
