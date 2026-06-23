# Steam 1v1 Networking

This project now has a Steam-ready host-authoritative networking layer.

## Current Architecture

- The host runs the real `MatchController` simulation.
- The client sends only local player commands to the host.
- The host sends match snapshots to the client through Steam P2P.
- If the Steam singleton is missing, the game stays in local 1v1 mode.

This avoids deterministic lockstep problems while the MVP still uses frame delta timers and local RNG.

## Required Plugin

Install the GodotSteam editor and export templates that match the Godot version used by the project.

- GodotSteam project: https://github.com/GodotSteam/GodotSteam
- GodotSteam moved notice / Codeberg link: https://codeberg.org/godotsteam/godotsteam
- Current local Steam build target: `Godot 4.6.3 - Steamworks 1.64 - GodotSteam 4.19.1`.

GodotSteam `v4.19.1` is distributed as a Godot editor/export-template build, not as a regular `addons/` GDExtension plugin. Local binaries are installed under ignored `tools/godotsteam/`:

- `tools/godotsteam/editor/godotsteam.463.editor.win64.console.exe`
- `tools/godotsteam/editor/godotsteam.463.editor.win64.exe`
- `tools/godotsteam/templates/win64/godotsteam.463.template.win64.exe`
- `tools/godotsteam/templates/win64/steam_api64.dll`

The repository tracks the integration scripts and docs, but does not commit these downloaded binaries.

Install or refresh the ignored local GodotSteam files with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_godotsteam.ps1
```

## Local Steam Test App ID

For local testing outside the Steam launcher:

```powershell
Copy-Item steam_appid.example.txt steam_appid.txt
```

`steam_appid.txt` is ignored by Git. The example uses Valve's test App ID `480`.

When exporting with `scripts/export_windows.ps1`, an existing local `steam_appid.txt` is copied next to `builds/AiGameTest.exe`.

When `tools/godotsteam` is present, `scripts/export_windows.ps1` prefers the GodotSteam editor, installs the matching Windows export template into its self-contained editor data, and copies `steam_api64.dll` next to the exported `.exe`.

## Controls

Main menu `Steam 로비` screen:

- `Steam 연결`: Initialize GodotSteam and read the currently logged-in Steam persona name and Steam ID.
- `로비 만들기`: Host a Steam lobby and move into the lobby waiting room. The lobby id is copied to the clipboard.
- `공개 로비 찾기`: Search public Steam lobbies and join the first matching AiGameTest lobby.
- `붙여넣기`: Paste the clipboard lobby id into the read-only lobby id field.
- `참가`: Join the numeric Steam lobby id currently shown in the lobby id field.
- `+ 초대`: Open Steam's invite overlay for the current lobby.
- `코드 복사`: Copy the current lobby id again as a fallback invite path.
- `준비 완료`: Toggle local ready state. The match starts only after both players are ready.
- `로비 나가기`: Leave the current Steam lobby and return to offline menu state.

Lobby creation, public search, and lobby join attempts show a loading screen while waiting for Steam. Failed Steam login, lobby creation, lobby search, lobby join, or invite overlay calls show a failure screen with the Steam status message.

The game does not collect Steam credentials. Steam login happens in the Steam client, and the game only reads the active account through GodotSteam.

When a lobby is created, the host writes these lobby metadata fields:

- `host_name`: Steam persona name shown to joiners.
- `host_id`: Host Steam ID.
- `game_version`: Current game version string.
- `mode`: `1v1`.
- `protocol`: Network protocol version.
- `seed`: Match seed for the hosted session.

Lobby flow:

1. Host clicks `로비 만들기` and waits in the lobby waiting room.
2. Host clicks the `+ 초대` button to open the Steam invite overlay and invite the opponent.
3. As a fallback, host can click `코드 복사` and send the lobby id manually.
4. Client accepts the Steam invite, finds the public lobby, or uses `붙여넣기` and `참가` with a copied lobby id.
5. Both players click `준비 완료`.
6. The host starts the authoritative match and sends the first match snapshot to the client.

In-game Steam buttons:

- `Copy Code`: Copy the current lobby id.
- `Leave`: Leave the Steam lobby and return to the main menu.
- `Restart`: Restart the local match or host match.

Online match controls:

- Host is Player A.
- Client is Player B.
- Each side can use the on-screen `Summon`, `Merge`, `Attack`, and `Boss` buttons.
- Only the host can restart with the on-screen `Restart` button.

## Test Flow

1. Install the GodotSteam 4.6.3 editor/templates under `tools/godotsteam/`.
2. Start Steam on both machines with two different Steam accounts.
3. Create local `steam_appid.txt` from the example, or launch through Steam with a real app id.
4. Host runs the game, opens `Steam 로비`, and clicks `Steam 연결`.
5. The host verifies the displayed Steam persona name and Steam ID.
6. Host clicks `로비 만들기` and moves into the lobby waiting room.
7. Host clicks `+ 초대`, selects a Steam friend, and sends the invite. `코드 복사` can copy the lobby id as a fallback.
8. Client accepts the Steam invite, or opens `Steam 로비`, clicks `Steam 연결`, then clicks `공개 로비 찾기` or uses `붙여넣기` and `참가` with the copied lobby id.
9. Both players click `준비 완료`.
10. Host should enter the match as Player A; client should enter the match as Player B.
11. Client commands should affect Player B on the host, then appear on the client through snapshots.

## Notes

- This is an MVP transport layer, not final rollback/netcode.
- Host authority is intentional for now. It is easier to ship and debug than deterministic lockstep while the rules are still changing.
- Steam binaries and exported `.exe` files should not be committed unless the team explicitly decides to vendor GodotSteam through Git LFS.
