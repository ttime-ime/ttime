# Windows adapter (scaffold)

Reserved for the future Text Services Framework (TSF) input method over
`ttime-ffi`. Nothing here is an IME yet.

For now, prove the C ABI on Windows:

```powershell
pwsh scripts/build-ffi-smoke.ps1
.\build\ffi-smoke.exe
```

See `ffi-smoke/README.md` and `crates/ttime-ffi/include/ttime.h`. Platform order
in the project plan is macOS → Windows → Linux.
