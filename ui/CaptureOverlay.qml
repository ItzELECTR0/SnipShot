import QtQuick
import QtQuick.Shapes
import SnipShot.Core

Window {
    id: overlay
    required property var targetScreen
    readonly property rect area: targetScreen.geometry
    readonly property string screenName: targetScreen.name
    readonly property bool live: Capture.purpose === "record"
    readonly property bool armed: Capture.state === "armed"
    readonly property bool active: Capture.activeScreen === screenName
    property bool dragging: false
    property point dragStart
    property var strokePoints: []

    width: area.width
    height: area.height
    color: "transparent"
    title: "SnipShot capture"
    flags: Qt.FramelessWindowHint

    function local(point) { return Qt.point(point.x - area.x, point.y - area.y) }
    function global(x, y) { return Qt.point(x + area.x, y + area.y) }
    function rectContains(r, p) { return p.x >= r.x && p.y >= r.y && p.x < r.x + r.width && p.y < r.y + r.height }

    readonly property rect selection: Capture.selection
    readonly property bool hasSelection: selection.width > 0 && selection.height > 0
    readonly property bool freeform: Capture.mode === "freeform" && Capture.freeformPath.length > 2
    readonly property var holePoints: {
        if (!hasSelection) return []
        if (freeform) {
            const points = []
            for (const point of Capture.freeformPath) points.push(local(point))
            points.push(points[0])
            return points
        }
        const s = selection
        return [Qt.point(s.x - area.x, s.y - area.y), Qt.point(s.x + s.width - area.x, s.y - area.y),
                Qt.point(s.x + s.width - area.x, s.y + s.height - area.y), Qt.point(s.x - area.x, s.y + s.height - area.y),
                Qt.point(s.x - area.x, s.y - area.y)]
    }

    Image {
        anchors.fill: parent
        visible: !overlay.live
        source: overlay.visible ? "image://frozen/" + overlay.screenName + "/" + Capture.frozenSerial : ""
        cache: false
        smooth: true
        mipmap: false
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.GeometryRenderer
        ShapePath {
            fillColor: Theme.dim
            strokeWidth: -1
            fillRule: ShapePath.OddEvenFill
            PathSvg { path: "M0 0 H" + overlay.width + " V" + overlay.height + " H0 Z" }
            PathPolyline { path: overlay.holePoints }
        }
    }

    Rectangle {
        visible: overlay.hasSelection && !overlay.freeform
        x: overlay.selection.x - overlay.area.x - 1
        y: overlay.selection.y - overlay.area.y - 1
        width: overlay.selection.width + 2
        height: overlay.selection.height + 2
        color: "transparent"
        border.width: 1
        border.color: overlay.live ? Theme.recordFill : "#ffffff"
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            color: "transparent"
            border.width: 1
            border.color: "#40000000"
        }
    }

    Shape {
        anchors.fill: parent
        visible: overlay.freeform
        ShapePath {
            fillColor: "transparent"
            strokeColor: "#ffffff"
            strokeWidth: 1.5
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: overlay.holePoints }
        }
    }

    // Windows stacked above the hovered one stay dimmed and cover its outline.
    readonly property var occluders: {
        if (Capture.mode !== "window" || !hasSelection) return []
        const s = selection
        const rects = Capture.windowRects
        const hovered = rects.findIndex(r => r.x === s.x && r.y === s.y && r.width === s.width && r.height === s.height)
        const covers = []
        for (let index = 0; index < hovered; ++index) {
            const r = rects[index]
            const left = Math.max(r.x, s.x), top = Math.max(r.y, s.y)
            const right = Math.min(r.x + r.width, s.x + s.width), bottom = Math.min(r.y + r.height, s.y + s.height)
            if (right <= left || bottom <= top) continue
            const l = left - (left === s.x ? 2 : 0), t = top - (top === s.y ? 2 : 0)
            const rr = right + (right === s.x + s.width ? 2 : 0), b = bottom + (bottom === s.y + s.height ? 2 : 0)
            covers.push(Qt.rect(l - area.x, t - area.y, rr - l, b - t))
        }
        return covers
    }

    Repeater {
        model: overlay.occluders
        Item {
            required property rect modelData
            x: modelData.x
            y: modelData.y
            width: modelData.width
            height: modelData.height
            clip: true
            Image {
                x: -parent.x
                y: -parent.y
                width: overlay.width
                height: overlay.height
                source: "image://frozen/" + overlay.screenName + "/" + Capture.frozenSerial
                cache: false
                smooth: true
            }
            Rectangle { anchors.fill: parent; color: Theme.dim }
        }
    }

    Rectangle {
        id: sizeLabel
        readonly property real edgeRight: overlay.selection.x + overlay.selection.width - overlay.area.x
        readonly property real edgeBottom: overlay.selection.y + overlay.selection.height - overlay.area.y
        visible: overlay.hasSelection && overlay.active && (overlay.dragging || overlay.armed || Capture.mode !== "rectangle")
        x: Math.min(Math.max(8, edgeRight - width), overlay.width - width - 8)
        y: edgeBottom + height + 12 < overlay.height ? edgeBottom + 8 : Math.max(8, edgeBottom - height - 8)
        width: sizeText.implicitWidth + 16
        height: sizeText.implicitHeight + 8
        radius: Theme.controlRadius
        color: "#cc1c1c1c"
        Text {
            id: sizeText
            anchors.centerIn: parent
            readonly property real ratio: overlay.targetScreen.devicePixelRatio
            text: Math.round(overlay.selection.width * ratio) + " × " + Math.round(overlay.selection.height * ratio)
            color: "#ffffff"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.captionSize
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Capture.mode === "rectangle" || Capture.mode === "freeform" ? Qt.CrossCursor : Qt.ArrowCursor

        function clampToScreen(point) {
            if (!overlay.live) return point
            return Qt.point(Math.max(overlay.area.x, Math.min(point.x, overlay.area.x + overlay.area.width)),
                            Math.max(overlay.area.y, Math.min(point.y, overlay.area.y + overlay.area.height)))
        }

        function hoverTarget(point) {
            if (Capture.mode === "fullscreen") return overlay.area
            if (Capture.mode === "window") {
                for (const rect of Capture.windowRects)
                    if (overlay.rectContains(rect, point)) return rect
            }
            return Qt.rect(0, 0, 0, 0)
        }

        onEntered: Capture.activeScreen = overlay.screenName
        onPositionChanged: mouse => {
            Capture.activeScreen = overlay.screenName
            const point = clampToScreen(overlay.global(mouse.x, mouse.y))
            if (overlay.dragging) {
                if (Capture.mode === "freeform") {
                    const points = overlay.strokePoints
                    const last = points[points.length - 1]
                    if (Math.abs(last.x - point.x) + Math.abs(last.y - point.y) < 2) return
                    points.push(point)
                    overlay.strokePoints = points
                    let minX = point.x, minY = point.y, maxX = point.x, maxY = point.y
                    for (const p of points) {
                        minX = Math.min(minX, p.x); minY = Math.min(minY, p.y)
                        maxX = Math.max(maxX, p.x); maxY = Math.max(maxY, p.y)
                    }
                    Capture.freeformPath = overlay.strokePoints
                    Capture.selection = Qt.rect(minX, minY, maxX - minX, maxY - minY)
                } else {
                    const start = overlay.dragStart
                    Capture.selection = Qt.rect(Math.min(start.x, point.x), Math.min(start.y, point.y),
                                                Math.abs(point.x - start.x), Math.abs(point.y - start.y))
                }
            } else if (!overlay.armed && (Capture.mode === "window" || Capture.mode === "fullscreen")) {
                Capture.selection = hoverTarget(point)
            }
        }
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                Capture.cancel()
                return
            }
            if (Capture.mode !== "rectangle" && Capture.mode !== "freeform") return
            const point = clampToScreen(overlay.global(mouse.x, mouse.y))
            overlay.dragging = true
            overlay.dragStart = point
            overlay.strokePoints = [point]
            Capture.freeformPath = []
            Capture.selection = Qt.rect(point.x, point.y, 0, 0)
        }
        onReleased: mouse => {
            if (!overlay.dragging) return
            overlay.dragging = false
            if (Capture.selection.width >= 3 && Capture.selection.height >= 3) Capture.commit()
            else Capture.selection = Qt.rect(0, 0, 0, 0)
        }
        onClicked: mouse => {
            if (mouse.button !== Qt.LeftButton) return
            if (Capture.mode === "window" || Capture.mode === "fullscreen") {
                Capture.selection = hoverTarget(overlay.global(mouse.x, mouse.y))
                if (Capture.selection.width > 0) Capture.commit()
            }
        }
    }

    CaptureBar {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 16
        visible: overlay.active
        opacity: overlay.dragging ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    RecordControls {
        readonly property rect region: Capture.recordRegion
        readonly property real regionTop: region.y - overlay.area.y
        readonly property real regionBottom: regionTop + region.height
        visible: overlay.armed && !overlay.dragging && overlay.screenName === Capture.screenNameAt(Qt.point(region.x + region.width / 2, region.y + region.height / 2))
        x: Math.max(12, Math.min(region.x - overlay.area.x + (region.width - width) / 2, overlay.width - width - 12))
        y: regionTop - height - 15 >= 12 ? regionTop - height - 15
            : regionBottom + 15 + height <= overlay.height - 12 ? regionBottom + 15 : 72
    }

    Shortcut {
        sequences: [StandardKey.Cancel]
        onActivated: Capture.cancel()
    }
    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: overlay.armed
        onActivated: Capture.startRecording()
    }
}
