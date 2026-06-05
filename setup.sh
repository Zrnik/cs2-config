#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/cs2-paths.sh
source "$SCRIPT_DIR/scripts/cs2-paths.sh"

DRY_RUN=0
INSTALL_CONFIG=1
SET_LAUNCH_OPTIONS=1
INSTALL_GAMESCOPE=0
MODE="native"
MONITOR_MODE="best"
APPID="730"
STEAM_USER_ID="${STEAM_USER_ID:-}"
LOCALCONFIG="${STEAM_LOCALCONFIG:-}"
EXTRA_CS2_ARGS="${EXTRA_CS2_ARGS:-}"
FORCE_STEAM_RUNNING=0
RESTART_STEAM=1
STEAM_WAS_RUNNING=0

usage() {
  cat <<'HELP'
Usage: ./setup.sh [options]

Installs this CS2 config and sets Steam launch options for Debian/Linux Steam.
By default it:
  1. installs autoexec.cfg + custom_cfg/ into CS2's cfg directory,
  2. writes native 1920x1080 CS2 LaunchOptions into Steam's localconfig.vdf.

Gamescope 4:3 stretched mode is available only with --gamescope/--stretched because CS2 currently segfaults under gamescope on this machine. The removed KDE/X11 display-mode switching approach is intentionally not used because it shrinks the desktop while alt-tabbing.

Options:
  --dry-run                 Print actions; do not install packages or modify files.
  --native                  Use native CS2 1920x1080 launch options (default).
  --stretched               Alias for --gamescope; experimental because CS2 segfaults here.
  --gamescope               Install/use gamescope 1280x960 stretched launch options; experimental.
  --monitor best            Use enabled monitor with highest current refresh (default).
  --monitor primary         Use X11/KDE primary monitor.
  --monitor CONNECTOR       Use a connector like HDMI-A-6.
  --no-install-config       Do not copy cfg files into CS2.
  --no-launch-options       Do not edit Steam LaunchOptions.
  --no-install-gamescope    Do not install gamescope when using --gamescope.
  --steam-user-id ID        Steam userdata ID if auto-detection is ambiguous.
  --localconfig PATH        Edit this localconfig.vdf explicitly.
  --restart-steam           Stop Steam before editing launch options, then start it again (default).
  --no-restart-steam        Do not stop/start Steam; refuse if it is running unless forced.
  --force-steam-running     Edit launch options even when Steam appears to be running.
  --help                    Show this help.

Environment overrides:
  CS2_ROOT / CS2_GAME / CS2_CFG / STEAM_ROOT / STEAM_USER_ID / STEAM_LOCALCONFIG
  EXTRA_CS2_ARGS="..." appends extra args after +exec autoexec.
HELP
}

log() { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
run_cmd() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

steam_running() {
  pgrep -x steam >/dev/null 2>&1 || pgrep -f 'steamwebhelper|steam-runtime-launcher-service' >/dev/null 2>&1
}

stop_steam_for_localconfig() {
  STEAM_WAS_RUNNING=0
  if ! steam_running; then
    return 0
  fi

  STEAM_WAS_RUNNING=1
  if [ "$FORCE_STEAM_RUNNING" -eq 1 ]; then
    warn "Steam is running, but --force-steam-running was requested; editing localconfig.vdf without stopping Steam."
    return 0
  fi

  if [ "$RESTART_STEAM" -ne 1 ]; then
    cs2_die "Steam appears to be running. Rerun with --restart-steam, quit Steam first, or use --force-steam-running."
  fi

  log "Stopping Steam before editing localconfig.vdf..."
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] would stop Steam and restart it after editing launch options"
    return 0
  fi

  pkill -TERM -x steam || true
  local i
  for i in {1..20}; do
    steam_running || return 0
    sleep 1
  done

  warn "Steam did not exit cleanly after 20s; terminating remaining Steam helper processes."
  pkill -TERM -f 'steamwebhelper|steam-runtime|steam' || true
  for i in {1..10}; do
    steam_running || return 0
    sleep 1
  done

  cs2_die "Steam is still running; not editing localconfig.vdf"
}

restart_steam_if_needed() {
  [ "$STEAM_WAS_RUNNING" -eq 1 ] || return 0
  [ "$RESTART_STEAM" -eq 1 ] || return 0
  [ "$FORCE_STEAM_RUNNING" -ne 1 ] || return 0

  log "Starting Steam again..."
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] would start Steam"
    return 0
  fi

  if command -v steam >/dev/null 2>&1; then
    nohup steam >/tmp/cs2-config-steam-restart.log 2>&1 &
  elif [ -x "$HOME/.local/share/Steam/steam.sh" ]; then
    nohup "$HOME/.local/share/Steam/steam.sh" >/tmp/cs2-config-steam-restart.log 2>&1 &
  elif [ -x "$HOME/.steam/steam/steam.sh" ]; then
    nohup "$HOME/.steam/steam/steam.sh" >/tmp/cs2-config-steam-restart.log 2>&1 &
  else
    warn "Steam was stopped, but no steam launcher was found in PATH or common Steam roots. Start it manually."
    return 0
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --native) MODE="native"; INSTALL_GAMESCOPE=0 ;;
    --stretched) MODE="gamescope"; INSTALL_GAMESCOPE=1 ;;
    --gamescope) MODE="gamescope"; INSTALL_GAMESCOPE=1 ;;
    --monitor) shift; MONITOR_MODE="${1:-}"; [ -n "$MONITOR_MODE" ] || cs2_die "--monitor needs a value" ;;
    --no-install-config) INSTALL_CONFIG=0 ;;
    --no-launch-options) SET_LAUNCH_OPTIONS=0 ;;
    --no-install-gamescope) INSTALL_GAMESCOPE=0 ;;
    --steam-user-id) shift; STEAM_USER_ID="${1:-}"; [ -n "$STEAM_USER_ID" ] || cs2_die "--steam-user-id needs a value" ;;
    --localconfig) shift; LOCALCONFIG="${1:-}"; [ -n "$LOCALCONFIG" ] || cs2_die "--localconfig needs a value" ;;
    --restart-steam) RESTART_STEAM=1 ;;
    --no-restart-steam) RESTART_STEAM=0 ;;
    --force-steam-running) FORCE_STEAM_RUNNING=1 ;;
    --help|-h) usage; exit 0 ;;
    *) cs2_die "unknown option: $1" ;;
  esac
  shift
done

find_steam_root() {
  local root
  while IFS= read -r root; do
    [ -n "$root" ] || continue
    [ -d "$root" ] || continue
    printf '%s\n' "$(cd "$root" && pwd -P)"
    return 0
  done < <(cs2_candidate_steam_roots)
  return 1
}

find_localconfig() {
  if [ -n "$LOCALCONFIG" ]; then
    printf '%s\n' "$LOCALCONFIG"
    return 0
  fi

  local root userdir found=()
  root="$(find_steam_root)" || cs2_die "could not find Steam root"

  if [ -n "$STEAM_USER_ID" ]; then
    printf '%s/userdata/%s/config/localconfig.vdf\n' "$root" "$STEAM_USER_ID"
    return 0
  fi

  while IFS= read -r userdir; do
    [ -f "$userdir/config/localconfig.vdf" ] || continue
    if grep -q '"730"' "$userdir/config/localconfig.vdf"; then
      found+=("$userdir/config/localconfig.vdf")
    fi
  done < <(find "$root/userdata" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

  if [ "${#found[@]}" -eq 1 ]; then
    printf '%s\n' "${found[0]}"
    return 0
  fi

  if [ "${#found[@]}" -gt 1 ]; then
    printf 'Found multiple Steam users with CS2 in localconfig.vdf:\n' >&2
    printf '  %s\n' "${found[@]}" >&2
    cs2_die "rerun with --steam-user-id ID or --localconfig PATH"
  fi

  cs2_die "could not find Steam localconfig.vdf containing app 730"
}

ensure_gamescope() {
  [ "$INSTALL_GAMESCOPE" -eq 1 ] || return 0
  if command -v gamescope >/dev/null 2>&1; then
    log "gamescope already installed: $(command -v gamescope)"
    return 0
  fi

  log "gamescope not found; installing via apt. sudo may prompt for your password."
  run_cmd sudo apt-get update

  local candidate=""
  candidate="$(apt-cache policy gamescope 2>/dev/null | sed -nE 's/^[[:space:]]*Candidate:[[:space:]]*(.*)$/\1/p' | head -n1)"
  if [ -n "$candidate" ] && [ "$candidate" != "(none)" ]; then
    run_cmd sudo apt-get install -y gamescope
    return 0
  fi

  local codename=""
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    codename="${VERSION_CODENAME:-}"
  fi

  if [ "$codename" = "trixie" ]; then
    log "gamescope has no base apt candidate; enabling trixie-backports."
    if [ "$DRY_RUN" -eq 1 ]; then
      log "[dry-run] would write /etc/apt/sources.list.d/trixie-backports.list"
    else
      printf '%s\n' 'deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware' \
        | sudo tee /etc/apt/sources.list.d/trixie-backports.list >/dev/null
    fi
    run_cmd sudo apt-get update
    run_cmd sudo apt-get install -y -t trixie-backports gamescope
    return 0
  fi

  cs2_die "gamescope is not available from current apt sources; install it manually or rerun --native"
}

monitor_from_xrandr() {
  local mode="$1" tmp
  tmp="$(mktemp)"
  xrandr --query >"$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  python3 - "$mode" "$tmp" <<'PY'
import re
import sys
mode = sys.argv[1]
path = sys.argv[2]
outputs = []
current = None
for line in open(path, encoding='utf-8', errors='replace'):
    m = re.match(r'^(\S+) connected( primary)?(?: (\d+)x(\d+)\+(\d+)\+(\d+))?', line)
    if m:
        current = {
            'name': m.group(1),
            'primary': bool(m.group(2)),
            'width': int(m.group(3) or 0),
            'height': int(m.group(4) or 0),
            'refresh': 0.0,
        }
        outputs.append(current)
        continue
    if current:
        mm = re.match(r'^\s+(\d+)x(\d+)\s+(.+)$', line)
        if not mm:
            continue
        rates = mm.group(3).split()
        for rate in rates:
            if '*' in rate:
                try:
                    current['refresh'] = float(rate.replace('*','').replace('+',''))
                    if not current['width']:
                        current['width'] = int(mm.group(1))
                        current['height'] = int(mm.group(2))
                except ValueError:
                    pass

outputs = [o for o in outputs if o['width'] and o['height']]
if not outputs:
    sys.exit(1)
if mode == 'primary':
    selected = next((o for o in outputs if o['primary']), outputs[0])
elif mode == 'best':
    selected = sorted(outputs, key=lambda o: (o['refresh'], o['width'] * o['height'], o['primary']), reverse=True)[0]
else:
    selected = next((o for o in outputs if o['name'] == mode), None)
    if selected is None:
        print(f'unknown monitor connector: {mode}', file=sys.stderr)
        sys.exit(2)
print(f"{selected['name']} {selected['width']} {selected['height']} {selected['refresh']:.2f}")
PY
  local status=$?
  rm -f "$tmp"
  return "$status"
}

detect_monitor() {
  if [ -n "${GAMESCOPE_OUTPUT_WIDTH:-}" ] && [ -n "${GAMESCOPE_OUTPUT_HEIGHT:-}" ]; then
    printf 'env %s %s %s\n' "$GAMESCOPE_OUTPUT_WIDTH" "$GAMESCOPE_OUTPUT_HEIGHT" "${GAMESCOPE_REFRESH:-144}"
    return 0
  fi
  monitor_from_xrandr "$MONITOR_MODE"
}

detect_vulkan_device() {
  if [ -n "${GAMESCOPE_VK_DEVICE:-}" ]; then
    printf '%s\n' "$GAMESCOPE_VK_DEVICE"
    return 0
  fi

  # Prefer the main NVIDIA card for this machine. This avoids gamescope picking Intel iGPU.
  local line
  line="$(lspci -Dnn 2>/dev/null | grep -Ei 'VGA|3D|Display' | grep -i 'NVIDIA' | head -n1 || true)"
  if [ -z "$line" ]; then
    line="$(lspci -Dnn 2>/dev/null | grep -Ei 'VGA|3D|Display' | grep -vi 'Intel' | head -n1 || true)"
  fi
  if [ -z "$line" ]; then
    line="$(lspci -Dnn 2>/dev/null | grep -Ei 'VGA|3D|Display' | head -n1 || true)"
  fi
  if [[ "$line" =~ \[([0-9a-fA-F]{4}):([0-9a-fA-F]{4})\] ]]; then
    printf '%s:%s\n' "${BASH_REMATCH[1],,}" "${BASH_REMATCH[2],,}"
    return 0
  fi
  return 1
}

display_index_for_monitor() {
  local connector="$1" tmp status
  tmp="$(mktemp)"
  xrandr --query >"$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  python3 - "$connector" "$tmp" <<'PY'
import re
import sys
wanted, path = sys.argv[1:]
index = 0
for line in open(path, encoding='utf-8', errors='replace'):
    m = re.match(r'^(\S+) connected\b', line)
    if not m:
        continue
    if m.group(1) == wanted:
        print(index)
        sys.exit(0)
    index += 1
sys.exit(1)
PY
  status=$?
  rm -f "$tmp"
  return "$status"
}

build_launch_options() {
  local base
  if [ "$MODE" = "native" ]; then
    base="-freq 144 -fullscreen -w 1920 -h 1080 -console -novid -nojoy -high +exec autoexec"
    [ -z "$EXTRA_CS2_ARGS" ] || base="$base $EXTRA_CS2_ARGS"
    printf '%s\n' "$base"
    return 0
  fi

  # gamescope owns the fullscreen 4:3 scaled window, so do not pass CS2's own
  # -fullscreen/-w/-h here. That keeps the desktop resolution unchanged while
  # alt-tabbing and avoids the small-window Linux fullscreen path.
  base="-freq 144 -console -novid -nojoy -high +exec autoexec"
  [ -z "$EXTRA_CS2_ARGS" ] || base="$base $EXTRA_CS2_ARGS"

  local monitor name width height refresh vk_device display_index display_arg=()
  monitor="$(detect_monitor)" || cs2_die "could not detect monitor via xrandr; set GAMESCOPE_OUTPUT_WIDTH/GAMESCOPE_OUTPUT_HEIGHT"
  read -r name width height refresh <<<"$monitor"
  vk_device="$(detect_vulkan_device || true)"
  display_index="$(display_index_for_monitor "$name" || true)"

  log "Selected monitor for gamescope fullscreen window: $name ${width}x${height}@${refresh}Hz" >&2
  if [ -n "$display_index" ]; then
    log "Selected gamescope display index: $display_index" >&2
    display_arg=(--display-index "$display_index")
  fi

  if [ -n "$vk_device" ]; then
    log "Selected Vulkan device: $vk_device" >&2
    printf 'gamescope --prefer-vk-device %s -f -b --force-windows-fullscreen -r 144 -w 1280 -h 960 -W %s -H %s -S stretch %s-- %%command%% %s\n' "$vk_device" "$width" "$height" "${display_arg[*]:+${display_arg[*]} }" "$base"
  else
    warn "could not detect Vulkan device; gamescope may pick the wrong GPU"
    printf 'gamescope -f -b --force-windows-fullscreen -r 144 -w 1280 -h 960 -W %s -H %s -S stretch %s-- %%command%% %s\n' "$width" "$height" "${display_arg[*]:+${display_arg[*]} }" "$base"
  fi
}

install_config() {
  [ "$INSTALL_CONFIG" -eq 1 ] || return 0
  log "Installing CS2 config..."
  if [ "$DRY_RUN" -eq 1 ]; then
    ./install.sh --dry-run
  else
    ./install.sh
  fi
}

set_launch_options() {
  [ "$SET_LAUNCH_OPTIONS" -eq 1 ] || return 0

  stop_steam_for_localconfig

  local localconfig launch_options
  localconfig="$(find_localconfig)"
  launch_options="$(build_launch_options)"

  log "Setting Steam LaunchOptions for app $APPID:"
  log "$launch_options"
  python3 "$SCRIPT_DIR/scripts/set-steam-launch-options.py" \
    --localconfig "$localconfig" \
    --appid "$APPID" \
    --launch-options "$launch_options" \
    $([ "$DRY_RUN" -eq 1 ] && printf '%s' '--dry-run')

  restart_steam_if_needed
}

install_config
ensure_gamescope
set_launch_options

log "Done. Launch Counter-Strike 2 from Steam."
