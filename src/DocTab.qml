import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// One tab in the strip: the file icon, its name, and a close button that a
// dot stands in for while the file has unsaved changes.
Item {
    id: tab

    property var doc
    property bool active: false
    readonly property bool hovered: hover.hovered

    signal activate()
    signal closeRequested()
    signal menuRequested(real x, real y)

    height: 32

    HoverHandler {
        id: hover
    }

    Rectangle {
        anchors.fill: parent
        color: tab.active ? Style.activeTab : tab.hovered ? Style.tabHover : Style.strip
    }

    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 16
        color: Style.border
        visible: !tab.active
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onPressed: mouse => {
            if (mouse.button === Qt.MiddleButton)
                tab.closeRequested()
            else
                tab.activate()
        }
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                tab.menuRequested(mouse.x, mouse.y)
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 4
        spacing: 8

        Icon {
            name: "file"
            color: Style.accent
            width: 15
            height: 15
        }

        Text {
            Layout.fillWidth: true
            text: tab.doc ? tab.doc.title : ""
            color: tab.active ? Style.text : Style.muted
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Item {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 24

            Rectangle {
                anchors.centerIn: parent
                width: 7
                height: 7
                radius: 3.5
                color: tab.active ? Style.text : Style.muted
                visible: tab.doc && tab.doc.modified && !tab.hovered
            }

            IconButton {
                anchors.fill: parent
                icon: "close"
                iconSize: 12
                tip: qsTr("Close tab (Ctrl+W)")
                visible: tab.doc && (tab.doc.modified ? tab.hovered : (tab.active || tab.hovered))
                onClicked: tab.closeRequested()
            }
        }
    }

    ToolTip.visible: tab.hovered && tab.doc && tab.doc.filePath !== ""
    ToolTip.delay: 900
    ToolTip.text: tab.doc ? tab.doc.filePath : ""
}
