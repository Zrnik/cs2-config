#!/usr/bin/env bash

cs2_die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

cs2_candidate_steam_roots() {
  [ -n "${STEAM_ROOT:-}" ] && printf '%s\n' "$STEAM_ROOT"
  printf '%s\n' \
    "$HOME/.steam/steam" \
    "$HOME/.local/share/Steam" \
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
}

cs2_library_paths_from_root() {
  local root="$1"

  # Primary library inside the Steam root itself.
  [ -d "$root/steamapps" ] && printf '%s\n' "$root"

  local vdf="$root/steamapps/libraryfolders.vdf"
  [ -f "$vdf" ] || return 0

  # Additional Steam libraries. Debian/Linux Steam stores absolute POSIX paths here.
  sed -nE 's/^[[:space:]]*"path"[[:space:]]*"([^"]+)".*/\1/p' "$vdf"
}

cs2_find_root() {
  if [ -n "${CS2_ROOT:-}" ]; then
    printf '%s\n' "$CS2_ROOT"
    return 0
  fi

  if [ -n "${CS2_GAME:-}" ]; then
    printf '%s\n' "${CS2_GAME%/game/csgo}"
    return 0
  fi

  if [ -n "${CS2_CFG:-}" ]; then
    local game="${CS2_CFG%/cfg}"
    printf '%s\n' "${game%/game/csgo}"
    return 0
  fi

  local steam_root library candidate
  while IFS= read -r steam_root; do
    [ -n "$steam_root" ] || continue
    [ -d "$steam_root" ] || continue

    while IFS= read -r library; do
      [ -n "$library" ] || continue
      candidate="$library/steamapps/common/Counter-Strike Global Offensive"
      [ -d "$candidate/game/csgo" ] && printf '%s\n' "$candidate" && return 0
    done < <(cs2_library_paths_from_root "$steam_root")
  done < <(cs2_candidate_steam_roots)

  return 1
}

cs2_find_game_dir() {
  if [ -n "${CS2_GAME:-}" ]; then
    printf '%s\n' "$CS2_GAME"
    return 0
  fi

  if [ -n "${CS2_CFG:-}" ]; then
    printf '%s\n' "${CS2_CFG%/cfg}"
    return 0
  fi

  printf '%s/game/csgo\n' "$(cs2_find_root)"
}

cs2_find_cfg_dir() {
  if [ -n "${CS2_CFG:-}" ]; then
    printf '%s\n' "$CS2_CFG"
    return 0
  fi

  printf '%s/cfg\n' "$(cs2_find_game_dir)"
}

cs2_explain_detection_failure() {
  cat >&2 <<'HELP'
Could not find CS2 installed through Steam on Debian/Linux.

Checked Steam roots:
  $STEAM_ROOT
  $HOME/.steam/steam
  $HOME/.local/share/Steam
  $HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam

Set one of these manually, for example:
  CS2_ROOT="$HOME/.local/share/Steam/steamapps/common/Counter-Strike Global Offensive" ./setup.sh
  CS2_CFG="/path/to/Counter-Strike Global Offensive/game/csgo/cfg" ./setup.sh
HELP
}
