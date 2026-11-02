#!/bin/sh
# Builds the Wasm bridge into web/pkg and copies fixtures for the parity page.
# Needs: rustup target wasm32-unknown-unknown, wasm-bindgen-cli (same version as
# the wasm-bindgen crate pinned in crates/ttime-wasm/Cargo.toml).
set -eu
cd "$(dirname "$0")/.."

want=$(sed -n 's/^wasm-bindgen = "=\(.*\)"/\1/p' crates/ttime-wasm/Cargo.toml)
have=$(wasm-bindgen --version | awk '{print $2}')
if [ "$want" != "$have" ]; then
  echo "wasm-bindgen CLI is $have but the crate is pinned to $want" >&2
  exit 1
fi

TTIME_GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then TTIME_GIT_SHA="$TTIME_GIT_SHA+dirty"; fi
export TTIME_GIT_SHA

cargo build -p ttime-wasm --release --target wasm32-unknown-unknown
rm -rf web/pkg web/fixtures
wasm-bindgen --target web --out-dir web/pkg --no-typescript \
  target/wasm32-unknown-unknown/release/ttime_wasm.wasm
mkdir -p web/fixtures
cp crates/ttime-core/tests/fixtures/*.tsv web/fixtures/
ls web/fixtures > web/fixtures/index.txt
echo "built web/pkg ($(wc -c < web/pkg/ttime_wasm_bg.wasm) bytes wasm), commit $TTIME_GIT_SHA"
