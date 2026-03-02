# CS2 Config

Personal Counter-Strike 2 configuration with keybinds, crosshair recoil modes, practice setup, and utility scripts.

## Launch Options

```
-freq 144 -console -novid +exec autoexec
```

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

Static crosshair (style 4) with custom size, color, and outline. The config includes a **dual recoil-follow mode** system that changes how the crosshair tracks recoil:

- **Rifle mode** (`Numpad +`, default) — crosshair follows recoil spray only while holding mouse1, then snaps back when you release. Good for seeing where your rifle spray is landing.
- **Pistol mode** (`Numpad -`) — recoil follow is always on (no snap-back). Crosshair stays where it drifts. A center dot appears as a visual indicator that pistol mode is active.

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

- `cl_interp_ratio 1` + `cl_interp 0.03125` — reduced interpolation delay
- `fps_max 0` — uncapped framerate
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

### install.cmd

Copies the config files into the CS2 `cfg` folder using robocopy.

```
CS2\game\csgo\cfg\
```

### demos.cmd

Processes downloaded demo files (`.dem.zst`) from your Downloads folder:

1. Auto-downloads [zstd](https://github.com/facebook/zstd) if not present
2. Decompresses all `.dem.zst` files to the CS2 demo folder
3. Deletes loose `.dem` files from Downloads
4. Lists all available demos with `playdemo` commands sorted by date

Steam path is auto-detected from the Windows registry.