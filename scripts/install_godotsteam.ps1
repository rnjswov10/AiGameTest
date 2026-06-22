param(
    [string]$VersionTag = "v4.19.1"
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir "..")).Path
}

function Download-FileIfMissing {
    param(
        [string]$Url,
        [string]$OutputPath
    )

    if (Test-Path $OutputPath) {
        Write-Host "Using existing download: $OutputPath"
        return
    }

    Write-Host "Downloading: $Url"
    Invoke-WebRequest -Uri $Url -OutFile $OutputPath
}

function Expand-TarArchive {
    param(
        [string]$ArchivePath,
        [string]$DestinationPath,
        [string]$ExpectedPath
    )

    if ($ExpectedPath -and (Test-Path $ExpectedPath)) {
        Write-Host "Using existing extracted files: $DestinationPath"
        return
    }

    New-Item -ItemType Directory -Force -Path $DestinationPath | Out-Null
    tar -xf $ArchivePath -C $DestinationPath
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to extract archive: $ArchivePath"
    }
}

function Install-TemplateAliases {
    param(
        [string]$RepoRoot
    )

    $editorDir = Join-Path $RepoRoot "tools\godotsteam\editor"
    $sourceDir = Join-Path $RepoRoot "tools\godotsteam\templates\win64"
    $targetDir = Join-Path $editorDir "editor_data\export_templates\4.6.3.stable"

    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceDir "godotsteam.463.template.win64.exe") -Destination (Join-Path $targetDir "windows_release_x86_64.exe") -Force
    Copy-Item -LiteralPath (Join-Path $sourceDir "godotsteam.463.debug.template.win64.exe") -Destination (Join-Path $targetDir "windows_debug_x86_64.exe") -Force
    Copy-Item -LiteralPath (Join-Path $sourceDir "steam_api64.dll") -Destination (Join-Path $targetDir "steam_api64.dll") -Force
    "4.6.3.stable" | Set-Content -Path (Join-Path $targetDir "version.txt") -NoNewline
}

$repoRoot = Get-RepoRoot
$downloadDir = Join-Path $repoRoot "tools\godotsteam\downloads"
$editorDir = Join-Path $repoRoot "tools\godotsteam\editor"
$templateDir = Join-Path $repoRoot "tools\godotsteam\templates"

New-Item -ItemType Directory -Force -Path $downloadDir, $editorDir, $templateDir | Out-Null

$editorUrl = "https://codeberg.org/godotsteam/godotsteam/releases/download/$VersionTag/win64-g463-s164-gs4191-editor.tar.xz"
$templateUrl = "https://github.com/GodotSteam/GodotSteam/releases/download/$VersionTag/godotsteam-g462-s164-gs4191-templates.tar.xz"
$editorArchive = Join-Path $downloadDir "win64-g463-s164-gs4191-editor.tar.xz"
$templateArchive = Join-Path $downloadDir "godotsteam-g462-s164-gs4191-templates.tar.xz"

Download-FileIfMissing -Url $editorUrl -OutputPath $editorArchive
Download-FileIfMissing -Url $templateUrl -OutputPath $templateArchive

Expand-TarArchive -ArchivePath $editorArchive -DestinationPath $editorDir -ExpectedPath (Join-Path $editorDir "godotsteam.463.editor.win64.console.exe")
Expand-TarArchive -ArchivePath $templateArchive -DestinationPath $templateDir -ExpectedPath (Join-Path $templateDir "win64\godotsteam.463.template.win64.exe")

New-Item -ItemType File -Force -Path (Join-Path $editorDir "_sc_") | Out-Null
Install-TemplateAliases -RepoRoot $repoRoot

Write-Host "GodotSteam installed under tools\godotsteam."
Write-Host "Editor: tools\godotsteam\editor\godotsteam.463.editor.win64.exe"
Write-Host "Console: tools\godotsteam\editor\godotsteam.463.editor.win64.console.exe"
