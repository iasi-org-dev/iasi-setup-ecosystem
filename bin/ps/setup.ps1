#requires -RunAsAdministrator
# IASI component orchestrator. Components execute in TOML declaration order.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common\toml.ps1')
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$configuration = $null; $overridePath = $null; $force = $false
for ($i=0; $i -lt $args.Count; $i++) {
    switch ([string]$args[$i]) {
        '--config' { if (++$i -ge $args.Count) { throw 'Missing --config value' }; $configuration = [string]$args[$i] }
        '--path' { if (++$i -ge $args.Count) { throw 'Missing --path value' }; $overridePath = [string]$args[$i] }
        '-f' { $force = $true }
        '-l' { } # Legacy compatibility
        default { throw "Unknown argument: $($args[$i])" }
    }
}
$cwd = (Get-Location).ProviderPath
$entry = if ($configuration) { (Resolve-Path -LiteralPath $configuration -ErrorAction Stop).ProviderPath } else { Join-Path $root 'config\setup.toml' }
if (-not (Test-Path -LiteralPath $entry)) { throw "Configuration missing: $entry" }
$items = @(); $baseDir = $null
if (Test-Path -LiteralPath $entry -PathType Container) {
    $candidate = Join-Path $entry 'setup.toml'
    if (Test-Path $candidate -PathType Leaf) { $entry = $candidate }
    else {
        $single = Join-Path $entry 'config-data\config.toml'
        if (-not (Test-Path $single -PathType Leaf)) { throw "No setup.toml or config-data/config.toml: $entry" }
        $vm = (Read-IasiToml -Path $single)['vm']
        $items = @(@{name=[string]$vm['name']; type='hyper-v'; config=$entry})
    }
}
if (Test-Path -LiteralPath $entry -PathType Leaf) {
    $baseDir = Split-Path -Parent $entry
    $manifest = Read-IasiToml -Path $entry
    if ($manifest.Contains('components')) { $items = @($manifest['components']) }
    elseif ($manifest.Contains('hyperv')) { $items = @(@{name='hyperv';type='host';config=$entry}) }
    elseif ($manifest.Contains('wsl')) { $items = @(@{name='wsl';type='wsl';config=$entry}) }
    elseif ($manifest.Contains('network')) { $items = @(@{name='iasi-net';type='network';config=$entry}) }
    elseif ($manifest.Contains('vm')) { $items = @(@{name=[string]$manifest['vm']['name'];type='hyper-v';config=(Split-Path -Parent (Split-Path -Parent $entry))}) }
    else { throw "Unknown configuration format: $entry" }
}
if (-not $items.Count) { throw 'No components selected.' }
# Path can be declared in hyperv.toml; CLI override takes precedence.
$hypervFile = Join-Path $root 'config\hyperv.toml'
$vmPath = 'C:\Machines'
if (Test-Path -LiteralPath $hypervFile) {
    $h = (Read-IasiToml -Path $hypervFile)['hyperv']
    if ($h -and $h.Contains('path')) { $vmPath = [string]$h['path'] }
}
if ($overridePath) { $vmPath = $overridePath }
if (-not [IO.Path]::IsPathRooted($vmPath)) { $vmPath = [IO.Path]::GetFullPath((Join-Path $cwd $vmPath)) }
if ($force) { Write-Warning '-f: selected VMs and network may be destructively recreated; existing WSL instances are NEVER overwritten.' }
foreach ($item in $items) {
    if ($item.Contains('enabled') -and -not [bool]$item['enabled']) { continue }
    $name=[string]$item['name']; $type=[string]$item['type']; $rel=[string]$item['config']
    if (-not $name -or -not $type -or -not $rel) { throw 'Each component requires name, type and config.' }
    $path = if ([IO.Path]::IsPathRooted($rel)) { $rel } elseif ($baseDir) { Join-Path $baseDir $rel } else { Join-Path $cwd $rel }
    $path = (Resolve-Path -LiteralPath $path -ErrorAction Stop).ProviderPath
    Write-Host "`n========== IASI: $name ($type) ==========" -ForegroundColor Cyan
    switch ($type) {
        'host' { & (Join-Path $PSScriptRoot 'hyperv-host.ps1') --config $path; if (-not $?) { throw "Host failed: $name" } }
        'wsl'  { & (Join-Path $PSScriptRoot 'wsl.ps1') --config $path; if (-not $?) { throw "WSL failed: $name" } }
        'network' {
            if (-not (Test-Path $path -PathType Leaf)) { throw 'Network requires a TOML file.' }
            $call=@(); if ($force) { $call+='-f' }
            & (Join-Path $PSScriptRoot 'iasi-net.ps1') @call
            if (-not $?) { throw "Network failed: $name" }
        }
        'hyper-v' {
            if (-not (Test-Path $path -PathType Container)) { throw 'VM component requires configuration directory.' }
            $vm=(Read-IasiToml -Path (Join-Path $path 'config-data\config.toml'))['vm']
            $vmName=[string]$vm['name']
            if (-not $vmName) { throw "Missing VM name: $path" }
            $existing=Get-VM -Name $vmName -ErrorAction SilentlyContinue
            if ($existing -and -not $force) { Write-Host "IASI: existing VM preserved: $vmName"; continue }
            $call=@('--config',$path,'--path',$vmPath,'-l'); if ($force) { $call+='-f' }
            & (Join-Path $PSScriptRoot 'hyper-v.ps1') @call
            if (-not $?) { throw "VM provisioning failed: $vmName" }
            Write-Host "IASI: VM provisioned: $vmName (startup independent)." -ForegroundColor Green
        }
        default { throw "Unregistered component adapter: $type ($name)" }
    }
}
Write-Host 'IASI: selected provisioning phases completed.' -ForegroundColor Green
