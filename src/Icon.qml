import QtQuick
import QtQuick.Window

// A line icon from :/icons, painted in any color at the screen's density.
// The Image sits inside a fixed-size Item: an Image's implicit size follows
// the pixmap it loaded, and with a scale factor above 1 that would widen the
// icon, reload it larger, and never settle.
Item {
    id: icon

    property string name
    property color color: "white"

    implicitWidth: 16
    implicitHeight: 16

    Image {
        anchors.fill: parent
        sourceSize: Qt.size(Math.ceil(icon.width * Screen.devicePixelRatio),
                            Math.ceil(icon.height * Screen.devicePixelRatio))
        source: icon.name && icon.width > 0 ? "image://icon/" + icon.name + "/" + icon.color.toString().substring(1) : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
