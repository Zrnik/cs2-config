#!/usr/bin/env bash
set -euo pipefail

cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n scripts/cs2-paths.sh
bash -n setup.sh
bash -n install.sh
bash -n demos.sh

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/game/csgo/cfg" "$TMP/downloads"

SETUP_DRY_RUN="$(CS2_CFG="$TMP/game/csgo/cfg" ./setup.sh --dry-run)"
printf '%s\n' "$SETUP_DRY_RUN" | grep -q "Installing CS2 config to: $TMP/game/csgo/cfg"
printf '%s\n' "$SETUP_DRY_RUN" | grep -q 'Dry run: would copy autoexec.cfg and custom_cfg/'

CS2_CFG="$TMP/game/csgo/cfg" ./setup.sh

test -f "$TMP/game/csgo/cfg/autoexec.cfg"
test -f "$TMP/game/csgo/cfg/custom_cfg/crosshair.cfg"
test -f "$TMP/game/csgo/cfg/custom_cfg/crosshair_state.cfg"

PRINTED_TARGET="$(CS2_CFG="$TMP/game/csgo/cfg" ./setup.sh --print-target)"
test "$PRINTED_TARGET" = "$TMP/game/csgo/cfg"

rm -rf "$TMP/game/csgo/cfg/custom_cfg"
rm -f "$TMP/game/csgo/cfg/autoexec.cfg"
CS2_CFG="$TMP/game/csgo/cfg" ./install.sh

test -f "$TMP/game/csgo/cfg/autoexec.cfg"
test -f "$TMP/game/csgo/cfg/custom_cfg/crosshair.cfg"

if command -v zstd >/dev/null 2>&1; then
  printf 'demo-content' > "$TMP/downloads/test.dem"
  zstd -q "$TMP/downloads/test.dem" -o "$TMP/downloads/test.dem.zst"
  rm "$TMP/downloads/test.dem"

  DEMO_DRY_RUN="$(CS2_GAME="$TMP/game/csgo" DOWNLOADS_DIR="$TMP/downloads" ./demos.sh --dry-run)"
  printf '%s\n' "$DEMO_DRY_RUN" | grep -q "Dry run: would decompress to $TMP/game/csgo/test.dem"
  test -f "$TMP/downloads/test.dem.zst"

  CS2_GAME="$TMP/game/csgo" DOWNLOADS_DIR="$TMP/downloads" ./demos.sh

  test -f "$TMP/game/csgo/test.dem"
  test ! -f "$TMP/downloads/test.dem.zst"
else
  printf 'Skipping zstd integration test: zstd not found\n'
fi

printf 'OK\n'
