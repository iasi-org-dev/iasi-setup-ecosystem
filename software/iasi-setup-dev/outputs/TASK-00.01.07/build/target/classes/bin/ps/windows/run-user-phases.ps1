# IASI Windows user phases. Run INSIDE iasi-dev2 as its interactive administrator.
# Does not create/recreate Hyper-V virtual machines and never runs WSL implicitly.
#requires -RunAsAdministrator
param([Parameter(Mandatory)][string]$ConfigDir)
$ErrorActionPreference = 'Stop'
$ConfigDir = (Resolve-Path -LiteralPath $ConfigDir -ErrorAction Stop).ProviderPath
$catalog = Join-Path $ConfigDir 'config-data'
$softwareManifest = Join-Path $catalog 'packages.toml'
$postManifest = Join-Path $catalog 'postinstall.toml'
foreach ($p in @($softwareManifest, $postManifest)) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { throw "Missing manifest: $p" }
}
$logDir = Join-Path $env:ProgramData 'IASI'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$log = Join-Path $logDir 'user-phases.log'
Start-Transcript -Path $log -Append | Out-Null
try {
    Write-Host 'IASI PHASE 1: declared Windows software (winget)'
    & (Join-Path $PSScriptRoot 'install-software.ps1') -Manifest $softwareManifest
    if (-not $?) { throw 'Windows software phase failed' }

    Write-Host 'IASI PHASE 2: declared post-install (VS Code / optional R / GitHub)'
    & (Join-Path $PSScriptRoot 'install-postinstall.ps1') -Manifest $postManifest
    if (-not $?) { throw 'IASI postinstall failed' }

    Write-Host 'IASI phases completed. Review WARN/UNKNOWN notices before declaring QA PASS.'
}
catch {
    Write-Error "IASI user phases FAIL: $_"
    throw
}
finally {
    Stop-Transcript | Out-Null
    Write-Host "IASI log: $log"
}
