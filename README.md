# SnipShot

I'm building SnipShot as a Linux capture tool in Zig, with a Qt Quick interface. It uses `slurp` to select a region, `grim` for screenshots, `wf-recorder` for video, and Tesseract for text recognition.

## Requirements

- Zig 0.18
- Qt 6.5 or newer with Quick, QML, Multimedia, and D-Bus
- LayerShellQt
- CMake and a C++20 compiler
- `slurp`, `grim`, `wf-recorder`, `ffmpeg`, and `tesseract`

## Build and run

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/snipshot
```

Screenshots and recognized-text captures go to `~/Pictures/SnipShot`; recordings go to `~/Videos/SnipShot`. Set `SNIPSHOT_OUTPUT_DIR` to save both in another directory.

The first prototype targets wlroots-style Wayland sessions such as Hyprland and Sway. The blocking toolbar and recording frame use LayerShellQt. The preview is a normal Qt dialog; SnipShot asks Hyprland to float and center it, while other desktops choose their own placement. SnipShot uses desktop notifications and the desktop file chooser through D-Bus portals. Recordings must fit on one screen. Pausing records separate segments and joins them into one video when you stop. Other desktop portals and X11 capture backends are not wired up yet.
