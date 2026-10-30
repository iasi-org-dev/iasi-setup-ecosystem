# Generic two-phase catalogue executor. Invoke in the real user's elevated session.
#requires -RunAsAdministrator
param([Parameter(Mandatory)][string]$ConfigDir)
$ErrorActionPreference = 'Stop'
$catalog = Join-Path $ConfigDir 'config-data'
$software = Join-Path $PSScriptRoot 'install-software.ps1'
$postinstall = Join-Path $PSScriptRoot 'install-postinstall.ps1'
& $software -Manifest (Join-Path $catalog 'packages.toml')
if (-not $?) { throw 'IASI software phase failed' }
$wslScript = Join-Path $ConfigDir 'services\wsl.ps1'
if (Test-Path -LiteralPath $wslScript) {
    & $wslScript
    if (-not $?) { throw 'IASI WSL phase failed' }
}
& $postinstall -Manifest (Join-Path $catalog 'postinstall.toml')
if (-not $?) { throw 'IASI postinstall phase failed' }
Write-Host 'IASI software and postinstall phases verified.'
