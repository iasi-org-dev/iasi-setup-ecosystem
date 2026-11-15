#requires -RunAsAdministrator
# IASI: verify or enable the Windows features needed by Hyper-V.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common\toml.ps1')
if ($args.Count -ne 2 -or $args[0] -ne '--config') { throw 'Usage: hyperv-host.ps1 --config <hyperv.toml>' }
$c = Read-IasiToml -Path ([IO.Path]::GetFullPath($args[1]))
if (-not $c.Contains('hyperv')) { throw 'Expected [hyperv].' }
$cfg = $c['hyperv']
$enabled = if ($cfg.Contains('enabled')) { [bool]$cfg['enabled'] } else { $false }
$feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction Stop
if ($feature.State -ne 'Enabled') {
    if (-not $enabled) { throw 'Hyper-V is not enabled and installation is disabled. Enable [hyperv].enabled to authorize it.' }
    Write-Host 'IASI: enabling Hyper-V. A reboot may be required.'
    $result = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart -ErrorAction Stop
    if ($result.RestartNeeded) { throw 'IASI REBOOT REQUIRED: restart Windows and re-run setup.ps1.' }
}
$feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
if ($feature.State -ne 'Enabled') { throw 'Hyper-V feature verification failed.' }
if (-not (Get-Command Get-VMHost -ErrorAction SilentlyContinue)) { throw 'Hyper-V PowerShell module unavailable; reboot may be required.' }
try { $null = Get-VMHost -ErrorAction Stop } catch { throw "Hyper-V is not operational: $($_.Exception.Message)" }
$vmms = Get-Service vmms -ErrorAction Stop
if ($vmms.Status -ne 'Running') { throw 'Hyper-V Virtual Machine Management service is not running.' }
Write-Host 'IASI: Hyper-V ready.' -ForegroundColor Green
