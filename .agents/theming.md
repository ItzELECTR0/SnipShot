# Theming

The look is SnipShot's own and shared with GlyphPop: a quiet monochrome surface with one accent, small radii, 1 px outlines and the system font. It must not imitate Windows or Fluent (the Fluent icon set is the one exception), and must not read any particular shell's or bar's config. Every colour, radius and font size in QML comes from `ui/Theme.qml`. The only hardcoded colours are content colours: the dim, the white selection outline and the dark size label on the overlay.

## Settings

`ThemeSource` (`app/themesource.*`, the `Appearance` singleton) owns these `[General]` keys and writes them as soon as the settings window changes them. They are deliberately not in `Settings`, so there is one owner.

- `theme`: `material` (default) or the name of `~/.config/SnipShot/themes/<name>.json`.
- `mode`: `system` (default), `light` or `dark`. System follows the portal's `color-scheme`; no preference means dark.
- `accent`: `default`, `system`, `orange`, `red`, `pink`, `purple`, `blue`, `teal`, `green`, `yellow`, `custom`.
- `customAccent`: `#rrggbb`.

## Material

The built-in theme is Prismora's Material, the same as GlyphPop's: surface and text `#121212`/`#e6e6e6` dark, `#f4f4f4`/`#161616` light, primary white or black. Containers, outlines and muted text are mixes of surface and text (4, 7, 10, 15, 32, 17 and 62 percent), computed by `material()`. SnipShot adds `error` (`#ff6b6b` dark, `#c62828` light), which is the recording red.

`default` accent is the theme's own `primary`; `system` is the portal's `accent-color` and is only offered while the desktop publishes one. `on_primary` is black or white by luminance.

## Theme files

Watched live; the folder is rescanned whenever the settings window opens, because a folder created after startup is not watched yet. `data/themes/Midnight.json` is the shipped example.

```json
{ "base": "dark", "radius": 10, "colors": { "surface": "#101820", "on_surface": "#dfe8f0", "primary": "#8ecfd4" },
  "light": { "surface": "#f0f4f8" } }
```

Everything is optional. `base` fixes the mode and greys out the Mode row. `colors` applies in both modes and a `dark` or `light` object adds per-mode overrides. Containers and lines are re-derived from the file's `surface` and `on_surface` before explicit overrides apply. Token names are Material roles: `surface`, `surface_container_low`, `surface_container`, `surface_container_high`, `surface_container_highest`, `on_surface`, `on_surface_variant`, `outline`, `outline_variant`, `primary`, `on_primary`, `error`, `shadow`. Derived values (`hover`, `pressed`, `selection`) are alpha blends in `Theme.qml`.

## Controls

The Quick Controls style is `Basic`, set once in `main.cpp`, and the platform palette is never touched, so every theme change applies live. Anything from Quick Controls is wrapped in a component that replaces its background, content and indicator from Theme: `Toggle`, `Dropdown`, `Field`, `PopupMenu`/`MenuDivider`, `Tip`, `Scroller`, `SeekSlider`. `Segmented`, `Chip`, `IconButton`, `Spinner` and `ColorPicker` are plain QtQuick. Use these rather than a bare Quick Controls type, which would show Basic's grey look.

`Dropdown` opens as its own popup surface (`Popup.Window`) because the main window is too short to hold the list. `PopupMenu` stays in-window: as a window popup on sway it ignored the requested x offset and anchored at the button's left edge.

Chips expose a checkable button role, not a check box: Qt's default toggle action for a check box writes `checked` directly and breaks the binding.

## Icons

`ui/icons/Icons.js` holds SVG path data from Microsoft's Fluent UI System Icons (MIT, licence beside it), rendered by `FluentIcon` with `QtQuick.Shapes` so they tint without Qt Svg. To add one, download `ic_fluent_<name>_24_<variant>.svg` and append its `d` attributes to `paths` under `<name>_<variant>`. The optional desktop icon theme maps names through `Theme.desktopIconNames` and falls back to the built-in path.
