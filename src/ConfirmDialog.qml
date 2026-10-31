import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "."

// "Save your changes?" with Save, Don't save, and Cancel.
Popup {
    id: dialog

    property string heading
    property string message
    property string acceptText
    property string discardText
    property var onAccept: null
    property var onDiscard: null

    function ask(heading, message, acceptText, discardText, accept, discard) {
        dialog.heading = heading
        dialog.message = message
        dialog.acceptText = acceptText
        dialog.discardText = discardText
        dialog.onAccept = accept
        dialog.onDiscard = discard
        open()
    }

    function finish(callback) {
        close()
        if (callback)
            Qt.callLater(callback)
    }

    anchors.centerIn: Overlay.overlay
    width: Math.min(440, (parent ? parent.width : 440) - 40)
    modal: true
    focus: true
    padding: 24
    closePolicy: Popup.CloseOnEscape

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.35)
    }

    background: Rectangle {
        color: Style.panel
        border.color: Style.border
        radius: Style.radius
    }

    contentItem: ColumnLayout {
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: dialog.heading
            color: Style.text
            font.pixelSize: 20
            wrapMode: Text.Wrap
        }
        Text {
            Layout.fillWidth: true
            text: dialog.message
            color: Style.muted
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }
        RowLayout {
            Layout.topMargin: 12
            Layout.fillWidth: true
            spacing: 8
            FlatButton {
                Layout.fillWidth: true
                text: dialog.acceptText
                primary: true
                onClicked: dialog.finish(dialog.onAccept)
            }
            FlatButton {
                Layout.fillWidth: true
                text: dialog.discardText
                onClicked: dialog.finish(dialog.onDiscard)
            }
            FlatButton {
                Layout.fillWidth: true
                text: qsTr("Cancel")
                onClicked: dialog.finish(null)
            }
        }
    }

    Shortcut {
        enabled: dialog.opened
        sequences: ["Return", "Enter"]
        onActivated: dialog.finish(dialog.onAccept)
    }
}
