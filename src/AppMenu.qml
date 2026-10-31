import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import "."

// A Fluent-looking menu: a flat panel with a hairline border, icons on the
// left and shortcuts on the right.
Menu {
    id: menu

    width: 280
    topPadding: 4
    bottomPadding: 4
    margins: 8
    Material.roundedScale: Style.radius

    delegate: AppMenuItem {}

    background: Rectangle {
        implicitWidth: 280
        color: Style.menu
        border.color: Style.border
        radius: Style.smallRadius
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 110; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 80 }
    }
}
