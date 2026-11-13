import QtQuick
import QtQuick.Controls.Basic

ScrollBar {
    id: bar
    padding: 2
    contentItem: Rectangle {
        implicitWidth: bar.hovered || bar.pressed ? 6 : 4
        implicitHeight: bar.hovered || bar.pressed ? 6 : 4
        radius: 3
        color: bar.pressed ? Theme.textMuted : Theme.outline
        opacity: bar.policy === ScrollBar.AlwaysOn || (bar.active && bar.size < 1) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
    background: Item {}
}
