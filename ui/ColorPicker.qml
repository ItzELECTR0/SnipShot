import QtQuick

// A saturation/value square, a hue strip and a hex field, all editing `color`.
Item {
    id: root

    property color color: "#8ecfd4"
    signal edited(color value)

    property real hue: Math.max(0, color.hsvHue)
    property real saturation: color.hsvSaturation
    property real value: color.hsvValue

    function commit(h, s, v) {
        hue = h;
        saturation = s;
        value = v;
        root.edited(Qt.hsva(h, s, v, 1));
    }

    // Greys have no hue, so keep the last one rather than jumping the strip to red.
    onColorChanged: {
        if (color.hsvHue >= 0 && color.hsvSaturation > 0.01 && color.hsvValue > 0.01)
            hue = color.hsvHue;
        saturation = color.hsvSaturation;
        value = color.hsvValue;
        if (!hex.activeFocus)
            hex.text = color.toString().substring(1);
    }

    implicitHeight: 120

    Rectangle {
        id: area
        width: parent.width - strip.width - 10 - side.width - 10
        height: parent.height
        radius: Theme.radiusSmall
        color: Qt.hsva(root.hue, 1, 1, 1)
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#ffffffff" }
                GradientStop { position: 1; color: "#00ffffff" }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            gradient: Gradient {
                GradientStop { position: 0; color: "#00000000" }
                GradientStop { position: 1; color: "#ff000000" }
            }
        }
        Rectangle {
            x: root.saturation * area.width - width / 2
            y: (1 - root.value) * area.height - height / 2
            width: 12
            height: 12
            radius: 6
            color: "transparent"
            border.width: 2
            border.color: root.value > 0.5 ? "#202020" : "#ffffff"
        }
        MouseArea {
            anchors.fill: parent
            function set(mouse) {
                root.commit(root.hue, Math.max(0, Math.min(1, mouse.x / width)), Math.max(0, Math.min(1, 1 - mouse.y / height)));
            }
            onPressed: mouse => set(mouse)
            onPositionChanged: mouse => set(mouse)
        }
    }

    Rectangle {
        id: strip
        anchors.left: area.right
        anchors.leftMargin: 10
        width: 14
        height: parent.height
        radius: 7
        gradient: Gradient {
            GradientStop { position: 0 / 6; color: "#ff0000" }
            GradientStop { position: 1 / 6; color: "#ffff00" }
            GradientStop { position: 2 / 6; color: "#00ff00" }
            GradientStop { position: 3 / 6; color: "#00ffff" }
            GradientStop { position: 4 / 6; color: "#0000ff" }
            GradientStop { position: 5 / 6; color: "#ff00ff" }
            GradientStop { position: 6 / 6; color: "#ff0000" }
        }
        Rectangle {
            x: -2
            y: root.hue * strip.height - height / 2
            width: strip.width + 4
            height: 6
            radius: 3
            color: "transparent"
            border.width: 2
            border.color: Theme.text
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            function set(mouse) {
                root.commit(Math.max(0, Math.min(0.999, (mouse.y - 4) / strip.height)), root.saturation, root.value);
            }
            onPressed: mouse => set(mouse)
            onPositionChanged: mouse => set(mouse)
        }
    }

    Column {
        id: side
        anchors.right: parent.right
        width: 92
        spacing: 8

        Rectangle {
            width: parent.width
            height: 40
            radius: Theme.radiusSmall
            color: root.color
            border.width: 1
            border.color: Theme.outlineVariant
        }

        Rectangle {
            width: parent.width
            height: 30
            radius: Theme.radiusSmall + 2
            color: Theme.containerLow
            border.width: 1
            border.color: hex.activeFocus ? Theme.accent : Theme.outlineVariant

            Text {
                id: hash
                x: 9
                anchors.verticalCenter: parent.verticalCenter
                text: "#"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSize
            }

            TextInput {
                id: hex
                anchors.left: hash.right
                anchors.leftMargin: 2
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.color.toString().substring(1)
                maximumLength: 6
                validator: RegularExpressionValidator { regularExpression: /[0-9a-fA-F]{0,6}/ }
                color: Theme.text
                selectionColor: Theme.selection
                selectedTextColor: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSize
                selectByMouse: true
                onTextEdited: {
                    if (text.length === 6) {
                        const c = Qt.color("#" + text);
                        root.hue = Math.max(0, c.hsvHue);
                        root.edited(c);
                    }
                }
                Keys.onEscapePressed: event => { focus = false; event.accepted = false; }
            }
        }
    }
}
