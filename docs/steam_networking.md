# Steam 1v1 Networking

This project now has a Steam-ready host-authoritative networking layer.

## Current Architecture

- The host runs the real `MatchController` simulation.
- The client sends only local player commands to the host.
- The host sends match snapshots to the client through Steam P2P.
- If the Steam singleton is missing, the game stays in local 1v1 mode.

This avoids deterministic lockstep problems while the MVP still uses frame delta timers and local RNG.

## Required Plugin

Install a GodotSteam GDExtension build that matches the Godot version used by the project.

- GodotSteam project: https://github.com/GodotSteam/GodotSteam
- GodotSteam moved notice / Codeberg link: https://codeberg.org/godotsteam/godotsteam
- The latest GitHub release seen during implementation was `Godot 4.6.3 - Steamworks 1.64 - GodotSteam 4.19.1`.

The project currently runs on Godot `4.7.stable`. Do not commit an incompatible GodotSteam binary just to make the editor load. Use a GodotSteam build compiled for Godot 4.7, or temporarily align the project/editor version with the plugin build in a separate PR.

## Local Steam Test App ID

For local testing outside the Steam launcher:

```powershell
Copy-Item steam_appid.example.txt steam_appid.txt
```

`steam_appid.txt` is ignored by Git. The example uses Valve's test App ID `480`.

When exporting with `scripts/export_windows.ps1`, an existing local `steam_appid.txt` is copied next to `builds/AiGameTest.exe`.

## Controls

Main menu `Lobby` panel:

- `Connect Steam`: Initialize GodotSteam and read the currently logged-in Steam persona name and Steam ID.
- `Host Steam`: Host a Steam lobby. The lobby id is copied to the clipboard.
- `Find Public`: Search public Steam lobbies and join the first matching AiGameTest lobby.
- `Paste Code`: Paste the clipboard lobby id into the lobby id field.
- `Join`: Join the numeric Steam lobby id typed into the field.

The game does not collect Steam credentials. Steam login happens in the Steam client, and the game only reads the active account through GodotSteam.

When a lobby is created, the host writes these lobby metadata fields:

- `host_name`: Steam persona name shown to joiners.
- `host_id`: Host Steam ID.
- `game_version`: Current game version string.
- `mode`: `1v1`.
- `protocol`: Network protocol version.
- `seed`: Match seed for the hosted session.

In-game Steam buttons:

- `Copy Code`: Copy the current lobby id.
- `Leave`: Leave the Steam lobby and return to the main menu.
- `Restart`: Restart the local match or host match.

Keyboard shortcuts are still available: `H`, `L`, `V`, `C`, `Esc`, and `R`.

Online match controls:

- Host is Player A.
- Client is Player B.
- Each side can use the on-screen `Summon`, `Merge`, `Attack`, and `Boss` buttons.
- Keyboard shortcuts are still available: `Q` summon, `W` merge, `E` attack wave, `A` challenge boss.
- Only the host can restart with `R`.

## Test Flow

1. Install a compatible GodotSteam GDExtension in `addons/`.
2. Start Steam on both machines with two different Steam accounts.
3. Create local `steam_appid.txt` from the example, or launch through Steam with a real app id.
4. Host runs the game, opens `Lobby`, and clicks `Connect Steam`.
5. The host verifies the displayed Steam persona name and Steam ID.
6. Host clicks `Host Steam`.
7. Client opens `Lobby`, clicks `Connect Steam`, then either clicks `Find Public`, or receives the copied lobby id, types or pastes it into the lobby id field, and clicks `Join`.
8. Host should see Player A; client should see Player B.
9. Client commands should affect Player B on the host, then appear on the client through snapshots.

## Notes

- This is an MVP transport layer, not final rollback/netcode.
- Host authority is intentional for now. It is easier to ship and debug than deterministic lockstep while the rules are still changing.
- Steam binaries and exported `.exe` files should not be committed unless the team explicitly decides to vendor GodotSteam through Git LFS.
