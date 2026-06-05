#!/usr/bin/env bash
set -euo pipefail

cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n scripts/cs2-paths.sh
bash -n install.sh
bash -n demos.sh
bash -n setup.sh
python3 - <<'PY'
import py_compile
py_compile.compile('scripts/set-steam-launch-options.py', cfile='/tmp/cs2-set-steam-launch-options.pyc', doraise=True)
PY

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/game/csgo/cfg" "$TMP/downloads"

cat > "$TMP/localconfig.vdf" <<'VDF'
"UserLocalConfigStore"
{
	"Software"
	{
		"Valve"
		{
			"Steam"
			{
				"apps"
				{
					"730"
					{
						"LastPlayed"		"1"
						"LaunchOptions"		"old options"
					}
				}
			}
		}
	}
}
VDF
python3 scripts/set-steam-launch-options.py \
  --localconfig "$TMP/localconfig.vdf" \
  --appid 730 \
  --launch-options 'gamescope -- %command% +exec autoexec'
grep -q 'gamescope -- %command% +exec autoexec' "$TMP/localconfig.vdf"

NATIVE_DRY_RUN="$(./setup.sh --dry-run --no-install-config --force-steam-running --localconfig "$TMP/localconfig.vdf")"
printf '%s\n' "$NATIVE_DRY_RUN" | grep -q -- '-freq 144 -fullscreen -w 1920 -h 1080 -console -novid -nojoy -high +exec autoexec'
printf '%s\n' "$NATIVE_DRY_RUN" | grep -q 'Dry run: localconfig.vdf not modified.'

CS2_CFG="$TMP/game/csgo/cfg" ./install.sh

test -f "$TMP/game/csgo/cfg/autoexec.cfg"
test -f "$TMP/game/csgo/cfg/custom_cfg/crosshair.cfg"
test -f "$TMP/game/csgo/cfg/custom_cfg/crosshair_state.cfg"

PRINTED_TARGET="$(CS2_CFG="$TMP/game/csgo/cfg" ./install.sh --print-target)"
test "$PRINTED_TARGET" = "$TMP/game/csgo/cfg"

if command -v zstd >/dev/null 2>&1; then
  printf 'demo-content' > "$TMP/downloads/test.dem"
  zstd -q "$TMP/downloads/test.dem" -o "$TMP/downloads/test.dem.zst"
  rm "$TMP/downloads/test.dem"

  CS2_GAME="$TMP/game/csgo" DOWNLOADS_DIR="$TMP/downloads" ./demos.sh

  test -f "$TMP/game/csgo/test.dem"
  test ! -f "$TMP/downloads/test.dem.zst"
else
  printf 'Skipping zstd integration test: zstd not found\n'
fi

printf 'OK\n'
