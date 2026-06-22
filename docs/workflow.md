# Collaboration Workflow

## Branches

- Codex uses `codex/<task>`.
- Cursor with Claude Sonnet uses `cursor/<task>`.
- `main` is protected and receives changes through Pull Requests.

## Pull Requests

Before opening a PR:

- Open the project in Godot.
- Run `res://scenes/main.tscn`.
- Confirm the Space key triggers the `player_interact` input action.
- Run `git status` and confirm only intended files changed.

## GitHub Repository Settings

- Protect `main`.
- Require Pull Requests before merging.
- Disable direct pushes to `main`.
- Keep the PR template checks current as the project gains export targets or automated tests.

## Conflict Avoidance

- Coordinate before editing the same `.tscn` scene.
- Coordinate before changing `project.godot`, especially Input Map, autoloads, display settings, or export settings.
- Keep scenes small and compose larger features from instanced scenes when possible.
- Commit `*.import` files with their source assets.
- Do not commit generated `.godot/`, `exports/`, or `builds/` contents.
