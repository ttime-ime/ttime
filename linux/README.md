# Linux IBus engine

Composer-only T-Time input method for IBus (GNOME and other IBus desktops). It
links `ttime-ffi` and supports EWTS composition (underlined preedit, commit on
Space/Return, Backspace/Escape, Tibetan/Latin via left-Shift tap). There is no
Stacker, Symbols, Dictionary, or toolbar UI yet. **Fcitx5 is not included** in
this MVP.

| Path | Role |
|---|---|
| `linux/ibus/` | IBus engine (`ibus-engine-ttime`) |
| `scripts/build-linux-ibus.sh` | Build `ttime-ffi` + the engine |
| `scripts/install-linux-ibus.sh` | Install into `~/.local` for the current user |

Engine name: `ttime` (bus name `org.freedesktop.IBus.TTime`). EWTS is typed on a
US/Latin keyboard layout (`layout` us in the component).

## Prerequisites

- Linux with IBus (GNOME on Wayland is the intended first target)
- [Rust](https://rustup.rs/) (stable)
- A C11 compiler (`cc`)
- Development packages, e.g. Debian/Ubuntu:

```sh
sudo apt install build-essential pkg-config libibus-1.0-dev
```

Fedora: `ibus-devel`. Arch: `ibus`.

## Build

```sh
scripts/build-linux-ibus.sh
```

Output:

- `build/linux/ibus-engine-ttime`
- `build/linux/ttime.xml` (exec path points at the build tree)

CI runs the same script on `ubuntu-latest` and uploads the binary; it does not
start IBus.

## Install (user-local)

```sh
scripts/install-linux-ibus.sh
ibus restart
```

That copies the engine to `~/.local/libexec/ibus-engine-ttime` and the component
to `~/.local/share/ibus/component/ttime.xml`. Not yet checked: whether your
`ibus-daemon` reads that folder. If `ibus list-engine | grep -i ttime` shows nothing
after `ibus restart`, point IBus at it with `IBUS_COMPONENT_PATH` (it replaces the
search path, so include the system folder too, for example
`/usr/share/ibus/component:$HOME/.local/share/ibus/component`), or copy
`build/linux/ttime.xml` into `/usr/share/ibus/component/` with `sudo`.

Then add the input source:

1. Settings → Keyboard → **Input Sources** → Add → look for **T-Time** / Tibetan
2. Or: `ibus list-engine | grep -i ttime` then enable it in your desktop’s IME UI

## Test checklist

| Action | Expected |
|---|---|
| Type `bkra` | Tibetan preedit (underlined) |
| Space | Commits `བཀྲ་` |
| Backspace | Edits the preedit |
| Escape | Cancels the preedit |
| Left Shift tap | Toggles Tibetan / Latin (double tap locks) |
| Switch to another window | Starts in the mode last chosen, or the locked mode |
| Ctrl+S, Alt+F, … | Reach the application |
| Latin mode | ASCII passes through |

Try gedit or LibreOffice. Floating UI (Stacker, Symbols, accents, Sanskrit) is
out of scope for this MVP. None of this has been run under IBus yet; CI only builds
the engine.

## Mode memory

One engine process serves every window, and the mode lock is shared by all of them,
so a lock or the mode last chosen carries over, as on macOS. Both are saved in
`~/.config/t-time/ibus.ini` (`[mode]` `lock`, `last`: -1 none, 0 Tibetan, 1 Latin);
`start` (0 or 1) sets the mode before any choice. The rule is the core's
`ttime_mode_lock_mode_on_focus`.

## FFI smoke (no IME)

```sh
scripts/build-ffi-smoke.sh
./build/ffi-smoke
```

## Desktop notes

- Primary target: **GNOME + IBus**.
- Other sessions that use IBus should work for composer-only typing.
- Fcitx5 users need a later addon; this tree does not provide one yet.
