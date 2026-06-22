# AiGameTest

GodotSteam 4.6.3 + GDScript project.

## Project Defaults

- Engine: GodotSteam 4.6.3 for Steam builds, Godot 4.6.x Standard for local-only editing
- Language: GDScript only
- Git host: GitHub
- Workflow: branch + Pull Request
- Codex branch prefix: `codex/<task>`
- Cursor/Claude Sonnet branch prefix: `cursor/<task>`

## Structure

- `project.godot`: Godot project settings
- `scenes/`: Godot scenes
- `scripts/`: GDScript files
- `assets/`: source game assets tracked with Git LFS when binary
- `addons/`: Godot addons
- `docs/`: setup and workflow notes
- `exports/`, `builds/`: local build outputs; contents are ignored by Git
- `tools/`: local editor/template downloads; ignored by Git

## Quick Start

```powershell
git lfs install
git lfs pull
```

Open this folder in GodotSteam 4.6.3 and run `res://scenes/main.tscn`. The game starts at the main menu.

For local Steam testing, create the ignored App ID file:

```powershell
Copy-Item steam_appid.example.txt steam_appid.txt
```

Install the ignored local GodotSteam editor/templates:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_godotsteam.ps1
```

Use `scripts/export_windows.ps1` to export a Windows build. When `tools/godotsteam` is present, the script uses the GodotSteam editor/templates and copies `steam_api64.dll` next to the exported `.exe`.

## Current MVP

The current prototype is a local 1v1 PvP roguelite tower-defense simulation with staged combat, relic drafting, and an optional Steam P2P transport layer.

- Player A uses the left board.
- Player B uses the right board.
- Main menu buttons: `Local 1v1`, `Lobby`, `Settings`, and `Quit`.
- The `Lobby` panel includes `Connect Steam`, `Host Steam`, `Find Public`, `Paste Code`, and direct numeric lobby ID join.
- Steam account login is handled by the Steam client. The game only checks the logged-in Steam account and displays the persona name and Steam ID.
- Settings include fullscreen, borderless window, resolution, VSync, and master volume. They are saved to the local user settings file.
- Click a cell to select it.
- Player A: `Q` summon, `W` merge, `E` send attack wave.
- Player B: `I` summon, `O` merge, `P` send attack wave.
- Player A: `A` summons a challenge boss on the left field.
- Player B: `J` summons a challenge boss on the right field.
- `R` restarts the match.
- Steam lobby controls are available as buttons: `Host`, `Find`, `Join Code`, `Copy Code`, `Leave`, and `Restart`.
- Keyboard shortcuts are still available: `H` host, `L` find lobby, `C` copy lobby id, `V` join clipboard lobby id, `Esc` leave lobby.
- In Steam online mode, host is Player A and client is Player B. Each side can use the player action buttons or `Q`, `W`, `E`, and `A` for their own board.
- Steam lobbies store host metadata: `host_name`, `host_id`, `game_version`, `mode`, `protocol`, and match `seed`.

Towers are colored squares with `Lv1`, `Lv2`, and higher labels. Monsters are colored circles. Your dominant tower color determines the monster type sent to the opponent when using the attack gauge.

Each stage runs combat, cleanup, and then a relic selection phase. Both players choose one of three relics before the next stage starts. Rerolls cost match gold, and Luck can make a reroll free without directly increasing combat stats.

See `docs/steam_networking.md` for GodotSteam setup and online test flow.

## Collaboration

Read `AGENTS.md` and `docs/workflow.md` before making AI-assisted changes. Generated `.godot/` data is ignored, but Godot `*.import` files must be committed with their source assets.
