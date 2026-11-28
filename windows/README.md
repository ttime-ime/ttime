# Windows Text Service (TSF)

Composer-only T-Time input method for Windows 10/11. It links `ttime-ffi` and
supports EWTS composition (underlined provisional text, commit on Space/Return,
Backspace/Escape, Tibetan/Latin via left-Shift tap). There is no Stacker,
Symbols, Dictionary, or toolbar UI yet.

| Path | Role |
|---|---|
| `windows/tsf/` | C++ TSF DLL (`TTimeTSF.dll`) |
| `windows/register.ps1` | `regsvr32` register / unregister (elevated) |
| `scripts/build-windows-tsf.ps1` | Build `ttime-ffi` + the DLL |

Stable identifiers (do not change once published):

- **CLSID:** `{B7E4C2A1-9F3D-4E8B-A1C6-2D5E8F0A1B3C}`
- **Profile GUID:** `{C8F5D3B2-0A4E-5F9C-B2D7-3E6F9A1B2C4D}`
- **Language:** Tibetan (PRC), bo-CN, so typed text is tagged Tibetan; EWTS is typed
  on the Latin keys of whatever keyboard layout is in use

## Prerequisites

- Windows 10 or 11 (or a VM: Parallels, UTM, cloud)
- [Rust](https://rustup.rs/) (stable, MSVC toolchain)
- Visual Studio 2022 Build Tools with the **Desktop development with C++** workload
- CMake 3.20+ (comes with the VS installer)

## Build

```powershell
pwsh scripts/build-windows-tsf.ps1
```

Output: `build/windows/TTimeTSF.dll` (plus `ttime_ffi.lib` for reference).

CI runs the same script on `windows-latest` and uploads the DLL as an artifact;
it does not register the TIP.

## Register

From an **elevated** PowerShell:

```powershell
pwsh -File windows/register.ps1
# to remove:
pwsh -File windows/register.ps1 -Unregister
```

## Enable and test

1. Settings → Time & Language → Language & region → **Add a language** → **Tibetan
   (PRC)** (if it is not there yet), then Tibetan → Language options → Keyboards →
   **Add a keyboard** → **T-Time**. Windows may add its own Tibetan keyboard with the
   language; remove it there if you do not want it.
2. Choose **T-Time** from the taskbar input indicator (or Win+Space).
3. Open Notepad and try:

| Action | Expected |
|---|---|
| Type `bkra` | Tibetan preedit (underlined) |
| Space | Commits `བཀྲ་` |
| Backspace | Edits the preedit |
| Escape | Cancels the preedit |
| Return mid-syllable | Commits it, then a new line |
| Left Shift tap | Toggles Tibetan / Latin (double tap locks) |
| Switch to another app | Starts in the mode last chosen, or the locked mode |
| Latin mode | ASCII passes through |
| Ctrl+S, Alt+F, … | Reach the application; Ctrl or Alt alone commits nothing |
| Click another window mid-syllable | The syllable is committed where it was typed |

Word should behave the same for basic composition. None of this has been run on
Windows yet; CI only builds the DLL. Floating UI (Stacker,
Symbols, accents, Sanskrit) is out of scope for this MVP.

## Mode memory

The lock and the last mode are kept in `HKCU\Software\T-Time` (`ModeLock`,
`LastMode`: DWORD 0 none, 1 Tibetan, 2 Latin), because each application loads its own
copy of the DLL. `StartMode` (same values) sets the mode before any choice; there is no
settings window for it yet. The rule itself (lock, else last mode, else start mode) is
the core's `ttime_mode_lock_mode_on_focus`, the same as on macOS.

## FFI smoke (no IME)

To exercise only the C ABI without TSF:

```powershell
pwsh scripts/build-ffi-smoke.ps1
.\build\ffi-smoke.exe
```
