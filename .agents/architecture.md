# Architecture

## Process model

One resident instance owns the session bus name `net.electris.SnipShot` (object `/net/electris/SnipShot`, method `Activate(as)`). Any later `snipshot ...` invocation fails to register the name, forwards its arguments over D-Bus and exits. `handleCommand` in `app/capturebackend.cpp` is the single entry point for both paths. The app never quits when windows close; `snipshot quit` ends it. `restart()` releases the bus name before spawning the replacement so the new process becomes the primary.

## Layers

- `src/core.zig`: C ABI (`src/core.h`) for grim, compositor IPC, tesseract, wl-copy, gpu-screen-recorder, wf-recorder and ffmpeg. Blocking calls; the host always runs them on `QThreadPool`. Recording state is a single global, so recorder calls must stay serialised (`m_recorderBusy`).
- `app/capturebackend.*`: the state machine and everything QML binds to, registered as the `Capture` singleton in `SnipShot.Core`. Pixel work (crop, freeform mask, border, PNG encoding) is here because Zig has no image codec and Qt already does it.
- `app/overlaycontroller.*`: creates one `CaptureOverlay` per `QScreen` from the QML module, configures LayerShellQt for every layer surface, and owns the frozen images behind `image://frozen/<screen>/<serial>`.
- `app/settings.*`: a `QQmlPropertyMap` over QSettings (`~/.config/SnipShot/SnipShot.conf`), registered as `Config`. Defaults live in its table; QML writes persist immediately.
- `ui/App.qml`: a `QtObject` holding every top-level window as a property. C++ finds the layer-shell windows by property name (`recordBar`, `recordFrame`, `statusPill`, `textFlyout`), so renaming one breaks `OverlayController::attach`.

## Capture states

`idle -> delaying -> freezing -> selecting -> processing -> idle` for snips and text. Recording goes `selecting -> armed -> countdown -> starting -> recording -> finishing -> idle`. Window visibility is bound to these states in QML; C++ only positions layer surfaces.

Freezing grabs every output in parallel before any overlay maps, so SnipShot's own windows never appear in a snip. Main/settings/text windows are hidden first and the freeze waits 150 ms for them to unmap. Record mode shows the live screen (the frozen image is hidden) because the region is about to be recorded.

## Layer-shell rules learned the hard way

- On sway, unmapping a layer surface that holds exclusive keyboard focus leaves the seat's pointer stuck on the dead surface; no other surface gets enter events afterwards. `hideOverlays` therefore drops keyboard interactivity to none, then hides 50 ms later.
- Pointer input order between separately mapped layer surfaces did not match render order on sway. The armed-state record controls are drawn inside the overlay (`RecordControls` in `CaptureOverlay.qml`); the separate `RecordBar` window only exists once the overlays are gone.
- A layer surface cannot change outputs while mapped. `OverlayController::placeAt` hides, moves and re-shows.
- Recorder bar and frame sit outside the recorded rect, so they never end up in the video.

## Normal windows

Main, settings and snip windows are xdg toplevels. Tiling compositors would tile them, so `snipshot_float_window` floats, sizes and centres them by title on Hyprland (`hyprctl eval` Lua) and sway (`swaymsg`). Titles are therefore part of the contract: `SnipShot`, `SnipShot Settings`, `SnipShot Snip`. Pass the intended size, not `width`/`height` at show time, which already hold the tiled size.
