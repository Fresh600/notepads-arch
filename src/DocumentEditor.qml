import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Notepads 1.0
import "."

// One tab's document: the text, the file it belongs to, and how that file
// is encoded. The text itself lives in the TextArea's QTextDocument, which
// also keeps the undo history and the modified flag.
Item {
    id: editor

    property string filePath: ""
    property string encoding: Style.prefs.defaultEncoding
    property string lineEnding: Style.prefs.defaultLineEnding
    property int zoom: 100
    property Menu contextMenu: null
    property bool previewVisible: false

    readonly property alias area: textArea
    readonly property bool modified: textArea.textDocument.modified
    readonly property string title: filePath ? backend.fileName(filePath) : qsTr("Untitled.txt")
    readonly property bool markdown: /\.(md|markdown|mdown|mkd|mkdn)$/i.test(filePath)
    readonly property bool hasSelection: textArea.selectionEnd > textArea.selectionStart
    readonly property int selectedCount: textArea.selectionEnd - textArea.selectionStart
    // Right-to-left paragraphs align to the text's right edge, which
    // without wrapping is the end of the longest line, often far off
    // screen. So a document with Hebrew in it always wraps.
    readonly property bool hasRightToLeft: rightGutter.hasLines
    readonly property bool wraps: Style.prefs.wrapWord || hasRightToLeft
    property int line: 1
    property int column: 1

    signal edited()
    signal zoomRequested(int step)

    // Ctrl+wheel zooms 10% per notch. A touchpad sends many small steps
    // instead of one 120-unit notch, so they add up before zooming.
    property real wheelPending: 0
    function wheelZoom(event) {
        const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y
        wheelPending += delta
        const notches = Math.trunc(wheelPending / 120)
        if (notches !== 0) {
            wheelPending -= notches * 120
            zoomRequested(notches * 10)
        }
        event.accepted = true
    }

    function load(path, forcedEncoding) {
        const result = backend.readFile(path, forcedEncoding || "")
        if (!result.ok)
            return result.error
        textArea.text = result.text
        backend.applyDirections(textArea.textDocument)
        filePath = path
        encoding = result.encoding
        lineEnding = result.lineEnding || Style.prefs.defaultLineEnding
        backend.setModified(textArea.textDocument, false)
        textArea.cursorPosition = 0
        return ""
    }

    function saveTo(path) {
        const error = backend.writeFile(textArea.textDocument, path, encoding, lineEnding)
        if (error)
            return error
        filePath = path
        backend.setModified(textArea.textDocument, false)
        return ""
    }

    function isEmpty() {
        return textArea.length === 0
    }

    function focusText() {
        textArea.forceActiveFocus()
    }

    function setLineEnding(value) {
        if (value === lineEnding)
            return
        lineEnding = value
        backend.setModified(textArea.textDocument, true)
    }

    function setEncoding(value) {
        if (value === encoding)
            return
        encoding = value
        backend.setModified(textArea.textDocument, true)
    }

    // What the session needs to bring this tab back: the text only when it
    // differs from the file, since a saved file is read from disk again.
    function snapshot() {
        return {
            path: filePath,
            encoding: encoding,
            lineEnding: lineEnding,
            modified: modified,
            text: modified ? backend.documentText(textArea.textDocument) : "",
            cursor: textArea.cursorPosition
        }
    }

    function restore(state) {
        if (state.modified) {
            textArea.text = state.text || ""
            backend.applyDirections(textArea.textDocument)
            filePath = state.path || ""
            encoding = state.encoding || Style.prefs.defaultEncoding
            lineEnding = state.lineEnding || Style.prefs.defaultLineEnding
            backend.setModified(textArea.textDocument, true)
        } else if (state.path) {
            if (load(state.path, state.encoding))
                return false
        }
        textArea.cursorPosition = Math.min(state.cursor || 0, textArea.length)
        return true
    }

    function updateLineColumn() {
        const position = backend.lineColumn(textArea.textDocument, textArea.cursorPosition)
        line = position.line
        column = position.column
    }

    function insertIndent() {
        if (Style.prefs.tabSize > 0)
            textArea.insert(textArea.cursorPosition, " ".repeat(Style.prefs.tabSize))
        else
            textArea.insert(textArea.cursorPosition, "\t")
    }

    function duplicateLine() {
        const text = textArea.text
        const position = textArea.cursorPosition
        const start = text.lastIndexOf("\n", position - 1) + 1
        let end = text.indexOf("\n", position)
        if (end < 0)
            end = text.length
        textArea.insert(end, "\n" + text.substring(start, end))
        textArea.cursorPosition = position + (end - start) + 1
    }

    FontMetrics {
        id: metrics
        font: textArea.font
    }

    Timer {
        id: previewTimer
        interval: 250
        onTriggered: preview.text = textArea.text
    }

    Component.onCompleted: backend.attachDirections(textArea.textDocument)

    onPreviewVisibleChanged: if (previewVisible) preview.text = textArea.text

    component Gutter: LineNumberGutter {
        Layout.fillHeight: true
        Layout.preferredWidth: visible ? neededWidth : 0
        visible: Style.prefs.lineNumbers && hasLines
        document: textArea.textDocument
        contentY: scroller.contentItem.contentY
        textTop: textArea.topPadding
        currentLine: editor.line
        color: Style.faint
        currentColor: Style.muted
        font: backend.gutterFont(Style.prefs.fontFamily, Style.prefs.fontSize * editor.zoom / 100)
        clip: true

        WheelHandler {
            acceptedModifiers: Qt.ControlModifier
            onWheel: event => editor.wheelZoom(event)
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Gutter {
            rightSide: false
        }

        ScrollView {
            id: scroller
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            ScrollBar.horizontal.policy: editor.wraps ? ScrollBar.AlwaysOff : ScrollBar.AsNeeded
            // A TextArea's implicit width is its unwrapped width, which the
            // ScrollView would otherwise give it, wrapping off screen.
            contentWidth: editor.wraps ? availableWidth : Math.max(availableWidth, textArea.implicitWidth)

            TextArea {
                id: textArea

                textFormat: TextEdit.PlainText
                wrapMode: editor.wraps ? TextEdit.Wrap : TextEdit.NoWrap
                // Hebrew and Arabic fonts first: they only cover their own
                // script, so everything else falls through to the editor font.
                font: backend.editorFont(Style.editorFamilies, Style.prefs.fontSize * editor.zoom / 100,
                                         Style.prefs.wordSpacingPercent)
                color: Style.text
                selectionColor: Style.accent
                selectedTextColor: Style.accentText
                placeholderText: ""
                persistentSelection: true
                selectByMouse: true
                // Line numbers bring their own margin.
                leftPadding: Style.prefs.lineNumbers ? 4 : 12
                rightPadding: Style.prefs.lineNumbers ? 4 : 12
                topPadding: 8
                bottomPadding: 8
                // Material insets the background for its floating label;
                // the line highlight needs it to line up with the text.
                topInset: 0
                bottomInset: 0
                leftInset: 0
                rightInset: 0
                tabStopDistance: metrics.advanceWidth(" ") * (Style.prefs.tabSize > 0 ? Style.prefs.tabSize : 4)
                ContextMenu.menu: editor.contextMenu
                Material.accent: Style.accent

                background: Item {
                    Rectangle {
                        visible: Style.prefs.highlightLine && textArea.activeFocus && !editor.hasSelection
                        x: 0
                        width: parent.width
                        y: textArea.cursorRectangle.y
                        height: textArea.cursorRectangle.height
                        color: Style.lineHighlight
                    }
                }

                onCursorPositionChanged: editor.updateLineColumn()
                onTextChanged: {
                    editor.edited()
                    if (editor.previewVisible)
                        previewTimer.restart()
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Tab && event.modifiers === Qt.NoModifier && Style.prefs.tabSize > 0) {
                        editor.insertIndent()
                        event.accepted = true
                    }
                }

                WheelHandler {
                    acceptedModifiers: Qt.ControlModifier
                    onWheel: event => editor.wheelZoom(event)
                }
            }
        }

        Gutter {
            id: rightGutter
            rightSide: true
        }

        Rectangle {
            visible: preview.visible
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: Style.border
        }

        ScrollView {
            visible: editor.previewVisible
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1

            TextArea {
                id: preview
                readOnly: true
                textFormat: TextEdit.MarkdownText
                wrapMode: TextEdit.Wrap
                color: Style.text
                selectionColor: Style.accent
                selectedTextColor: Style.accentText
                font.pixelSize: 14
                padding: 20
                background: null
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
        }
    }
}
