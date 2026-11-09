# Roadmap

## Snipping Tool parity

- Markup editor: pen, highlighter, eraser, crop, shapes, undo/redo, ruler.
- Text actions in the editor: select OCR words on the image, quick redact emails and phone numbers. Needs tesseract TSV output for word boxes.
- Colour picker.

## Desktops

- GNOME and KDE: screenshot and screencast portals (KDE also has layer-shell; GNOME has neither layer-shell nor wlr-screencopy).
- X11: a freeze backend and fullscreen override-redirect overlays.
- Window snips on desktops other than Hyprland and sway.
- True window capture: grab the picked window with `grim -T <ext-foreign-toplevel id>` so covered parts come out too. Needs a verified mapping from Hyprland and sway clients to foreign-toplevel identifiers.

## Rough edges

- On sway the snip window sometimes floats at its tiled size instead of the fitted size.
- gpu-screen-recorder start is confirmed by polling for up to 1.5 s, so the first moment after the countdown can be cut or the timer can lag slightly.

## Unverified

- Notification actions (Open, Copy, Save as) with a real notification daemon.
