param(
    [string]$GodotPath = $env:GODOT_BIN,
    [string]$Preset = "Windows Desktop",
    [string]$OutputPath = "builds/AiGameTest.exe"
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..")).Path
}

function Get-GodotExecutable {
    param([string]$CandidatePath)

    if ($CandidatePath -and (Test-Path $CandidatePath)) {
        return (Resolve-Path $CandidatePath).Path
    }

    $commandNames = @("godot4.7", "godot4", "godot")
    foreach ($commandName in $commandNames) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    $searchRoots = @(
        (Join-Path (Get-RepoRoot) "tools"),
        (Join-Path $env:LOCALAPPDATA "Programs\Godot"),
        (Join-Path $env:ProgramFiles "Godot")
    )

    foreach ($root in $searchRoots) {
        if (-not (Test-Path $root)) {
            continue
        }

        $matches = @(Get-ChildItem -Path $root -Recurse -Filter "Godot*.exe" -ErrorAction SilentlyContinue)
        $consoleMatches = @($matches | Where-Object { $_.Name -like "*console.exe" })
        foreach ($match in $consoleMatches) {
            return $match.FullName
        }
        foreach ($match in $matches) {
            return $match.FullName
        }
    }

    throw "Godot executable not found. Install Godot or pass -GodotPath / set GODOT_BIN."
}

function Initialize-PortableGodot {
    param(
        [string]$GodotExecutable,
        [string]$RepoRoot
    )

    $godotDir = Split-Path -Parent $GodotExecutable
    $selfContainedMarker = Join-Path $godotDir "_sc_"
    if (-not (Test-Path $selfContainedMarker)) {
        New-Item -ItemType File -Force -Path $selfContainedMarker | Out-Null
    }

    $templateSource = Join-Path $RepoRoot "tools\godot\templates\templates"
    $templateTarget = Join-Path $godotDir "editor_data\export_templates\4.7.stable"
    if ((Test-Path $templateSource) -and (-not (Test-Path (Join-Path $templateTarget "windows_release_x86_64.exe")))) {
        New-Item -ItemType Directory -Force -Path $templateTarget | Out-Null
        Copy-Item -Path (Join-Path $templateSource "*") -Destination $templateTarget -Recurse -Force
    }
}

function Copy-SteamAppIdIfPresent {
    param(
        [string]$RepoRoot,
        [string]$OutputDirectory
    )

    $appIdSource = Join-Path $RepoRoot "steam_appid.txt"
    if (-not (Test-Path $appIdSource)) {
        return
    }

    Copy-Item -LiteralPath $appIdSource -Destination (Join-Path $OutputDirectory "steam_appid.txt") -Force
}

$repoRoot = Get-RepoRoot
$godot = Get-GodotExecutable -CandidatePath $GodotPath
$resolvedOutput = Join-Path $repoRoot $OutputPath
$outputDir = Split-Path -Parent $resolvedOutput

Initialize-PortableGodot -GodotExecutable $godot -RepoRoot $repoRoot

if (-not (Test-Path (Join-Path $repoRoot "project.godot"))) {
    throw "project.godot was not found at $repoRoot"
}

if (-not (Test-Path (Join-Path $repoRoot "export_presets.cfg"))) {
    throw "export_presets.cfg was not found at $repoRoot"
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

Write-Host "Using Godot: $godot"
Write-Host "Export preset: $Preset"
Write-Host "Output: $resolvedOutput"

& $godot --headless --path $repoRoot --export-release $Preset $resolvedOutput

if ($LASTEXITCODE -ne 0) {
    throw "Godot export failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $resolvedOutput)) {
    throw "Godot export completed but output file was not created: $resolvedOutput"
}

Copy-SteamAppIdIfPresent -RepoRoot $repoRoot -OutputDirectory $outputDir

Write-Host "Export complete: $resolvedOutput"
