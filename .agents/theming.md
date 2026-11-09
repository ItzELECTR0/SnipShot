# Theming

Every colour, radius and font in custom-drawn UI comes from the `Theme` singleton (`ui/Theme.qml`). Do not hardcode colours elsewhere except deliberate content colours (the dim, the white selection outline).

## Sources

- `fluent` (default): Windows 11 tokens for light and dark, Segoe UI Variable when installed. Quick Controls style `FluentWinUI3`.
- `desktop`: tokens derived from `SystemPalette`, font from `Qt.application.font`. Quick Controls style `Fusion`, which also follows the palette.
- `custom`: JSON from `~/.config/SnipShot/themes/<name>.json`. `base` picks fluent or desktop; any token name in `Theme.qml` (`window`, `accent`, `radius`, `fontFamily`, `dark`...) overrides that base.

The Quick Controls style is fixed per process, so switching between a fluent-based and a desktop-based source asks for a restart. Colours switch live.

## Why Fluent mode replaces the platform theme

FluentWinUI3 picks its light or dark images from `Application.styleHints.colorScheme` and treats `Unknown` as dark. Measured on this machine:

| Platform theme | Reports | `setColorScheme` works? |
| --- | --- | --- |
| qt6ct | Unknown | no |
| xdgdesktopportal | system value | no |
| gtk3 | GTK's guess | yes |

So in Fluent mode `main.cpp` sets `QT_QPA_PLATFORMTHEME=gtk3` (or `xdgdesktopportal` if the gtk3 plugin is missing) before `QGuiApplication` exists, overrides the palette with Fluent colours and forces the scheme. The system preference is read from the portal (`org.freedesktop.appearance color-scheme`) and followed live through `SettingChanged`. The user's original platform theme is kept in `SNIPSHOT_USER_PLATFORMTHEME` so a restart into Desktop mode gets qt6ct back.

In Desktop mode, never call `QGuiApplication::setPalette` at startup: qt6ct applies its palette after construction, and an early explicit palette blocks it.

Text fields and combo boxes use `FluentField`/`FluentCombo`, which draw their own backgrounds from Theme tokens so they read correctly under every source.

## Icons

`ui/icons/Icons.js` holds SVG path data from Microsoft's Fluent UI System Icons (MIT, licence beside it), rendered by `FluentIcon` with `QtQuick.Shapes` so they tint without Qt Svg. To add one, download `ic_fluent_<name>_24_<variant>.svg` and append its `d` attributes to `paths` under `<name>_<variant>`. The optional desktop icon theme maps names through `Theme.desktopIconNames` and falls back to the Fluent path.
