#requires -RunAsAdministrator
<#
.SYNOPSIS
    Read-only IASI GPU-P inventory and explainable candidate selection test.
.DESCRIPTION
    Discovers partitionable devices, correlates them with Windows display controllers
    and PnP devices, filters non-GPU accelerators, and explains a conservative V1
    choice. No Hyper-V configuration, VM, adapter or driver is modified.

    This is HOST-SIDE selection only. Guest Linux GPU-P and inference support
    cannot be demonstrated by this test.
.EXAMPLE
    .\iasi-gpu-select-test.ps1
    .\iasi-gpu-select-test.ps1 -AllowIntegrated
    .\iasi-gpu-select-test.ps1 -Selector 'PCI\VEN_10DE&DEV_...\...'
.NOTES
    PowerShell 5.1+, Windows host with Hyper-V GPU-P cmdlets.
#>
[CmdletBinding()]
param(
    [string]$Selector = 'auto',
    [switch]$AllowIntegrated
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-IasiPnpId {
    param([string]$PartitionName)
    if ([string]::IsNullOrWhiteSpace($PartitionName)) { return $null }
    # GPU-P name: \\?\PCI#VEN_....#INSTANCE#{GUID}\GPUPARAV
    $name = $PartitionName -replace '^\\\\\?\\', ''
    $segments = $name -split '#'
    if ($segments.Count -lt 3 -or $segments[0] -ne 'PCI') { return $null }
    return ('{0}\{1}\{2}' -f $segments[0], $segments[1], $segments[2])
}

function Get-IasiClassification {
    param($Controller, $PnpDevice)
    if ($null -eq $Controller) {
        $label = if ($null -ne $PnpDevice) { [string]$PnpDevice.Name } else { '' }
        if ($label -match '(?i)\b(NPU|neural processing|neural processor|AI Boost)\b') {
            return [pscustomobject]@{ Kind = 'NPU'; Reason = 'PnP identifies a neural accelerator, not a display GPU' }
        }
        return [pscustomobject]@{ Kind = 'Unknown'; Reason = 'No matching Win32_VideoController; GPU function not established' }
    }

    $name = [string]$Controller.Name
    # Product-family patterns are *heuristics*, not assumptions about Linux support.
    if ($name -match '(?i)(GeForce|Quadro|RTX\s|Radeon\s+RX|Radeon\s+Pro|Intel\s+Arc)') {
        return [pscustomobject]@{ Kind = 'DiscreteCandidate'; Reason = 'Display GPU with a typically discrete product family (name heuristic)' }
    }
    if ($name -match '(?i)(Intel.*(Graphics|UHD|Iris)|Radeon.*Graphics)') {
        return [pscustomobject]@{ Kind = 'IntegratedCandidate'; Reason = 'Display GPU with a typically integrated product family (name heuristic)' }
    }
    return [pscustomobject]@{ Kind = 'DisplayUnknown'; Reason = 'Display GPU found, but discrete/integrated status is uncertain' }
}

function Get-IasiInventory {
    $partitionable = @(Get-VMHostPartitionableGpu -ErrorAction Stop)
    $controllers = @(Get-CimInstance Win32_VideoController -ErrorAction Stop)
    $pnpDevices = @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop)
    $items = @()
    foreach ($gpu in $partitionable) {
        $pnpId = ConvertTo-IasiPnpId -PartitionName ([string]$gpu.Name)
        $display = @($controllers | Where-Object { $pnpId -and $_.PNPDeviceID -and $_.PNPDeviceID -ieq $pnpId })
        $pnp = @($pnpDevices | Where-Object { $pnpId -and $_.PNPDeviceID -and $_.PNPDeviceID -ieq $pnpId })
        $controller = if ($display.Count -eq 1) { $display[0] } else { $null }
        $device = if ($pnp.Count -eq 1) { $pnp[0] } else { $null }
        $classification = Get-IasiClassification -Controller $controller -PnpDevice $device
        $notes = @()
        if ($display.Count -gt 1 -or $pnp.Count -gt 1) { $notes += 'Device correlation is not unique' }
        if ($classification.Kind -eq 'NPU') { $notes += 'Not eligible for GPU-only IASI Models V1' }
        if ($classification.Kind -eq 'Unknown') { $notes += 'GPU-P enumeration alone does not prove this is a GPU' }
        $items += [pscustomobject]@{
            Name           = [string]$gpu.Name
            PnpId          = $pnpId
            FriendlyName   = if ($controller) { [string]$controller.Name } elseif ($device) { [string]$device.Name } else { '(unresolved)' }
            Kind           = $classification.Kind
            Reason         = $classification.Reason
            DriverVersion  = if ($controller) { [string]$controller.DriverVersion } else { '(not reported)' }
            Counts         = (@($gpu.ValidPartitionCounts) -join ', ')
            OptimalVRAM    = $gpu.OptimalPartitionVRAM
            OptimalCompute = $gpu.OptimalPartitionCompute
            Notes          = $notes
        }
    }
    return $items
}

function Get-IasiDecision {
    param([object[]]$Inventory, [string]$RequestedSelector, [bool]$PermitIntegrated)
    if ($Inventory.Count -eq 0) {
        return [pscustomobject]@{ Item = $null; Reason = 'No GPU-P devices exposed by Hyper-V' }
    }
    if ($RequestedSelector -ne 'auto') {
        $matches = @($Inventory | Where-Object {
            $_.Name -ieq $RequestedSelector -or $_.PnpId -ieq $RequestedSelector -or $_.FriendlyName -ieq $RequestedSelector
        })
        if ($matches.Count -ne 1) {
            return [pscustomobject]@{ Item = $null; Reason = "Explicit selector matches $($matches.Count) devices; it must match exactly one" }
        }
        if ($matches[0].Kind -notin @('DiscreteCandidate','IntegratedCandidate','DisplayUnknown')) {
            return [pscustomobject]@{ Item = $null; Reason = "Selected device is $($matches[0].Kind), not a confirmed display GPU" }
        }
        return [pscustomobject]@{ Item = $matches[0]; Reason = 'Explicit user selection of a display GPU (guest compatibility still unverified)' }
    }
    $discrete = @($Inventory | Where-Object { $_.Kind -eq 'DiscreteCandidate' })
    if ($discrete.Count -eq 1) {
        return [pscustomobject]@{ Item = $discrete[0]; Reason = 'Only discrete GPU candidate; preferred over integrated, unknown and NPU devices' }
    }
    if ($discrete.Count -gt 1) {
        return [pscustomobject]@{ Item = $null; Reason = "Ambiguous: $($discrete.Count) discrete GPU candidates; specify -Selector" }
    }
    if (-not $PermitIntegrated) {
        return [pscustomobject]@{ Item = $null; Reason = 'No discrete candidate; integrated GPU auto-selection disabled (use -AllowIntegrated or -Selector)' }
    }
    $integrated = @($Inventory | Where-Object { $_.Kind -eq 'IntegratedCandidate' })
    if ($integrated.Count -eq 1) {
        return [pscustomobject]@{ Item = $integrated[0]; Reason = 'Only integrated GPU candidate and -AllowIntegrated was supplied' }
    }
    return [pscustomobject]@{ Item = $null; Reason = "No unambiguous integrated GPU candidate (found $($integrated.Count))" }
}

if (-not (Get-Command Get-VMHostPartitionableGpu -ErrorAction SilentlyContinue)) {
    throw 'Hyper-V GPU-P command Get-VMHostPartitionableGpu is unavailable.'
}

$inventory = @(Get-IasiInventory)
$decision = Get-IasiDecision -Inventory $inventory -RequestedSelector $Selector -PermitIntegrated $AllowIntegrated.IsPresent

Write-Host "`nIASI | GPU selection diagnostic (READ ONLY)" -ForegroundColor Cyan
Write-Host ('Partitionable devices: {0}' -f $inventory.Count)
foreach ($item in $inventory) {
    $selected = $null -ne $decision.Item -and $decision.Item.Name -eq $item.Name
    $status = if ($selected) { 'SELECTED (host candidate)' } elseif ($item.Kind -eq 'NPU') { 'EXCLUDED (NPU)' } elseif ($item.Kind -in @('Unknown','DisplayUnknown')) { 'NOT AUTO-SELECTED (uncertain)' } else { 'NOT SELECTED' }
    Write-Host "`nDevice: $($item.FriendlyName)"
    Write-Host "  Type:             $($item.Kind)"
    Write-Host "  Classification:   $($item.Reason)"
    Write-Host "  PnP ID:           $($item.PnpId)"
    Write-Host "  GPU-P path:       $($item.Name)"
    Write-Host "  Driver version:   $($item.DriverVersion)"
    Write-Host "  Partition counts: $($item.Counts)"
    Write-Host "  Optimal VRAM:     $($item.OptimalVRAM)"
    Write-Host "  Optimal compute:  $($item.OptimalCompute)"
    foreach ($note in $item.Notes) { Write-Host "  Note:             $note" }
    Write-Host "  Decision:         $status"
}
Write-Host "`nIASI decision:" -ForegroundColor Cyan
if ($null -eq $decision.Item) {
    Write-Host '  Result: NO AUTOMATIC SELECTION' -ForegroundColor Yellow
} else {
    Write-Host ('  Result: {0}' -f $decision.Item.FriendlyName) -ForegroundColor Green
    Write-Host ('  GPU-P path to configure later: {0}' -f $decision.Item.Name)
}
Write-Host ('  Reason: {0}' -f $decision.Reason)
Write-Host '  Limits: GPU-P enumeration is NOT proof of Linux guest access, CUDA availability or inference acceleration.'
Write-Host '  Hyper-V modifications: NONE' -ForegroundColor Cyan
