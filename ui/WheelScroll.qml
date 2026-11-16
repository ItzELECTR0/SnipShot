import QtQuick
import QtQuick.Controls.Basic

// A wheel notch scrolls wheelScrollLines lines of 24 px, with no flick. It sits under the content, so
// controls handle the wheel first, and touchpad scrolls pass through to the Flickable's own scrolling.
MouseArea {
    id: area

    required property Flickable view
    readonly property real notch: Qt.styleHints.wheelScrollLines * 24

    function clamp(value, low, high) {
        return Math.max(low, Math.min(Math.max(low, high), value))
    }

    parent: view.contentItem
    x: view.originX - view.leftMargin
    y: view.originY - view.topMargin
    z: -1
    width: Math.max(view.width, view.contentWidth + view.leftMargin + view.rightMargin)
    height: Math.max(view.height, view.contentHeight + view.topMargin + view.bottomMargin)
    enabled: view.interactive
    acceptedButtons: Qt.NoButton
    scrollGestureEnabled: false

    onWheel: wheel => {
        const v = view
        const tall = v.contentHeight + v.topMargin + v.bottomMargin > v.height
        const wide = v.contentWidth + v.leftMargin + v.rightMargin > v.width
        let dx = wheel.angleDelta.x
        let dy = wheel.angleDelta.y
        if (!tall && dx === 0) {
            dx = dy
            dy = 0
        }
        if (tall && dy !== 0)
            v.contentY = clamp(v.contentY - dy / 120 * notch, v.originY - v.topMargin, v.originY + v.contentHeight + v.bottomMargin - v.height)
        if (wide && dx !== 0)
            v.contentX = clamp(v.contentX - dx / 120 * notch, v.originX - v.leftMargin, v.originX + v.contentWidth + v.rightMargin - v.width)
        for (const bar of [v.ScrollBar.vertical, v.ScrollBar.horizontal])
            if (bar)
                bar.active = true
        settle.restart()
    }

    // Scroll bars only show while the view is moving, and setting contentY does not count.
    Timer {
        id: settle
        interval: 600
        onTriggered: {
            for (const bar of [area.view.ScrollBar.vertical, area.view.ScrollBar.horizontal])
                if (bar && !bar.hovered && !bar.pressed && !area.view.moving)
                    bar.active = false
        }
    }
}
