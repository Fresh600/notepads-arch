import QtQuick
import QtQuick.Window

// A line icon from :/icons, painted in any color at the screen's density.
Image {
    property string name
    property color color: "white"

    width: 16
    height: 16
    sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
    source: name ? "image://icon/" + name + "/" + color.toString().substring(1) : ""
    fillMode: Image.PreserveAspectFit
    smooth: true
}
