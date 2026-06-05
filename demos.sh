#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/cs2-paths.sh
source "$SCRIPT_DIR/scripts/cs2-paths.sh"

SOURCE="${DOWNLOADS_DIR:-$HOME/Downloads}"
KEEP_LOOSE=0
DRY_RUN=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source)
      shift
      [ "$#" -gt 0 ] || cs2_die "--source requires a path"
      SOURCE="$1"
      ;;
    --keep-loose)
      KEEP_LOOSE=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      cat <<'HELP'
Usage: ./demos.sh [--source DIR] [--keep-loose] [--dry-run]

Processes *.dem.zst files from Downloads into Counter-Strike 2's game/csgo directory.

Environment overrides:
  DOWNLOADS_DIR=/path/to/downloads
  CS2_GAME=/path/to/game/csgo
  CS2_ROOT=/path/to/Counter-Strike Global Offensive
  STEAM_ROOT=/path/to/Steam
HELP
      exit 0
      ;;
    *)
      cs2_die "Unknown argument: $1"
      ;;
  esac
  shift
done

command -v zstd >/dev/null 2>&1 || cs2_die "zstd not found. Install it with: sudo apt install zstd"
[ -d "$SOURCE" ] || cs2_die "Source directory not found: $SOURCE"

if ! GAME_DIR="$(cs2_find_game_dir)"; then
  cs2_explain_detection_failure
  exit 1
fi
[ -d "$GAME_DIR" ] || cs2_die "CS2 game directory does not exist: $GAME_DIR"

printf 'Source: %s\n' "$SOURCE"
printf 'CS2 game dir: %s\n' "$GAME_DIR"

if [ "$KEEP_LOOSE" -eq 0 ]; then
  for dem in "$SOURCE"/*.dem; do
    printf 'Deleting loose demo: %s\n' "$(basename "$dem")"
    [ "$DRY_RUN" -eq 1 ] || rm -f -- "$dem"
  done
fi

COUNT=0
for packed in "$SOURCE"/*.dem.zst; do
  COUNT=$((COUNT + 1))
  out="$GAME_DIR/$(basename "${packed%.zst}")"
  printf 'Processing: %s\n' "$(basename "$packed")"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  Dry run: would decompress to %s\n' "$out"
    continue
  fi

  if zstd -d --force "$packed" -o "$out" >/dev/null; then
    rm -f -- "$packed"
    printf '  OK -> %s\n' "$(basename "$out")"
  else
    printf '  ERROR -> decompression failed\n' >&2
  fi
done

if [ "$COUNT" -eq 0 ]; then
  printf 'No .dem.zst files found in %s.\n' "$SOURCE"
else
  printf '\nDone! Demos copied to CS2 folder.\n'
fi

printf '\nAvailable demos (paste into CS2 console):\n'
printf '%s\n' '-----------------------------------------------'
find "$GAME_DIR" -maxdepth 1 -type f -name '*.dem' -printf '%T@ %TY-%Tm-%Td %TH:%TM %f\n' 2>/dev/null \
  | sort -nr \
  | while read -r _ date time file; do
      printf '%s %s  playdemo %s\n' "$date" "$time" "$file"
    done
