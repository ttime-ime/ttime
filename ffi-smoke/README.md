# FFI smoke harness

A tiny C program that links `ttime-ffi` and drives `ttime_composer` through one
EWTS syllable (`bkra` + space). It proves the C ABI builds and runs on the host
OS. It is not an input method.

## Build and run

From the repository root:

```sh
scripts/build-ffi-smoke.sh    # macOS / Linux → build/ffi-smoke
./build/ffi-smoke
```

```powershell
pwsh scripts/build-ffi-smoke.ps1   # Windows → build/ffi-smoke.exe
.\build\ffi-smoke.exe
```

Success prints `ffi-smoke: ok` and exits 0. The binary links the **static**
library (`libttime_ffi.a` / `ttime_ffi.lib`) so there is no DLL/so path to set
for the smoke itself.

## Header

`crates/ttime-ffi/include/ttime.h` is the contract. Future Windows (TSF) and
Linux (IBus/Fcitx5) shells should call the same API; see `windows/` and
`linux/`.
