# Development Setup

## Required Tools

- Git for Windows
- Git LFS
- Godot 4.7.x Standard, with the same patch version for both collaborators
- Cursor with a Godot/GDScript extension for the Cursor + Claude Sonnet workflow
- Codex for Codex-assisted work

## First Clone

```powershell
git clone <github-repo-url>
cd AiGameTest
git lfs install
git lfs pull
```

Open the repository root in Godot. The main scene is `res://scenes/main.tscn`.

## Codex Git Ownership Note

If Codex reports a `dubious ownership` error for this workspace, run this once:

```powershell
git config --global --add safe.directory C:/workspace/project/Other/AiGameTest
```

## External Editor Notes

- Keep Godot open while editing GDScript in Cursor or another VS Code-compatible editor.
- Godot's default GDScript LSP port is `6005`.
- Godot's default debug adapter port is `6006`.
