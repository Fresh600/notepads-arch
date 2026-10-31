import QtQuick
import QtQuick.Controls
import "."

// A piece of the status bar; clickable ones light up on hover.
Item {
    id: item

    property string text
    property color textColor: Style.muted
    property bool clickable: false
    property string tip
    property alias elide: label.elide

    signal clicked()

    implicitWidth: label.implicitWidth + 20
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        color: item.clickable && area.containsMouse ? (area.pressed ? Style.pressed : Style.hover) : "transparent"
    }

    Text {
        id: label
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: Text.AlignVCenter
        text: item.text
        color: item.textColor
        font.pixelSize: 12
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: item.clickable || item.tip !== ""
        cursorShape: item.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (item.clickable) item.clicked()
    }

    ToolTip.visible: item.tip !== "" && area.containsMouse
    ToolTip.delay: 700
    ToolTip.text: item.tip
}
