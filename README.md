# AiGameTest

Godot 4.7.x Standard + GDScript 협업 프로젝트입니다.

## Project Defaults

- Engine: Godot 4.7.x Standard
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

## Quick Start

```powershell
git lfs install
git lfs pull
```

Open this folder in Godot and run `res://scenes/main.tscn`.

## Current MVP

The current prototype is a local 1v1 PvP roguelite tower-defense simulation with staged combat and relic drafting.

- Player A uses the left board.
- Player B uses the right board.
- Click a cell to select it.
- Player A: `Q` summon, `W` merge, `E` send attack wave.
- Player B: `I` summon, `O` merge, `P` send attack wave.
- Player A: `A` summons a challenge boss on the left field.
- Player B: `J` summons a challenge boss on the right field.
- `R` restarts the match.

Towers are colored squares with `Lv1`, `Lv2`, and higher labels. Monsters are colored circles. Your dominant tower color determines the monster type sent to the opponent when using the attack gauge.

Each stage runs combat, cleanup, and then a relic selection phase. Both players choose one of three relics before the next stage starts. Rerolls cost match gold, and Luck can make a reroll free without directly increasing combat stats.

## Collaboration

Read `AGENTS.md` and `docs/workflow.md` before making AI-assisted changes. Generated `.godot/` data is ignored, but Godot `*.import` files must be committed with their source assets.
