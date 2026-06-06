#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/cs2-paths.sh
source "$SCRIPT_DIR/scripts/cs2-paths.sh"

DRY_RUN=0
PRINT_TARGET=0

usage() {
  cat <<'HELP'
Usage: ./setup.sh [--dry-run] [--print-target]

Installs this CS2 config into Counter-Strike 2's game/csgo/cfg directory.
It only copies:
  autoexec.cfg
  custom_cfg/

Environment overrides:
  CS2_CFG=/path/to/game/csgo/cfg
  CS2_GAME=/path/to/game/csgo
  CS2_ROOT=/path/to/Counter-Strike Global Offensive
  STEAM_ROOT=/path/to/Steam
HELP
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --print-target)
      PRINT_TARGET=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      cs2_die "Unknown argument: $1"
      ;;
  esac
  shift
done

if ! CFG_DIR="$(cs2_find_cfg_dir)"; then
  cs2_explain_detection_failure
  exit 1
fi

if [ "$PRINT_TARGET" -eq 1 ]; then
  printf '%s\n' "$CFG_DIR"
  exit 0
fi

printf 'Installing CS2 config to: %s\n' "$CFG_DIR"

if [ "$DRY_RUN" -eq 1 ]; then
  printf 'Dry run: would copy autoexec.cfg and custom_cfg/\n'
  exit 0
fi

[ -f "$SCRIPT_DIR/autoexec.cfg" ] || cs2_die "Missing $SCRIPT_DIR/autoexec.cfg"
[ -d "$SCRIPT_DIR/custom_cfg" ] || cs2_die "Missing $SCRIPT_DIR/custom_cfg"

mkdir -p "$CFG_DIR/custom_cfg"
cp "$SCRIPT_DIR/autoexec.cfg" "$CFG_DIR/autoexec.cfg"
cp -R "$SCRIPT_DIR/custom_cfg/." "$CFG_DIR/custom_cfg/"

printf 'OK: installed autoexec.cfg and custom_cfg/\n'
