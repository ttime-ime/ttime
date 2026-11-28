# T-Time

A Tibetan input engine: EWTS ↔ Unicode conversion and incremental composition in a
platform-independent Rust core, with native IMEs to follow (macOS, then Windows,
then Linux). See `docs/` for the plan, the EWTS specification and decision records.

macOS has a working InputMethodKit shell (`macos/`). `windows/` and `linux/` are
scaffolds for future TSF and IBus/Fcitx5 shells; they are not IMEs yet. The shared
C ABI is exercised on Linux and Windows in CI by `ffi-smoke/`
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
