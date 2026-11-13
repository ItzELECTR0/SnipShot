# Capture backends

Everything here lives in `src/core.zig`. In Window mode the overlay keeps windows stacked above the hovered one dimmed, but the saved snip keeps the on-screen pixels of the window's rect (owner's decision until true window capture exists). Children are spawned with `fork`/`execvp`; all pipes are `O_CLOEXEC` because freeze runs one grim per output concurrently and an inherited write end would stall another call's EOF.

## Freeze

`grim -t ppm -o <output>` per output into `$XDG_RUNTIME_DIR/snipshot/`. PPM because it is raw and QImage reads it without a plugin; the host deletes the file after loading. grim applies output transforms, so a rotated monitor's image already matches its logical orientation. Images are physical pixels; the host maps logical selections by `image.width / screen.width`. Verified at scale 1.5: a 390x73 logical selection produced a 585x110 PNG.

`QScreen::name()` must match grim's output names (xdg-output). Verified on sway and on live Hyprland, including a selection spanning a rotated output at negative coordinates.

## Window rects

`snipshot_windows` returns `x y w h` lines, topmost first, in global logical coordinates.

- Hyprland: `hyprctl -j clients` (verified live: rects match client sizes 1:1) filtered to mapped, not hidden, on a monitor's active or special workspace. Order: fullscreen, pinned, floating, tiled, then `focusHistoryID`.
- sway: `swaymsg -t get_tree` views with `visible: true`, floating before tiled, focused first. `rect` includes decorations.
- Anything else returns `unsupported` and the Window mode button hides.

## Focused output

`snipshot snip --fullscreen focused` asks the compositor which output has focus (`snipshot_focused_output`): the `focused` field of `hyprctl -j monitors` or `swaymsg -t get_outputs`. Both verified (Hyprland live, sway headless). Plain `--fullscreen` composes every output and skips the overlay.

## Recording

Backends are tried in order for `auto`: gpu-screen-recorder, then wf-recorder. Encoders need even sizes, so the region is rounded down. Output is always `.mp4`. Startup is confirmed by polling for up to 1.5 s: if the process exits, the last line of `recorder.log` becomes the error and `auto` falls through to the next backend.

- gpu-screen-recorder: `-w region -region WxH+X+Y` (logical coordinates, same as slurp), `-c mp4 -ac aac`. Pause is native (`SIGUSR2`), stop is `SIGINT`. Mic and system audio merge into one track with `default_output|default_input`. Verified live on Hyprland with NVIDIA: region coordinates, H.264 with AAC, pause. Region capture uses KMS through `gsr-kms-server` (`cap_sys_admin`), which reads the real GPU planes. **Never run it inside a headless test session**: it records the user's live screen, not the session.
- wf-recorder: one segment per pause cycle (`<final>.part-NNN.mkv`), joined with ffmpeg concat on stop. It takes one audio device, so when both mic and system audio are wanted, system audio goes through wf-recorder and the mic through a parallel `ffmpeg -f pulse` capture per segment, mixed with `amix` at the end. Segments are kept if joining fails.

## Clipboard

`wl-copy` (data-control, works without focus) is preferred because the overlay is already gone when a snip or OCR result is ready. If wl-copy is missing the host falls back to `QClipboard`, which needs a recent input serial on Wayland.

## OCR

`tesseract <png> stdout -l <langs>` with langs joined by `+`. `snipshot_ocr_languages` lists installed packs minus `osd`.
