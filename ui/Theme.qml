pragma Singleton
import QtQuick
import SnipShot.Core

QtObject {
    readonly property var colors: Appearance.colors
    readonly property bool dark: Appearance.dark
    readonly property bool desktopIcons: Config.desktopIcons

    readonly property color surface: colors.surface
    readonly property color containerLow: colors.surface_container_low
    readonly property color container: colors.surface_container
    readonly property color containerHigh: colors.surface_container_high
    readonly property color containerHighest: colors.surface_container_highest
    readonly property color text: colors.on_surface
    readonly property color textMuted: colors.on_surface_variant
    readonly property color outline: colors.outline
    readonly property color outlineVariant: colors.outline_variant
    readonly property color accent: colors.primary
    readonly property color onAccent: colors.on_primary
    readonly property color record: colors.error

    readonly property color hover: Qt.alpha(text, 0.07)
    readonly property color pressed: Qt.alpha(text, 0.12)
    readonly property color selection: Qt.alpha(accent, dark ? 0.22 : 0.18)
    readonly property color shadow: Qt.alpha(colors.shadow, dark ? 0.5 : 0.18)
    readonly property color dim: "#80000000"

    readonly property int radius: Appearance.radius
    readonly property int radiusSmall: Math.max(2, Math.round(radius * 0.6))
    readonly property int controlRadius: radiusSmall + 2

    readonly property string fontFamily: Qt.application.font.family
    readonly property int textSize: 13
    readonly property int smallSize: 11
    readonly property int titleSize: 18
    readonly property int controlHeight: 32

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
