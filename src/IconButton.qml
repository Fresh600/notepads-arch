import QtQuick
import QtQuick.Controls
import "."

// A flat Fluent-style button: an icon, a soft hover, and a tooltip.
Item {
    id: button

    property string icon
    property string tip
    property color iconColor: Style.text
    property int iconSize: 16
    property bool checked: false
    property bool flat: true

    signal clicked()

    implicitWidth: 40
    implicitHeight: 32
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: Style.smallRadius
        color: area.pressed ? Style.pressed : (area.containsMouse || button.checked) ? Style.hover : "transparent"
    }

    Icon {
        anchors.centerIn: parent
        name: button.icon
        color: button.iconColor
        width: button.iconSize
        height: button.iconSize
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: button.clicked()
    }

    ToolTip.visible: button.tip !== "" && area.containsMouse
    ToolTip.delay: 700
    ToolTip.text: button.tip
}
