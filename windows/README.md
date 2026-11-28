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
- **Language:** English (United States) — EWTS is typed on a Latin keyboard

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

1. Settings → Time & Language → Language & region → **English (United States)**  
   → Language options → Keyboards → **Add a keyboard** → **T-Time**
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
| Latin mode | ASCII passes through |
| Ctrl+S, Alt+F, … | Reach the application; Ctrl or Alt alone commits nothing |
| Click another window mid-syllable | The syllable is committed where it was typed |

Word should behave the same for basic composition. None of this has been run on
Windows yet; CI only builds the DLL. Floating UI (Stacker,
Symbols, accents, Sanskrit) is out of scope for this MVP.

## FFI smoke (no IME)

To exercise only the C ABI without TSF:

```powershell
pwsh scripts/build-ffi-smoke.ps1
.\build\ffi-smoke.exe
```
