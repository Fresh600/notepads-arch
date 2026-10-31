import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "."

MenuItem {
    id: item

    property string iconName
    property string shortcut

    // Hidden items in a Menu still take a row unless they give up their height.
    height: visible ? implicitHeight : 0
    implicitHeight: 34
    leftPadding: 12
    rightPadding: 12
    opacity: enabled ? 1 : 0.4

    indicator: Item {}
    arrow: Item {}

    contentItem: RowLayout {
        spacing: 12

        Item {
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            Icon {
                anchors.fill: parent
                name: item.checkable ? (item.checked ? "check" : "")
                     : item.iconName || (item.subMenu && item.subMenu.iconName ? item.subMenu.iconName : "")
                color: Style.text
            }
        }

        Text {
            Layout.fillWidth: true
            text: item.text
            color: Style.text
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Text {
            visible: item.shortcut !== ""
            text: item.shortcut
            color: Style.muted
            font.pixelSize: 12
        }

        Icon {
            visible: item.subMenu !== null
            name: "chevron-right"
            color: Style.muted
            width: 12
            height: 12
        }
    }

    background: Item {
        implicitWidth: 280
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            radius: Style.smallRadius
            color: item.highlighted ? Style.hover : "transparent"
        }
    }
}
