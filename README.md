# SnipShot

SnipShot is a screenshot, screen recording and text extraction tool for Linux, modelled on the Windows Snipping Tool. It's written in Zig with a Qt Quick interface and currently targets wlroots-style Wayland compositors (Hyprland and sway are the ones I've tested).

## LICENSE

[GPL-3.0-or-later](LICENSE)

## What can it do?

| What? | How? |
| --- | --- |
| Snip | Freezes the screen and lets you pick a rectangle, a window, a whole screen or a freeform shape |
| Record | Records an area with a 3-2-1 countdown, pause, mic and system audio |
| Extract text | Reads the text in an area with Tesseract and puts it on the clipboard |
| Themes | Fluent (light or dark), your Qt platform theme (qt6ct, KDE colours) or a custom JSON theme |

Snips go straight to the clipboard, and a notification opens them in SnipShot.

## Usage

SnipShot keeps one instance running, so commands from a keybind are instant:

```sh
snipshot            # open the SnipShot window
snipshot snip       # take a snip (add --delay 3 or --mode window)
snipshot snip --fullscreen          # every monitor as one image, no overlay
snipshot snip --fullscreen focused  # just the focused monitor
snipshot text       # extract text from an area
snipshot record     # record an area, run it again to stop
snipshot settings
snipshot quit
```

For example, in Hyprland:

```lua
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("snipshot snip"))
hl.bind("Print", hl.dsp.exec_cmd("snipshot snip --fullscreen"))
```

To have it ready at login without opening the window, autostart `snipshot --daemon`.

In the overlay, `Esc` or a right click cancels and `Enter` starts an armed recording.

Screenshots go to `~/Pictures/SnipShot` and recordings to `~/Videos/SnipShot`. You can change both in settings, or set `SNIPSHOT_OUTPUT_DIR` to override everything.

Custom themes are JSON files in `~/.config/SnipShot/themes/`. Any token you leave out comes from the base theme. There's an example in `data/themes/Midnight.json`.

## Prerequisites

- Zig 0.17
- Qt 6.8 or newer with Quick, Quick Controls, QML, Multimedia and D-Bus
- LayerShellQt
- CMake, Ninja and a C++20 compiler
- `grim`, `wl-clipboard`, `tesseract` with at least one language pack, and `ffmpeg`
- `gpu-screen-recorder` (hardware encoding) or `wf-recorder` for recording

## Build

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/snipshot
```

## Install on Arch

```sh
cd packaging
makepkg -si
```

The package is built from your checkout as it is, uncommitted changes included.

## Test

```sh
zig test src/core.zig -lc
```
