import QtQuick
import QtQuick.Controls
import "."

MenuSeparator {
    // Hidden separators give up their row, like hidden items.
    height: visible ? implicitHeight : 0
    topPadding: 4
    bottomPadding: 4
    leftPadding: 12
    rightPadding: 12
    contentItem: Rectangle {
        implicitHeight: 1
        color: Style.border
    }
}
