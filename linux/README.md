# Linux adapter (scaffold)

Reserved for a future IBus and/or Fcitx5 input method over `ttime-ffi`. Nothing
here is an IME yet.

For now, prove the C ABI on Linux:

```sh
scripts/build-ffi-smoke.sh
./build/ffi-smoke
```

See `ffi-smoke/README.md` and `crates/ttime-ffi/include/ttime.h`. macOS and a
composer-only Windows TSF shell exist; Linux IBus/Fcitx5 is next.
