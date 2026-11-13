import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import SnipShot.Core

Window {
    id: window

    visible: Capture.settingsOpen
    title: "SnipShot Settings"
    width: 680
    height: 760
    minimumWidth: 520
    minimumHeight: 420
    color: Theme.surface
    onVisibleChanged: if (visible) {
        Appearance.rescan()
        Capture.floatWindow(title, 680, 760)
    }
    onClosing: Capture.closeSettings()

    component Heading: Text {
        Layout.topMargin: 20
        Layout.bottomMargin: 6
        Layout.leftMargin: 4
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.6
    }

    component Group: Rectangle {
        default property alias rows: column.data
        Layout.fillWidth: true
        implicitHeight: column.implicitHeight
        radius: Theme.radius
        color: Theme.containerLow
        border.width: 1
        border.color: Theme.outlineVariant
        Column {
            id: column
            width: parent.width
        }
    }

    // One row of a group; `below` puts the control under the text instead of beside it.
    component Setting: Item {
        id: setting
        property string title
        property string description
        property string icon
        property bool divider: true
        property bool below: false
        default property alias control: slot.data
        width: parent ? parent.width : 0
        implicitHeight: Math.max(56, body.implicitHeight + 24)

        Rectangle {
            visible: setting.divider
            x: 14
            width: parent.width - 28
            height: 1
            color: Theme.outlineVariant
        }

        GridLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            anchors.verticalCenter: parent.verticalCenter
            columns: setting.below ? 2 : 3
            columnSpacing: 12
            rowSpacing: 10

            FluentIcon {
                Layout.alignment: Qt.AlignVCenter
                name: setting.icon
                size: 18
                color: Theme.textMuted
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: setting.title
                    color: Theme.text
                    wrapMode: Text.Wrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSize
                }
                Text {
                    Layout.fillWidth: true
                    visible: setting.description.length > 0
                    text: setting.description
                    color: Theme.textMuted
                    wrapMode: Text.Wrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallSize + 1
                }
            }
            Item { visible: setting.below; Layout.preferredWidth: 18 }
            Item {
                id: slot
                Layout.fillWidth: setting.below
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                implicitWidth: setting.below ? 0 : childrenRect.width
                implicitHeight: childrenRect.height
            }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: content.implicitHeight + 48
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: Scroller {}

        ColumnLayout {
            id: content
            x: 24
            y: 20
            width: flick.width - 48
            spacing: 0

            Text {
                text: qsTr("Settings")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleSize
                font.weight: Font.DemiBold
            }

            Heading { text: qsTr("Snipping") }
            Group {
                Setting {
                    divider: false
                    icon: "copy_regular"
                    title: qsTr("Copy to clipboard")
                    description: qsTr("Every snip lands on the clipboard, ready to paste.")
                    Toggle { checked: Config.autoCopy; onToggled: Config.autoCopy = checked }
                }
                Setting {
                    icon: "save_regular"
                    title: qsTr("Save automatically")
                    description: Config.autoSave ? qsTr("Snips are saved to the screenshots folder.") : qsTr("Snips stay temporary until you save them.")
                    Toggle { checked: Config.autoSave; onToggled: Config.autoSave = checked }
                }
                Setting {
                    icon: "folder_open_regular"
                    title: qsTr("Screenshots folder")
                    description: qsTr("Leave empty for ~/Pictures/SnipShot.")
                    Field {
                        width: 240
                        text: Config.screenshotFolder
                        placeholderText: "~/Pictures/SnipShot"
                        onEditingFinished: Config.screenshotFolder = text.trim()
                    }
                }
                Setting {
                    icon: "image_regular"
                    title: qsTr("Border")
                    description: qsTr("Draw a line around each snip.")
                    Row {
                        spacing: 8
                        Field {
                            width: 104
                            leftPadding: 30
                            enabled: Config.border
                            text: Config.borderColor
                            validator: RegularExpressionValidator { regularExpression: /#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?/ }
                            onEditingFinished: Config.borderColor = text
                            Accessible.name: qsTr("Border colour")
                            Rectangle {
                                x: 9
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                radius: 3
                                color: Config.borderColor
                                border.width: 1
                                border.color: Theme.outline
                            }
                        }
                        Dropdown {
                            width: 88
                            enabled: Config.border
                            model: [1, 2, 3, 4, 6, 8, 12].map(size => ({ value: size, label: size + " px" }))
                            current: Config.borderWidth
                            onActivated: Config.borderWidth = currentValue
                            Accessible.name: qsTr("Border width")
                        }
                        Toggle {
                            anchors.verticalCenter: parent.verticalCenter
                            checked: Config.border
                            onToggled: Config.border = checked
                        }
                    }
                }
                Setting {
                    icon: "timer_regular"
                    title: qsTr("Default delay")
                    Dropdown {
                        width: 140
                        model: [0, 3, 5, 10].map(seconds => ({ value: seconds, label: seconds === 0 ? qsTr("No delay") : qsTr("%1 seconds").arg(seconds) }))
                        current: Config.delay
                        onActivated: Config.delay = currentValue
                    }
                }
            }

            Heading { text: qsTr("Screen recording") }
            Group {
                Setting {
                    divider: false
                    icon: "video_regular"
                    title: qsTr("Recorder")
                    description: qsTr("Automatic prefers gpu-screen-recorder for hardware encoding and falls back to wf-recorder.")
                    Dropdown {
                        width: 210
                        model: Capture.recorderBackends.map(backend => ({ value: backend.value, label: backend.available ? backend.name : qsTr("%1 (not installed)").arg(backend.name) }))
                        current: Config.recorderBackend
                        onActivated: Config.recorderBackend = currentValue
                    }
                }
                Setting {
                    icon: "play_filled"
                    title: qsTr("Frame rate")
                    Segmented {
                        options: [30, 60].map(rate => ({ value: rate, label: rate + " fps" }))
                        current: Config.framerate
                        onPicked: value => Config.framerate = value
                    }
                }
                Setting {
                    icon: "mic_regular"
                    title: qsTr("Record microphone")
                    description: qsTr("You can also toggle this on the recording bar.")
                    Toggle { checked: Config.microphone; onToggled: Capture.microphone = checked }
                }
                Setting {
                    icon: "speaker_2_regular"
                    title: qsTr("Record system audio")
                    Toggle { checked: Config.systemAudio; onToggled: Capture.systemAudio = checked }
                }
                Setting {
                    icon: "folder_open_regular"
                    title: qsTr("Recordings folder")
                    description: qsTr("Leave empty for ~/Videos/SnipShot.")
                    Field {
                        width: 240
                        text: Config.recordingFolder
                        placeholderText: "~/Videos/SnipShot"
                        onEditingFinished: Config.recordingFolder = text.trim()
                    }
                }
            }

            Heading { text: qsTr("Text extractor") }
            Group {
                Setting {
                    divider: false
                    below: Capture.ocrLanguages.length > 0
                    icon: "scan_text_regular"
                    title: qsTr("Recognition languages")
                    description: Capture.ocrLanguages.length > 0
                        ? qsTr("Pick every language you expect. More languages are slower.")
                        : qsTr("Install tesseract and a language pack, such as tesseract-data-eng.")
                    Flow {
                        width: parent.width
                        spacing: 6
                        Repeater {
                            model: Capture.ocrLanguages
                            Chip {
                                required property string modelData
                                text: modelData
                                checked: Config.ocrLanguages.split("+").indexOf(modelData) !== -1
                                onClicked: {
                                    const selected = Config.ocrLanguages.split("+").filter(language => language.length > 0 && language !== modelData)
                                    if (!checked) selected.push(modelData)
                                    Config.ocrLanguages = selected.join("+")
                                }
                            }
                        }
                    }
                }
            }

            Heading { text: qsTr("Notifications") }
            Group {
                Setting {
                    divider: false
                    icon: "checkmark_regular"
                    title: qsTr("Notify after each snip")
                    description: qsTr("Select it to open the snip. Snips started from the SnipShot window open directly.")
                    Toggle { checked: Config.notifications; onToggled: Config.notifications = checked }
                }
            }

            Heading { text: qsTr("Appearance") }
            Group {
                Setting {
                    divider: false
                    below: true
                    icon: "document_text_regular"
                    title: qsTr("Theme")
                    description: qsTr("Material, or a JSON theme file from %1.").arg(Appearance.themesFolder)
                    Flow {
                        width: parent.width
                        spacing: 6
                        Repeater {
                            model: Appearance.themes
                            Chip {
                                required property string modelData
                                text: modelData === "material" ? qsTr("Material") : modelData
                                checked: Appearance.theme === modelData
                                onClicked: Appearance.theme = modelData
                            }
                        }
                        IconButton {
                            implicitHeight: 30
                            icon: "folder_open_regular"
                            tooltip: qsTr("Open themes folder")
                            onClicked: Appearance.openThemesFolder()
                        }
                    }
                }
                Setting {
                    icon: "desktop_regular"
                    title: qsTr("Mode")
                    description: Appearance.modeFixed ? qsTr("Set by the theme file.") : ""
                    Segmented {
                        enabled: !Appearance.modeFixed
                        options: [
                            { value: "system", label: qsTr("System") },
                            { value: "light", label: qsTr("Light") },
                            { value: "dark", label: qsTr("Dark") }
                        ]
                        current: Appearance.mode
                        onPicked: value => Appearance.mode = value
                    }
                }
                Setting {
                    below: true
                    icon: "paint_brush_regular"
                    title: qsTr("Accent")
                    description: {
                        const list = Appearance.accents
                        for (let index = 0; index < list.length; ++index)
                            if (list[index].id === Appearance.accent) return list[index].label
                        return ""
                    }
                    Column {
                        width: parent.width
                        spacing: 10
                        Flow {
                            width: parent.width
                            spacing: 3
                            Repeater {
                                model: Appearance.accents
                                Item {
                                    id: swatch
                                    required property var modelData
                                    readonly property bool chosen: Appearance.accent === modelData.id
                                    width: 26
                                    height: 26
                                    Accessible.role: Accessible.RadioButton
                                    Accessible.name: modelData.label
                                    Accessible.checked: chosen

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 13
                                        color: "transparent"
                                        border.width: 2
                                        border.color: swatch.chosen ? Theme.text : swatchMouse.containsMouse ? Theme.outline : "transparent"
                                    }
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: swatch.modelData.color
                                        border.width: 1
                                        border.color: Qt.alpha(Theme.text, 0.25)
                                    }
                                    // Custom shows a hue ring around its colour so it reads as "pick your own".
                                    Rectangle {
                                        visible: swatch.modelData.id === "custom"
                                        anchors.centerIn: parent
                                        width: 18
                                        height: 18
                                        radius: 9
                                        rotation: 45
                                        gradient: Gradient {
                                            GradientStop { position: 0; color: "#ff5f5f" }
                                            GradientStop { position: 0.35; color: "#ffd54f" }
                                            GradientStop { position: 0.65; color: "#4dd0c4" }
                                            GradientStop { position: 1; color: "#b39ddb" }
                                        }
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 10
                                            height: 10
                                            radius: 5
                                            color: swatch.modelData.color
                                        }
                                    }
                                    MouseArea {
                                        id: swatchMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: Appearance.accent = swatch.modelData.id
                                    }
                                    Tip {
                                        visible: swatchMouse.containsMouse
                                        text: swatch.modelData.label
                                    }
                                }
                            }
                        }
                        ColorPicker {
                            visible: Appearance.accent === "custom"
                            width: Math.min(parent.width, 360)
                            height: visible ? implicitHeight : 0
                            color: Appearance.customAccent
                            onEdited: value => Appearance.customAccent = value
                        }
                    }
                }
                Setting {
                    icon: "image_regular"
                    title: qsTr("Use desktop icon theme")
                    description: qsTr("Falls back to the built-in icons where your icon theme has no match.")
                    Toggle { checked: Config.desktopIcons; onToggled: Config.desktopIcons = checked }
                }
            }

            Heading { text: qsTr("About") }
            Group {
                Setting {
                    divider: false
                    icon: "camera_regular"
                    title: "SnipShot"
                    description: qsTr("Bind keys to \"snipshot snip\", \"snipshot snip --fullscreen\", \"snipshot record\" and \"snipshot text\" in your desktop settings to start captures from anywhere.")
                }
            }
        }
    }
}
