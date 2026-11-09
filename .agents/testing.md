# Testing

## Headless first

Run GUI checks in a Wardian session (headless sway). Launch with a scratch config and output folder so tests never write to the user's real folders. On this machine `~/Pictures` resolves into `~/Vault`, which is off limits.

```sh
printf '[General]\nrecorderBackend=2\n' > "$SCRATCH/config/SnipShot/SnipShot.conf"
ln -sfn ~/.config/qt6ct "$SCRATCH/config/qt6ct"   # Desktop theme tests need the real qt6ct config
wardian -s NAME run --name app -e XDG_CONFIG_HOME="$SCRATCH/config" -e SNIPSHOT_OUTPUT_DIR="$SCRATCH/out" -- build/snipshot --daemon
wardian -s NAME exec -- build/snipshot snip
```

`recorderBackend=2` forces wf-recorder. gpu-screen-recorder captures the real GPU through KMS and must not run in a session (see `capture-backends.md`).

Wardian batches deliver pointer moves faster than a frame, and Qt coalesces them into one motion event. Pace moves with `wait_frames` or use `drag --ms` when testing freeform or drags, or the selection looks broken when it is not.

Useful checks: `wl-paste --list-types` inside the session for the clipboard, `ffprobe` on recordings, `a11y` to press bar buttons by name.

## Live desktop

Anything that captures the user's screen (live Hyprland, gpu-screen-recorder, multi-monitor with the rotated output) needs the user's go-ahead for that run. Keep captures in the session scratchpad and delete them afterwards.

Live-only facts still to confirm are listed in `ROADMAP.md`.
