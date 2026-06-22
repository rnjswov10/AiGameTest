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

## Collaboration

Read `AGENTS.md` and `docs/workflow.md` before making AI-assisted changes. Generated `.godot/` data is ignored, but Godot `*.import` files must be committed with their source assets.
