#requires -RunAsAdministrator
<#
.SYNOPSIS
IASI ecosystem orchestrator. Run without --config from the repo root to load config/setup.toml.
.EXAMPLE
.\bin\ps\setup.ps1 --config .\config --path C:\Maquinas
.EXAMPLE
.\bin\ps\setup.ps1 --config .\config\iasi-dev2 --path C:\Maquinas -f
.NOTES
-f deliberately recreates ALL selected Hyper-V VMs. Without --config, this includes the entire ecosystem. DESTRUCTIVE.
#>
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common\toml.ps1')
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$configuration = $null
$vmPath = (Get-Location).Path
$force = $false
for ($i=0; $i -lt $args.Count; $i++) {
    switch ([string]$args[$i]) {
        '--config' { if (++$i -ge $args.Count) { throw 'Missing --config value' }; $configuration = [string]$args[$i] }
        '--path'   { if (++$i -ge $args.Count) { throw 'Missing --path value' }; $vmPath = [string]$args[$i] }
        '-f'       { $force = $true }
        '-l'       { } # Legacy compatibility: all VM provisioning is now no-launch.
        default    { throw "Unknown argument: $($args[$i])" }
    }
}
if ($force) { Write-Warning 'DESTRUCTIVE MODE (-f): each selected Hyper-V VM and its disks may be deleted and recreated.' }
# Resolve either a single VM configuration or an ordered setup.toml directory.
# Defaults to the current working directory; a repository root may contain ./config/setup.toml.
$workingDir = (Get-Location).ProviderPath
$configInput = if ($configuration) { $configuration } else { $workingDir }
# Resolve-Path uses the current PowerShell location (unlike .NET's process cwd).
try {
    $cpath = (Resolve-Path -LiteralPath $configInput -ErrorAction Stop).ProviderPath
} catch {
    throw "Unknown configuration directory: $configInput (PowerShell cwd: $workingDir)"
}
if (-not (Test-Path -LiteralPath $cpath -PathType Container)) {
    throw "Configuration must be a directory: $cpath"
}
# --path describes the destination, not the configuration root.
# Resolve relative paths against the caller's PowerShell location.
if (-not [IO.Path]::IsPathRooted($vmPath)) {
    $vmPath = [IO.Path]::GetFullPath((Join-Path $workingDir $vmPath))
}
$manifestDir = $cpath
$manifest = Join-Path $manifestDir 'setup.toml'
$single = Join-Path $cpath 'config-data\config.toml'
if (-not (Test-Path -LiteralPath $manifest -PathType Leaf) -and -not (Test-Path -LiteralPath $single -PathType Leaf) -and -not $configuration) {
    $manifestDir = Join-Path $cpath 'config'
    $manifest = Join-Path $manifestDir 'setup.toml'
}
if (Test-Path -LiteralPath $manifest -PathType Leaf) {
    $plan = Read-IasiToml -Path $manifest
    if (-not $plan.Contains('components') -or @($plan['components']).Count -eq 0) { throw "setup.toml requires [[components]]: $manifest" }
    $items = @($plan['components'])
    $baseDir = $manifestDir
} elseif (Test-Path -LiteralPath $single -PathType Leaf) {
    $details = Read-IasiToml -Path $single
    if (-not $details.Contains('vm')) { throw "Missing [vm] in $single" }
    $name = [string]$details['vm']['name']
    if (-not $name) { throw "Missing [vm].name in $single" }
    $componentType = 'hyper-v'
    if ($details['vm'].Contains('type')) { $componentType = [string]$details['vm']['type'] }
    # Standalone Hyper-V VM also needs the shared network before deployment.
    $items = @(
        @{ name = 'iasi-net'; type = 'network'; config = (Join-Path $root 'config\iasi-net.toml') },
        @{ name = $name; type = $componentType; config = $cpath }
    )
    $baseDir = $null
} else {
    throw "No setup.toml or config-data/config.toml found at $cpath"
}

function Invoke-IasiHyperVComponent {
    param([string]$Name, [string]$ConfigDir, [bool]$Recreate)
    $conf = Read-IasiToml -Path (Join-Path $ConfigDir 'config-data\config.toml')
    $vm = $conf['vm']; $vmName = [string]$vm['name']
    if (-not $vmName) { throw "Missing VM name for component $Name" }
    $existing = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if ($existing -and -not $Recreate) {
        Write-Host "IASI: existing VM $vmName preserved (no -f)." -ForegroundColor DarkYellow
        return
    }
    $call = @('--config', $ConfigDir, '--path', $vmPath, '-l')
    if ($Recreate) { $call += '-f' }
    & (Join-Path $PSScriptRoot 'hyper-v.ps1') @call
    if (-not $?) { throw "hyper-v.ps1 failed for $vmName" }
    Write-Host "IASI: $vmName provisioned; VM left powered off." -ForegroundColor Green
}

foreach ($item in $items) {
    $name = [string]$item['name']
    $type = [string]$item['type']
    if (-not $name -or -not $type -or -not $item['config']) { throw 'Each component requires name, type and config.' }
    $relative = [string]$item['config']
    $dir = if ([IO.Path]::IsPathRooted($relative)) { $relative } elseif ($baseDir) { Join-Path $baseDir $relative } else { $relative }
    if (-not [IO.Path]::IsPathRooted($dir)) { $dir = Join-Path $workingDir $dir }
    $dir = (Resolve-Path -LiteralPath $dir -ErrorAction Stop).ProviderPath
    if ($type -eq 'network') {
        if (-not (Test-Path -LiteralPath $dir -PathType Leaf)) { throw "Network configuration missing: $dir" }
    } elseif (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        throw "Component '$name' configuration missing: $dir"
    }
    Write-Host "`n========== IASI component: $name ($type) ==========" -ForegroundColor Cyan
    switch ($type) {
        'network' {
            $call = @()
            if ($force) { $call += '-f' }
            & (Join-Path $PSScriptRoot 'iasi-net.ps1') @call
            if (-not $?) { throw "iasi-net.ps1 failed for $name" }
        }
        'hyper-v' { Invoke-IasiHyperVComponent -Name $name -ConfigDir $dir -Recreate $force }
        default { throw "Unregistered setup component adapter: $type ($name)" }
    }
}
Write-Host "`nIASI infrastructure provisioned. VM startup and guest installation are independent." -ForegroundColor Green
