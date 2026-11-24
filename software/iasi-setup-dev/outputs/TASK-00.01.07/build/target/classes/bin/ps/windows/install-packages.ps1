# Shared Windows package adapter, designed for execution as SYSTEM.
# Apply only declared package IDs and fail explicitly if winget is unavailable.
param([Parameter(Mandatory)][string]$Manifest)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\common\toml.ps1')
$cfg = Read-IasiToml -Path $Manifest
$packages = @($cfg['packages']['items'])
if ($packages.Count -eq 0) { Write-Host 'IASI packages: no additional Windows software declared.'; exit 0 }
$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $winget) { throw 'winget is unavailable in this execution context. Cannot install declared packages.' }
foreach ($id in $packages) {
    if ([string]$id -notmatch '^[A-Za-z0-9_.-]+$') { throw "Unsafe package identifier: $id" }
    & $winget.Source install --id $id --exact --silent --disable-interactivity --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "Package install failed: $id ($LASTEXITCODE)" }
}
