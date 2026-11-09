# SnipShot agent guide

SnipShot is a Linux capture tool modelled on the Windows Snipping Tool. The UI is Qt Quick/QML, the Qt host is a C++ bridge, and external-tool handling lives in Zig.

- Keep capture, output paths, clipboard, recorder and other external-tool handling in `src/core.zig`.
- Keep presentation and interaction in `ui/`. The C++ host in `app/` owns state, settings, pixel work and windows.
- Do not add dependencies or claim desktop/backend support beyond what has been exercised. Hyprland and sway are the exercised desktops.
- Build with CMake (see README); unit tests are `zig test src/core.zig -lc`.

## Topics

- `.agents/architecture.md`: read before changing the process model, state machine, windows or the Zig/C++/QML split.
- `.agents/capture-backends.md`: read before touching freeze, window lists, recorders, clipboard or OCR.
- `.agents/theming.md`: read before changing colours, styles, palettes, icons or the Theme singleton.
- `.agents/testing.md`: read before running the app, especially anything that captures a screen.
