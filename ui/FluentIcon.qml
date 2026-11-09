import QtQuick
import QtQuick.Shapes
import SnipShot.Core
import "Icons.js" as Icons

Item {
    id: icon
    property string name
    property color color: Theme.text
    property int size: 16

    implicitWidth: size
    implicitHeight: size

    readonly property string desktopName: Theme.desktopIcons ? (Theme.desktopIconNames[name] || "") : ""
    readonly property bool useDesktop: desktopName.length > 0 && ThemeFiles.hasDesktopIcon(desktopName)

    Image {
        anchors.fill: parent
        visible: icon.useDesktop
        source: icon.useDesktop ? "image://icon/" + icon.desktopName : ""
        sourceSize: Qt.size(icon.size * 2, icon.size * 2)
        smooth: true
    }

    Shape {
        visible: !icon.useDesktop
        width: 24
        height: 24
        scale: icon.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: icon.color
            strokeWidth: -1
            fillRule: ShapePath.WindingFill
            PathSvg { path: (Icons.paths[icon.name] || []).join(" ") }
        }
    }
}
