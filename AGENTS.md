# SnipShot agent guide

SnipShot is a Linux desktop capture prototype. The UI is Qt Quick/QML, the Qt host is a small C++ bridge, and capture workflows live in Zig.

- Keep capture, output paths, and external-tool handling in `src/core.zig`.
- Keep presentation and interaction in `ui/Main.qml`; the Qt host exposes the Zig core through `app/capturebackend.*`.
- Do not add dependencies or claim desktop/backend support beyond what has been exercised.
