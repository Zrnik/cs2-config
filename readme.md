# CS2 Config

Personal Counter-Strike 2 configuration with keybinds, crosshair recoil modes, practice setup, and utility scripts.

## Automatic Setup

On Debian/Linux Steam, use:

```bash
./setup.sh
```

It installs `autoexec.cfg` + `custom_cfg/` and writes native 1920x1080 CS2 LaunchOptions into Steam's `localconfig.vdf`. If Steam is running, setup stops it before editing `localconfig.vdf` and starts it again afterwards so Steam does not overwrite the change.

`./setup.sh --gamescope` / `./setup.sh --stretched` keeps desktop resolution unchanged and uses gamescope as an external 4:3 scaler, but it is experimental on this machine: CS2 currently segfaults shortly after launch under gamescope. The removed KDE/X11 display-mode switching approach is intentionally not used because it shrinks the desktop while Alt-Tabbing.

Default monitor selection is `--monitor best`, which picks the enabled display with the highest current refresh rate. On this setup that selects the AOC 1920x1080@144Hz display. To force KDE/X11 primary monitor or a connector explicitly:

```bash
./setup.sh --monitor primary
./setup.sh --monitor HDMI-A-6
```

Useful modes:

```bash
./setup.sh --dry-run
./setup.sh --stretched
./setup.sh --gamescope
./setup.sh --native
./setup.sh --no-restart-steam
./setup.sh --no-launch-options
./setup.sh --no-install-gamescope
```

Use `--no-restart-steam` if you want setup to refuse while Steam is running instead of stopping and starting it automatically. Use `--force-steam-running` only for diagnostics/dry-runs.

Setup normally handles Steam automatically: it stops Steam before editing `localconfig.vdf`, then starts Steam again. If Steam was not running, it is left stopped.

## Launch Options

Manual reference. Set this in Steam: *Library -> Counter-Strike 2 -> Properties -> Launch Options*.

### Windows: native 1920x1080 fullscreen

Use native 16:9 fullscreen instead of forced 4:3 stretched:

```text
-freq 144 -fullscreen -w 1920 -h 1080 -console -novid -nojoy -high +exec autoexec
```

### Debian/Linux: native 1920x1080 safe default

Linux CS2 exposes **Windowed** and **Fullscreen Windowed**, not Windows-style true exclusive fullscreen. Use native 16:9 output to avoid the blocky 4:3 compositor scaling and Alt-Tab freezes seen with low stretched resolutions:

```text
-freq 144 -fullscreen -w 1920 -h 1080 -console -novid -nojoy -high +exec autoexec
```

Do **not** use `-w 1280 -h 960` or lower 4:3 modes with CS2's Linux fullscreen-windowed mode unless you are also using an external scaler. On Linux it can look blocky, start as a small surface, black-screen, or freeze after Alt-Tab.

### Debian/Linux: 4:3 stretched via gamescope

For 1280x960 stretched output on Linux without changing desktop resolution, gamescope is the right class of external scaler, but on this machine CS2 currently segfaults under gamescope. Keep this as an experimental reference, not the default:

```text
gamescope --prefer-vk-device 10de:2805 -f -b --force-windows-fullscreen -r 144 -w 1280 -h 960 -W 1920 -H 1080 -S stretch --display-index 0 -- %command% -freq 144 -console -novid -nojoy -high +exec autoexec
```

Adjust `-W`/`-H` to your monitor's native resolution, for example:

```text
# 2560x1440 monitor
gamescope --prefer-vk-device 10de:2805 -f -b --force-windows-fullscreen -r 144 -w 1280 -h 960 -W 2560 -H 1440 -S stretch --display-index 0 -- %command% -freq 144 -console -novid -nojoy -high +exec autoexec
```

`--prefer-vk-device 10de:2805` forces gamescope to use the NVIDIA RTX 4060 Ti. Without it, Steam can start gamescope on the Intel iGPU and gamescope may abort with `Assertion 'modifiers.size() > 0' failed` before CS2 starts. `--force-windows-fullscreen` makes CS2 fill the nested gamescope surface instead of opening as a small inner window. `--display-index 0` targets the first connected display; remove it or rerun setup with `--monitor primary` if the fullscreen gamescope window appears on the wrong monitor.

Do not add CS2's own `-w 1280 -h 960` after `%command%` when using gamescope; gamescope already controls the render size with its own `-w`/`-h`.

### Installing gamescope on Debian

Check whether it is already installed:

```bash
command -v gamescope
```

Try the normal distro package first:

```bash
sudo apt update
apt-cache policy gamescope
sudo apt install gamescope
```

On Debian 13 (trixie), `gamescope` may be available from `trixie-backports` rather than the base repository. If `apt-cache policy gamescope` shows `Candidate: (none)`, enable backports and install from there:

```bash
echo 'deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware' \
  | sudo tee /etc/apt/sources.list.d/trixie-backports.list
sudo apt update
apt-cache policy gamescope
sudo apt install -t trixie-backports gamescope
```

If backports still does not provide `gamescope`, install it from another repository that provides it for your Debian version, or build it from Valve's upstream source:

```bash
git clone --recursive https://github.com/ValveSoftware/gamescope.git
cd gamescope
git submodule update --init
meson setup build/
ninja -C build/
sudo meson install -C build/ --skip-subprojects
```

Upstream build dependencies change over time; if `meson setup` reports missing packages, install the named `-dev` packages from Debian and rerun the command.

## FPS & Performance

### Debian/Linux display mode

On Linux, CS2 does not expose the same true exclusive fullscreen mode as Windows. The useful modes are **Windowed** and **Fullscreen Windowed**. Use native 1920x1080 for normal play.

Display mode is not a good fit for `autoexec.cfg`: it is applied before/around engine startup, and changing it after launch can cause a black screen on Linux. Prefer launch options or `gamescope`.

### NVIDIA Control Panel

Go to *Manage 3D Settings → Program Settings → CS2*:

| Setting | Value |
|---------|-------|
| Preferred graphics processor | **High-performance NVIDIA** (not Intel UHD 770!) |
| Power Management Mode | **Prefer Maximum Performance** |
| Low Latency Mode | **Ultra** |
| Vertical Sync | **Off** |

### In-game Video Settings

| Setting | Value |
|---------|-------|
| Display Mode | Fullscreen / Fullscreen Windowed at 1920x1080 |
| Global Shadow Quality | High |
| Model / Texture Detail | Low |
| Shader Detail | Low |
| Particle Detail | Low |
| VSync | Off |
| NVIDIA Reflex | Enabled |
| Boost Player Contrast | On |

## Config Structure

`autoexec.cfg` is the entry point — it unbinds everything and loads configs from `custom_cfg/`:

```
autoexec.cfg
  custom_cfg/crosshair.cfg
  custom_cfg/movement.cfg
  custom_cfg/model.cfg
  custom_cfg/common.cfg
  custom_cfg/buy.cfg
  custom_cfg/misc.cfg
  custom_cfg/fps.cfg
  custom_cfg/walk/initialize.cfg
  custom_cfg/practice/binds.cfg
  custom_cfg/crosshair_state.cfg
```

Press `F6` to reload the config at any time.

## Features

### Movement

| Key | Action |
|---|---|
| WASD | Move |
| Space / Scroll Up / Scroll Down | Jump |
| Ctrl | Crouch |
| Shift | Walk (see [Walk System](#walk-system)) |

- **Sensitivity:** 2
- **Zoom sensitivity:** 0.818933 (1:1 scoped feel)

### Crosshair

Static crosshair (style 4) with custom size, color, and outline. The config includes a recoil-follow mode system that changes how the crosshair tracks recoil:

- **Rifle mode** (`Numpad +`, default) — crosshair follows recoil spray only while holding mouse1, then snaps back when you release. Good for seeing where your rifle spray is landing.
- **Pistol mode** (`Numpad -`) — recoil follow is always on (no snap-back). Crosshair stays where it drifts. A center dot appears as a visual indicator that pistol mode is active.
- **Static mode** (`Numpad *`) — recoil follow is always off. The crosshair stays static and switches to a slightly different color.

### Buy Binds

| Key | Buy | Also does |
|---|---|---|
| F1 | Kevlar vest | Vote Yes |
| F2 | Rifle (team default) | Vote No |
| F3 | Smoke + HE grenade | — |
| F4 | Defuse kit + Flashbang | — |
| F5 | Kevlar + Helmet | — |

### Quick Grenades

| Key | Grenade |
|---|---|
| F | Flashbang |
| MOUSE4 | Smoke |
| C | HE grenade |

### Common Binds

| Key | Action |
|---|---|
| E | Use |
| R | Reload |
| G | Drop weapon |
| Q | Last weapon (quick switch) |
| V | Toggle voice chat on/off |
| MOUSE5 | Push-to-talk |
| MOUSE3 | Player ping |
| T | Spray menu |
| TAB | Scoreboard |
| X | Radio menu |
| B | Buy menu |
| M | Team menu |
| DEL | Disconnect |
| 1-5 | Weapon slots (primary, secondary, knife, grenades, bomb) |

### Walk System

Shift does more than just walk — it's a multi-action modifier:

**While holding Shift:**
- Walk (slow movement)
- Volume increases by +0.5 (from 0.5 to 1.0) to hear footsteps better
- Enter key switches to all-chat (`messagemode`)

**When Shift is released:**
- Normal run speed
- Volume returns to 0.5
- Enter key switches back to team-chat (`messagemode2`)

### Viewmodel

Left-side shifted viewmodel with FOV 60 (`viewmodel_offset_x -1`, `viewmodel_offset_y -2`, `viewmodel_offset_z -2`).

### Network / Misc

- `cl_interp_ratio 1` — interpolation ratio
- `mm_dedicated_search_maxping 35` — low ping matchmaking

## Practice Mode

Press `HOME` to activate practice mode on a local server. Sets up a full practice environment:

- Cheats enabled, infinite ammo, unlimited money ($60,000)
- Buy anywhere, no round time limit, no freeze time
- Grenade trajectories and impact markers visible
- One bot added and frozen for reference

### Practice Binds

| Key | Action |
|---|---|
| INS | Noclip (fly through walls) |
| PGUP | Give all grenade types |
| Numpad 0 | Rethrow last grenade |
| Numpad 5 | Toggle bot freeze |
| Numpad 7 | Clear all grenade projectiles |

## Scripts

### install.sh — Debian / Linux Steam

Installs this config into CS2's `game/csgo/cfg` directory:

```bash
./install.sh
```

The script auto-detects CS2 installed through Steam on Debian/Linux and copies only:

- `autoexec.cfg`
- `custom_cfg/`

Preview the target without copying:

```bash
./install.sh --dry-run
./install.sh --print-target
```

If Steam or CS2 is in a non-standard location, pass a Linux path manually:

```bash
CS2_ROOT="$HOME/.local/share/Steam/steamapps/common/Counter-Strike Global Offensive" ./install.sh
CS2_CFG="/path/to/Counter-Strike Global Offensive/game/csgo/cfg" ./install.sh
```

### demos.sh — Debian / Linux Steam

Requires `zstd`:

```bash
sudo apt install zstd
```

Processes downloaded demo files (`.dem.zst`) from `~/Downloads`:

```bash
./demos.sh
```

What it does:

1. Auto-detects CS2 installed through Steam on Debian/Linux
2. Deletes loose `.dem` files from Downloads, matching `demos.cmd` behavior
3. Decompresses all `.dem.zst` files to CS2's `game/csgo` folder
4. Deletes successfully processed `.dem.zst` files from Downloads
5. Lists available demos with `playdemo` commands sorted newest-first

Use a custom downloads folder:

```bash
DOWNLOADS_DIR=/path/to/downloads ./demos.sh
./demos.sh --source /path/to/downloads
```

Keep loose `.dem` files in Downloads:

```bash
./demos.sh --keep-loose
```

### Windows helpers

`install.cmd` and `demos.cmd` are still available for the old Windows workflow.
