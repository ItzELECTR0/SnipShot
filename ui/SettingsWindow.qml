import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SnipShot.Core

Window {
    id: window
    property string launchedStyle
    property string pendingStyle

    visible: Capture.settingsOpen
    title: "SnipShot Settings"
    width: 680
    height: 760
    minimumWidth: 520
    minimumHeight: 420
    color: Theme.window
    onVisibleChanged: if (visible) {
        ThemeFiles.refresh()
        Capture.floatWindow(title, 680, 760)
    }
    onClosing: Capture.closeSettings()
    Component.onCompleted: {
        launchedStyle = styleFor(Config.themeSource, Config.customTheme)
        pendingStyle = launchedStyle
    }

    function styleFor(source, custom) {
        if (source === "desktop") return "Fusion"
        if (source === "custom" && ThemeFiles.loadTheme(custom).base === "desktop") return "Fusion"
        return "FluentWinUI3"
    }
    function updatePendingStyle() { pendingStyle = styleFor(Config.themeSource, Config.customTheme) }

    component Heading: Text {
        Layout.topMargin: 18
        Layout.bottomMargin: 2
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Font.DemiBold
    }

    component Card: Rectangle {
        id: card
        property string title
        property string description
        property string icon
        default property alias control: slot.data
        Layout.fillWidth: true
        implicitHeight: Math.max(64, layout.implicitHeight + 24)
        radius: Theme.radius
        color: Theme.surface
        border.color: Theme.stroke

        RowLayout {
            id: layout
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 14
            FluentIcon {
                visible: card.icon.length > 0
                name: card.icon
                size: 20
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: card.title
                    color: Theme.text
                    wrapMode: Text.Wrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                Text {
                    Layout.fillWidth: true
                    visible: card.description.length > 0
                    text: card.description
                    color: Theme.textSecondary
                    wrapMode: Text.Wrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.captionSize
                }
            }
            Row {
                id: slot
                spacing: 8
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            }
        }
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth - 48
            x: 24
            spacing: 4

            Text {
                Layout.topMargin: 20
                text: qsTr("Settings")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleSize + 4
                font.weight: Font.DemiBold
            }

            Heading { text: qsTr("Snipping") }
            Card {
                icon: "copy_regular"
                title: qsTr("Automatically copy to clipboard")
                description: qsTr("Every snip lands on the clipboard, ready to paste.")
                Switch { checked: Config.autoCopy; onToggled: Config.autoCopy = checked }
            }
            Card {
                icon: "save_regular"
                title: qsTr("Automatically save screenshots")
                description: Config.autoSave ? qsTr("Snips are saved to the screenshots folder.") : qsTr("Snips stay temporary until you save them.")
                Switch { checked: Config.autoSave; onToggled: Config.autoSave = checked }
            }
            Card {
                icon: "folder_open_regular"
                title: qsTr("Screenshots folder")
                description: qsTr("Leave empty for ~/Pictures/SnipShot.")
                FluentField {
                    width: 240
                    text: Config.screenshotFolder
                    placeholderText: "~/Pictures/SnipShot"
                    onEditingFinished: Config.screenshotFolder = text.trim()
                }
            }
            Card {
                icon: "image_regular"
                title: qsTr("Add border to each screenshot")
                Row {
                    spacing: 8
                    FluentField {
                        width: 92
                        enabled: Config.border
                        text: Config.borderColor
                        validator: RegularExpressionValidator { regularExpression: /#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?/ }
                        onEditingFinished: Config.borderColor = text
                        Accessible.name: qsTr("Border colour")
                    }
                    FluentCombo {
                        width: 96
                        enabled: Config.border
                        model: [1, 2, 3, 4, 6, 8, 12].map(size => ({ value: size, label: size + " px" }))
                        current: Config.borderWidth
                        onActivated: Config.borderWidth = currentValue
                        Accessible.name: qsTr("Border width")
                    }
                    Switch { checked: Config.border; onToggled: Config.border = checked; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Card {
                icon: "timer_regular"
                title: qsTr("Default delay")
                FluentCombo {
                    width: 150
                    model: [0, 3, 5, 10].map(seconds => ({ value: seconds, label: seconds === 0 ? qsTr("No delay") : qsTr("%1 seconds").arg(seconds) }))
                    current: Config.delay
                    onActivated: Config.delay = currentValue
                }
            }

            Heading { text: qsTr("Screen recording") }
            Card {
                icon: "video_regular"
                title: qsTr("Recorder")
                description: qsTr("Automatic prefers gpu-screen-recorder for hardware encoding and falls back to wf-recorder.")
                FluentCombo {
                    width: 210
                    model: Capture.recorderBackends.map(backend => ({ value: backend.value, label: backend.available ? backend.name : qsTr("%1 (not installed)").arg(backend.name) }))
                    current: Config.recorderBackend
                    onActivated: Config.recorderBackend = currentValue
                }
            }
            Card {
                icon: "play_filled"
                title: qsTr("Frame rate")
                FluentCombo {
                    width: 140
                    model: [30, 60].map(rate => ({ value: rate, label: rate + " fps" }))
                    current: Config.framerate
                    onActivated: Config.framerate = currentValue
                }
            }
            Card {
                icon: "mic_regular"
                title: qsTr("Record microphone")
                description: qsTr("You can also toggle this on the recording bar.")
                Switch { checked: Config.microphone; onToggled: Capture.microphone = checked }
            }
            Card {
                icon: "speaker_2_regular"
                title: qsTr("Record system audio")
                Switch { checked: Config.systemAudio; onToggled: Capture.systemAudio = checked }
            }
            Card {
                icon: "folder_open_regular"
                title: qsTr("Recordings folder")
                description: qsTr("Leave empty for ~/Videos/SnipShot.")
                FluentField {
                    width: 240
                    text: Config.recordingFolder
                    placeholderText: "~/Videos/SnipShot"
                    onEditingFinished: Config.recordingFolder = text.trim()
                }
            }

            Heading { text: qsTr("Text extractor") }
            Card {
                icon: "scan_text_regular"
                title: qsTr("Recognition languages")
                description: Capture.ocrLanguages.length > 0
                    ? qsTr("Pick every language you expect. More languages are slower.")
                    : qsTr("Install tesseract and a language pack, such as tesseract-data-eng.")
                Flow {
                    width: 260
                    spacing: 4
                    Repeater {
                        model: Capture.ocrLanguages
                        CheckBox {
                            required property string modelData
                            text: modelData
                            checked: Config.ocrLanguages.split("+").indexOf(modelData) !== -1
                            onToggled: {
                                const selected = Config.ocrLanguages.split("+").filter(language => language.length > 0 && language !== modelData)
                                if (checked) selected.push(modelData)
                                Config.ocrLanguages = selected.join("+")
                            }
                        }
                    }
                }
            }

            Heading { text: qsTr("Notifications") }
            Card {
                icon: "checkmark_regular"
                title: qsTr("Show a notification after each snip")
                description: qsTr("Select it to open the snip. Snips started from the SnipShot window open directly.")
                Switch { checked: Config.notifications; onToggled: Config.notifications = checked }
            }

            Heading { text: qsTr("Appearance") }
            Card {
                icon: "paint_brush_regular"
                title: qsTr("Theme")
                description: qsTr("Desktop follows your Qt platform theme, such as qt6ct or KDE colours, and its font.")
                FluentCombo {
                    width: 200
                    model: [
                        { value: "fluent", label: qsTr("Fluent") },
                        { value: "desktop", label: qsTr("Desktop (qt6ct)") },
                        { value: "custom", label: qsTr("Custom file") }
                    ]
                    current: Config.themeSource
                    onActivated: {
                        Config.themeSource = currentValue
                        window.updatePendingStyle()
                    }
                }
            }
            Card {
                visible: Config.themeSource === "fluent"
                icon: "desktop_regular"
                title: qsTr("Colour mode")
                FluentCombo {
                    width: 200
                    model: [
                        { value: "system", label: qsTr("Use system setting") },
                        { value: "light", label: qsTr("Light") },
                        { value: "dark", label: qsTr("Dark") }
                    ]
                    current: Config.colorScheme
                    onActivated: Config.colorScheme = currentValue
                }
            }
            Card {
                visible: Config.themeSource === "custom"
                icon: "document_text_regular"
                title: qsTr("Custom theme")
                description: ThemeFiles.customThemes.length > 0
                    ? qsTr("JSON files in %1.").arg(ThemeFiles.themesFolder)
                    : qsTr("Add a JSON theme file to %1.").arg(ThemeFiles.themesFolder)
                Row {
                    spacing: 8
                    FluentCombo {
                        width: 180
                        model: ThemeFiles.customThemes.map(name => ({ value: name, label: name }))
                        current: Config.customTheme
                        onActivated: {
                            Config.customTheme = currentValue
                            window.updatePendingStyle()
                        }
                        Component.onCompleted: if (Config.customTheme.length === 0 && count > 0) Config.customTheme = valueAt(0)
                    }
                    IconButton {
                        variant: "standard"
                        icon: "folder_open_regular"
                        tooltip: qsTr("Open themes folder")
                        onClicked: ThemeFiles.openThemesFolder()
                    }
                }
            }
            Card {
                icon: "image_regular"
                title: qsTr("Use desktop icon theme")
                description: qsTr("Falls back to Fluent icons where your icon theme has no match.")
                Switch { checked: Config.desktopIcons; onToggled: Config.desktopIcons = checked }
            }
            Card {
                visible: window.pendingStyle !== window.launchedStyle
                icon: "settings_regular"
                title: qsTr("Restart to finish applying the theme")
                description: qsTr("Buttons, lists and switches pick up the new style after a restart.")
                IconButton {
                    variant: "accent"
                    text: qsTr("Restart")
                    onClicked: Capture.restart()
                }
            }

            Heading { text: qsTr("About") }
            Card {
                icon: "camera_regular"
                title: "SnipShot"
                description: qsTr("Bind keys to \"snipshot snip\", \"snipshot record\" and \"snipshot text\" in your desktop settings to start captures from anywhere.")
            }
            Item { Layout.preferredHeight: 24 }
        }
    }
}
