#!/bin/sh
# Builds ffi-smoke against the ttime-ffi static library (macOS / Linux).
# Output: build/ffi-smoke
set -eu
cd "$(dirname "$0")/.."
export PATH="${HOME}/.cargo/bin:${PATH}"
TARGET_DIR=${CARGO_TARGET_DIR:-target}

mkdir -p build
cargo build --release -p ttime-ffi

# System libraries the Rust staticlib needs (pthread, Security, …).
NATIVE=$(cargo rustc -p ttime-ffi --release -- --print=native-static-libs 2>&1 \
  | sed -n 's/^note: native-static-libs: //p' | tail -n 1)

LIB="$TARGET_DIR/release/libttime_ffi.a"
INC=crates/ttime-ffi/include
OUT=build/ffi-smoke

# shellcheck disable=SC2086
# Strict C99 with warnings as errors, so a header that only compiles leniently fails here.
cc -std=c99 -Wall -Wextra -pedantic -Werror -O2 -o "$OUT" ffi-smoke/main.c -I "$INC" "$LIB" $NATIVE
echo "built $OUT"
"$OUT"
