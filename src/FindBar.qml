import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "."

// The floating Find and Replace box in the editor's top-right corner.
Rectangle {
    id: bar

    property bool replaceVisible: false
    property bool matchCase: false
    property bool wholeWord: false
    property bool useRegex: false
    property bool notFound: false
    property string error: ""
    readonly property string query: findInput.text
    readonly property string replacement: replaceInput.text
    readonly property var options: ({ matchCase: matchCase, wholeWord: wholeWord, regex: useRegex })

    signal findRequested(bool backward, bool incremental)
    signal replaceRequested()
    signal replaceAllRequested()
    signal closed()

    function show(withReplace, seed) {
        replaceVisible = withReplace
        if (seed !== undefined && seed !== "" && seed.indexOf("\n") < 0 && seed.indexOf("\u2029") < 0)
            findInput.text = seed
        visible = true
        if (withReplace && findInput.text !== "")
            replaceInput.forceActiveFocus()
        else
            findInput.forceActiveFocus()
        findInput.selectAll()
    }

    function hide() {
        visible = false
        closed()
    }

    visible: false
    width: Math.min(420, parent ? parent.width - 24 : 420)
    height: column.implicitHeight + 12
    color: Style.panel
    border.color: Style.border
    radius: Style.smallRadius

    onOptionsChanged: if (visible && query !== "") findRequested(false, true)

    component Field: Rectangle {
        id: field
        property alias input: input
        property string placeholder
        property bool invalid: false
        signal accepted(bool shift)
        Layout.fillWidth: true
        implicitHeight: 32
        radius: Style.smallRadius
        color: Style.field
        border.color: invalid ? Style.danger : input.activeFocus ? Style.accent : Style.border

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: Style.text
            selectionColor: Style.selection
            selectedTextColor: Style.selectionText
            font.pixelSize: 13
            clip: true
            selectByMouse: true
            Keys.onReturnPressed: event => field.accepted(event.modifiers & Qt.ShiftModifier)
            Keys.onEnterPressed: event => field.accepted(event.modifiers & Qt.ShiftModifier)
            Keys.onEscapePressed: bar.hide()
        }

        Text {
            anchors.fill: input
            verticalAlignment: Text.AlignVCenter
            text: field.placeholder
            color: Style.faint
            font.pixelSize: 13
            visible: input.text === ""
        }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 6
        spacing: 6

        RowLayout {
            spacing: 2

            IconButton {
                implicitWidth: 28
                icon: bar.replaceVisible ? "chevron-down" : "chevron-right"
                iconSize: 12
                tip: bar.replaceVisible ? qsTr("Hide replace") : qsTr("Show replace (Ctrl+H)")
                onClicked: bar.replaceVisible = !bar.replaceVisible
            }

            Field {
                id: findField
                placeholder: qsTr("Find")
                invalid: bar.notFound || bar.error !== ""
                onAccepted: shift => bar.findRequested(shift, false)
                Connections {
                    target: findField.input
                    function onTextChanged() {
                        bar.findRequested(false, true)
                    }
                }
            }

            IconButton {
                id: optionsButton
                implicitWidth: 32
                icon: "more"
                checked: bar.matchCase || bar.wholeWord || bar.useRegex
                tip: qsTr("Search options")
                onClicked: optionsMenu.popup(optionsButton, 0, optionsButton.height)
            }
            IconButton {
                implicitWidth: 32
                icon: "arrow-up"
                enabled: bar.query !== ""
                tip: qsTr("Previous match (Shift+F3)")
                onClicked: bar.findRequested(true, false)
            }
            IconButton {
                implicitWidth: 32
                icon: "arrow-down"
                enabled: bar.query !== ""
                tip: qsTr("Next match (F3)")
                onClicked: bar.findRequested(false, false)
            }
            IconButton {
                implicitWidth: 32
                icon: "close"
                tip: qsTr("Close (Esc)")
                onClicked: bar.hide()
            }
        }

        RowLayout {
            visible: bar.replaceVisible
            spacing: 2

            Item { implicitWidth: 28 }

            Field {
                id: replaceField
                placeholder: qsTr("Replace")
                onAccepted: bar.replaceRequested()
            }

            IconButton {
                implicitWidth: 32
                icon: "replace"
                enabled: bar.query !== ""
                tip: qsTr("Replace")
                onClicked: bar.replaceRequested()
            }
            IconButton {
                implicitWidth: 32
                icon: "replace-all"
                enabled: bar.query !== ""
                tip: qsTr("Replace all")
                onClicked: bar.replaceAllRequested()
            }
            Item { implicitWidth: 66 }
        }

        Text {
            visible: bar.error !== ""
            Layout.fillWidth: true
            Layout.leftMargin: 30
            text: bar.error
            color: Style.danger
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
    }

    property alias findInput: findField.input
    property alias replaceInput: replaceField.input

    AppMenu {
        id: optionsMenu
        width: 230
        AppMenuItem { text: qsTr("Match case"); checkable: true; checked: bar.matchCase; onTriggered: bar.matchCase = checked }
        AppMenuItem { text: qsTr("Match whole word"); checkable: true; checked: bar.wholeWord; onTriggered: bar.wholeWord = checked }
        AppMenuItem { text: qsTr("Use regular expression"); checkable: true; checked: bar.useRegex; onTriggered: bar.useRegex = checked }
    }
}
