# T-Time

A Tibetan input engine: EWTS ↔ Unicode conversion and incremental composition in a
platform-independent Rust core, with native IMEs to follow (macOS, then Windows,
then Linux). See `docs/` for the plan, the EWTS specification and decision records.

macOS has a working InputMethodKit shell (`macos/`). Windows has a composer-only
TSF text service (`windows/tsf/`, build with `scripts/build-windows-tsf.ps1`; see
`windows/README.md`). Linux remains a scaffold for a future IBus/Fcitx5 shell.
The shared C ABI is also exercised by `ffi-smoke/`
(`scripts/build-ffi-smoke.sh` / `.ps1`).

## Licence

Code is licensed under either of

- Apache License, Version 2.0 (`LICENSE-APACHE`)
- MIT license (`LICENSE-MIT`)

at your option. Third-party attributions are in `NOTICE`.

The illustrations and logos (`macos/Resources`, `design/`) were made for T-Time by
the project and are **not** covered by this grant: they are not licensed for
reuse unless a licence says so.

Contributions are accepted under the same dual licence unless stated otherwise.
