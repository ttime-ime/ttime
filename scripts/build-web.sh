#!/bin/sh
# Builds the Wasm bridge and writes it, with the curated fixtures, into the
# playground checkout (default ../playground, or the directory given as $1).
# Needs: rustup target wasm32-unknown-unknown, wasm-bindgen-cli (same version as
# the wasm-bindgen crate pinned in crates/ttime-wasm/Cargo.toml).
set -eu
cd "$(dirname "$0")/.."
OUT="${1:-../playground}"
[ -d "$OUT" ] || { echo "no such directory: $OUT" >&2; exit 1; }

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
rm -rf "$OUT/pkg" "$OUT/fixtures"
wasm-bindgen --target web --out-dir "$OUT/pkg" --no-typescript \
  target/wasm32-unknown-unknown/release/ttime_wasm.wasm
mkdir -p "$OUT/fixtures"
cp crates/ttime-core/tests/fixtures/*.tsv "$OUT/fixtures/"
ls "$OUT/fixtures" | grep '\.tsv$' > "$OUT/fixtures/index.txt"
printf 'ttime commit: %s\nbuilt: %s\n' "$TTIME_GIT_SHA" "$(date -u +%Y-%m-%dT%H:%MZ)" > "$OUT/BUILD_INFO"
echo "wrote $OUT/pkg ($(wc -c < "$OUT/pkg/ttime_wasm_bg.wasm") bytes wasm), ttime commit $TTIME_GIT_SHA"
