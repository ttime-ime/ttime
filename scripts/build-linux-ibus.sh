#!/bin/sh
# Builds the T-Time IBus engine against ttime-ffi (Linux).
# Output: build/linux/ibus-engine-ttime and build/linux/ttime.xml
set -eu
cd "$(dirname "$0")/.."
export PATH="${HOME}/.cargo/bin:${PATH}"
TARGET_DIR=${CARGO_TARGET_DIR:-target}

mkdir -p build/linux
cargo build --release -p ttime-ffi

NATIVE=$(cargo rustc --color never -p ttime-ffi --release -- --print=native-static-libs 2>&1 \
  | sed -n 's/^note: native-static-libs: //p' | tail -n 1)
if [ -z "$NATIVE" ]; then
  echo "could not read the native libraries ttime-ffi needs" >&2
  exit 1
fi

if ! pkg-config --exists ibus-1.0; then
  echo "ibus-1.0 not found; install libibus-1.0-dev (Debian/Ubuntu) or ibus-devel" >&2
  exit 1
fi

LIB="$TARGET_DIR/release/libttime_ffi.a"
INC=crates/ttime-ffi/include
OUT=build/linux/ibus-engine-ttime
CFLAGS=$(pkg-config --cflags ibus-1.0)
LIBS=$(pkg-config --libs ibus-1.0)

# shellcheck disable=SC2086
cc -std=c11 -Wall -Wextra -O2 -o "$OUT" \
  linux/ibus/src/main.c \
  linux/ibus/src/engine.c \
  linux/ibus/src/composer_host.c \
  -I "$INC" -I linux/ibus/src \
  $CFLAGS \
  "$LIB" $NATIVE $LIBS

# Absolute path so a user-local component can find the binary without install.
EXEC_PATH=$(cd build/linux && pwd)/ibus-engine-ttime
sed "s|@EXEC_PATH@|$EXEC_PATH|g" linux/ibus/ttime.xml.in > build/linux/ttime.xml

cp -f "$LIB" build/linux/libttime_ffi.a

echo "built $OUT"
echo "component: build/linux/ttime.xml"
echo "Install (user-local): scripts/install-linux-ibus.sh"
