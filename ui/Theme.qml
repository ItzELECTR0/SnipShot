pragma Singleton
import QtQuick
import SnipShot.Core

QtObject {
    id: theme

    readonly property string source: Config.themeSource
    readonly property var custom: source === "custom" ? ThemeFiles.loadTheme(Config.customTheme) : ({})
    readonly property string base: source === "custom" ? (custom.base === "desktop" ? "desktop" : "fluent") : source
    readonly property bool desktopIcons: Config.desktopIcons

    property SystemPalette palette: SystemPalette { colorGroup: SystemPalette.Active }
    property SystemPalette disabledPalette: SystemPalette { colorGroup: SystemPalette.Disabled }

    readonly property bool systemDark: Application.styleHints.colorScheme === Qt.ColorScheme.Dark
    readonly property bool dark: {
        if (custom.dark !== undefined) return custom.dark
        if (base === "desktop") return luminance(palette.window) < 0.5
        if (Config.colorScheme === "dark") return true
        if (Config.colorScheme === "light") return false
        return systemDark
    }

    function luminance(color) { return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b }
    function pick(name, fluentDark, fluentLight, desktop) {
        if (custom[name] !== undefined) return custom[name]
        if (base === "desktop") return desktop
        return dark ? fluentDark : fluentLight
    }
    function alpha(color, opacity) { return Qt.rgba(color.r, color.g, color.b, opacity) }

    readonly property color window: pick("window", "#202020", "#f3f3f3", palette.window)
    readonly property color surface: pick("surface", "#2c2c2c", "#f9f9f9", palette.base)
    readonly property color flyout: pick("flyout", "#2c2c2c", "#fcfcfc", palette.window)
    readonly property color control: pick("control", "#0fffffff", "#b3ffffff", alpha(palette.button, 0.9))
    readonly property color controlHover: pick("controlHover", "#15ffffff", "#80f9f9f9", Qt.lighter(palette.button, dark ? 1.25 : 1.05))
    readonly property color controlPressed: pick("controlPressed", "#08ffffff", "#4df9f9f9", Qt.darker(palette.button, 1.1))
    readonly property color subtleHover: pick("subtleHover", "#0fffffff", "#0a000000", alpha(palette.windowText, 0.08))
    readonly property color subtlePressed: pick("subtlePressed", "#0affffff", "#06000000", alpha(palette.windowText, 0.05))
    readonly property color selected: pick("selected", "#14ffffff", "#0f000000", alpha(palette.highlight, 0.22))
    readonly property color stroke: pick("stroke", "#17ffffff", "#0f000000", alpha(palette.windowText, 0.14))
    readonly property color strokeStrong: pick("strokeStrong", "#33000000", "#29000000", alpha(palette.shadow, 0.5))
    readonly property color text: pick("text", "#ffffff", "#e4000000", palette.windowText)
    readonly property color textSecondary: pick("textSecondary", "#c5ffffff", "#9e000000", alpha(palette.windowText, 0.7))
    readonly property color textDisabled: pick("textDisabled", "#5dffffff", "#5c000000", disabledPalette.windowText)
    readonly property color accent: pick("accent", "#60cdff", "#005fb8", palette.highlight)
    readonly property color accentHover: pick("accentHover", "#e660cdff", "#e6005fb8", Qt.lighter(palette.highlight, 1.1))
    readonly property color accentText: pick("accentText", "#000000", "#ffffff", palette.highlightedText)
    readonly property color record: pick("record", "#ff6b6b", "#c42b1c", "#e5484d")
    readonly property color recordFill: pick("recordFill", "#e81123", "#e81123", "#e5484d")
    readonly property color dim: custom.dim !== undefined ? custom.dim : "#80000000"
    readonly property color shadow: dark ? "#66000000" : "#26000000"

    readonly property string fontFamily: {
        if (custom.fontFamily !== undefined) return custom.fontFamily
        if (base === "desktop") return Qt.application.font.family
        const families = Qt.fontFamilies()
        for (const candidate of ["Segoe UI Variable Text", "Segoe UI Variable", "Segoe UI"])
            if (families.indexOf(candidate) !== -1) return candidate
        return Qt.application.font.family
    }
    readonly property int fontSize: custom.fontSize !== undefined ? custom.fontSize : 14
    readonly property int captionSize: fontSize - 2
    readonly property int titleSize: fontSize + 6
    readonly property int radius: custom.radius !== undefined ? custom.radius : (base === "desktop" ? 6 : 8)
    readonly property int controlRadius: custom.controlRadius !== undefined ? custom.controlRadius : 4

    readonly property var desktopIconNames: ({
        "add_regular": "list-add",
        "camera_regular": "camera-photo",
        "checkmark_regular": "object-select",
        "chevron_down_regular": "go-down",
        "copy_regular": "edit-copy",
        "delete_regular": "edit-delete",
        "desktop_regular": "video-display",
        "dismiss_regular": "window-close",
        "document_text_regular": "text-x-generic",
        "folder_open_regular": "folder-open",
        "full_screen_maximize_regular": "view-fullscreen",
        "image_regular": "image-x-generic",
        "lasso_regular": "edit-select-lasso",
        "mic_off_regular": "microphone-sensitivity-muted",
        "mic_regular": "audio-input-microphone",
        "more_horizontal_regular": "view-more-horizontal",
        "paint_brush_regular": "draw-brush",
        "pause_filled": "media-playback-pause",
        "play_filled": "media-playback-start",
        "record_filled": "media-record",
        "rectangle_landscape_regular": "draw-rectangle",
        "save_regular": "document-save-as",
        "scan_text_regular": "insert-text",
        "settings_regular": "configure",
        "speaker_2_regular": "audio-volume-high",
        "speaker_off_regular": "audio-volume-muted",
        "stop_filled": "media-playback-stop",
        "timer_regular": "chronometer",
        "video_regular": "camera-video",
        "window_regular": "window",
        "zoom_fit_regular": "zoom-fit-best"
    })
}
