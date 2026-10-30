# Fase 1 Windows: catalogo [SDK], [software], [custom].
# Ejecutar como el usuario de destino (elevado si winget lo exige).
param([Parameter(Mandatory)][string]$Manifest)
$ErrorActionPreference = 'Stop'
# The ISO stages toml.ps1 beside this executor; the source repository
# keeps it under ../common. Support both layouts.
$tomlParser = Join-Path $PSScriptRoot 'toml.ps1'
if (-not (Test-Path -LiteralPath $tomlParser -PathType Leaf)) {
    $tomlParser = Join-Path $PSScriptRoot '..\common\toml.ps1'
}
if (-not (Test-Path -LiteralPath $tomlParser -PathType Leaf)) {
    throw "IASI TOML parser not found: $tomlParser"
}
. $tomlParser
$cfg = Read-IasiToml -Path (Resolve-Path -LiteralPath $Manifest)
$sdk = [string]$cfg['paths']['sdk']
if (-not [IO.Path]::IsPathRooted($sdk)) { throw 'SDK path must be absolute.' }
New-Item -ItemType Directory -Force -Path $sdk | Out-Null
$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $winget) { throw 'winget.exe is unavailable for the active user.' }
foreach ($sectionName in @('SDK','software')) {
    $section = $cfg[$sectionName]
    if (-not $section) { continue }
    foreach ($id in $section.Keys) {
        $enabled = $section[$id]
        if ($enabled -isnot [bool]) { throw "Expected boolean for ${sectionName}:$id" }
        if (-not $enabled) { continue }
        if ($id -notmatch '^[A-Za-z0-9_.-]+$') { throw "Invalid winget package ID: $id" }
        $args = @('install', '--id', $id, '--exact', '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements')
        if ($sectionName -eq 'SDK') {
            # Request a location; the installer may ignore this. No false guarantee.
            $location = Join-Path $sdk $id
            $args += @('--location', $location)
        }
        Write-Host "IASI install [$sectionName]: $id"
        & $winget.Source @args
        if ($LASTEXITCODE -ne 0) { throw "winget failed for $id ($LASTEXITCODE)" }
        Write-Host "IASI installed: $id"
    }
}
if ($cfg.Contains('custom')) {
    foreach ($id in $cfg['custom'].Keys) {
        if ($cfg['custom'][$id] -eq $true) {
            throw "custom package '$id' enabled, but the custom adapter has not been implemented"
        }
    }
}
Write-Host 'IASI Phase 1 completed (winget returned success; install paths still require verification).'
