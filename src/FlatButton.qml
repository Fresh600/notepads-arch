import QtQuick
import QtQuick.Controls
import "."

// A text button for dialogs and the find bar; the primary one is filled
// with the accent.
Item {
    id: button

    property string text
    property bool primary: false

    signal clicked()

    implicitWidth: Math.max(88, label.implicitWidth + 28)
    implicitHeight: 32
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: Style.smallRadius
        color: button.primary ? Style.accent : Style.field
        border.color: button.primary ? "transparent" : Style.border
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: area.pressed ? Style.pressed : area.containsMouse ? Style.hover : "transparent"
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: button.text
        color: button.primary ? Style.accentText : Style.text
        font.pixelSize: 13
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: button.clicked()
    }
}
