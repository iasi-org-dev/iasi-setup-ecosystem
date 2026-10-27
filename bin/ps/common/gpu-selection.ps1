<#
.SYNOPSIS
    IASI GPU-P discovery and explainable interactive selection.
.DESCRIPTION
    Exposes Select-IasiGpu. Read-only: does NOT change Hyper-V.
    Returns one validated inventory object. If automatic selection is ambiguous,
    asks the user to select. Explicit selectors are validated without prompting.
    Uses information messages on the HOST stream, not pipeline output.
.NOTES
    Host-side candidate selection is not proof of CUDA/Linux guest compatibility.
#>

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


function Select-IasiGpu {
    [CmdletBinding()]
    param(
        [string]$Selector = 'auto',
        [switch]$AllowIntegrated,
        [switch]$ForcePrompt
    )

    if (-not (Get-Command Get-VMHostPartitionableGpu -ErrorAction SilentlyContinue)) {
        throw 'Get-VMHostPartitionableGpu is unavailable.'
    }

    $inventory = @(Get-IasiInventory)

    Write-Host "`nIASI | GPU inventory and selection"
    Write-Host ('  Partitionable devices discovered: {0}' -f $inventory.Count)
    foreach ($item in $inventory) {
        Write-Host ('  - {0} [{1}]' -f $item.FriendlyName, $item.Kind)
        Write-Host ('    Classification: {0}' -f $item.Reason)
        Write-Host ('    GPU-P: {0}' -f $item.Name)
        foreach ($note in $item.Notes) { Write-Host ('    Note: {0}' -f $note) }
    }

    if ($inventory.Count -eq 0) {
        throw 'No GPU-P devices exposed by Hyper-V.'
    }

    $chosen = $null
    $reason = ''

    if ($Selector -ne 'auto') {
        $matches = @($inventory | Where-Object {
            $_.Name -ieq $Selector -or $_.PnpId -ieq $Selector -or $_.FriendlyName -ieq $Selector
        })
        if ($matches.Count -ne 1) {
            throw ("Explicit selector matches {0} devices; expected exactly one." -f $matches.Count)
        }
        $chosen = $matches[0]
        $reason = 'Explicit GPU selection validated against the discovered inventory.'
    }
    elseif (-not $ForcePrompt) {
        $discrete = @($inventory | Where-Object { $_.Kind -eq 'DiscreteCandidate' })
        $integrated = @($inventory | Where-Object { $_.Kind -eq 'IntegratedCandidate' })

        if ($discrete.Count -eq 1) {
            $chosen = $discrete[0]
            $reason = 'Only discrete GPU candidate; preferred over integrated, unknown and NPU devices.'
        }
        elseif ($discrete.Count -eq 0 -and $AllowIntegrated -and $integrated.Count -eq 1) {
            $chosen = $integrated[0]
            $reason = 'Only integrated GPU candidate; permitted by AllowIntegrated.'
        }
        else {
            $reason = 'Automatic GPU selection is ambiguous or lacks an eligible GPU candidate.'
        }
    }
    else {
        $reason = 'Manual selection deliberately requested for testing.'
    }

    if ($null -eq $chosen) {
        Write-Host ('  Automatic decision: {0}' -f $reason) -ForegroundColor Yellow
        Write-Host '  Seleccione la GPU que quiere utilizar:'
        for ($i = 0; $i -lt $inventory.Count; $i++) {
            $item = $inventory[$i]
            $eligibility = if ($item.Kind -in @('DiscreteCandidate','IntegratedCandidate','DisplayUnknown')) {
                'GPU candidate'
            } else {
                'NOT eligible for GPU-only V1'
            }
            Write-Host ('    [{0}] {1} ({2}; {3})' -f ($i + 1), $item.FriendlyName, $item.Kind, $eligibility)
        }
        Write-Host '    [0] Cancelar'
        while ($true) {
            $answer = (Read-Host 'Selecciona un numero').Trim()
            $index = 0
            if (-not [int]::TryParse($answer, [ref]$index) -or $index -lt 0 -or $index -gt $inventory.Count) {
                Write-Host '    Opcion no valida.' -ForegroundColor Yellow
                continue
            }
            if ($index -eq 0) { throw 'GPU selection cancelled by user.' }
            $candidate = $inventory[$index - 1]
            if ($candidate.Kind -notin @('DiscreteCandidate','IntegratedCandidate','DisplayUnknown')) {
                Write-Host ('    Rejected: {0} is not an eligible display GPU.' -f $candidate.FriendlyName) -ForegroundColor Yellow
                continue
            }
            $chosen = $candidate
            $reason = 'User selected a GPU from the discovered device inventory.'
            break
        }
    }

    if ($chosen.Kind -notin @('DiscreteCandidate','IntegratedCandidate','DisplayUnknown')) {
        throw ("Selected device '{0}' is {1}, not an eligible display GPU." -f $chosen.FriendlyName, $chosen.Kind)
    }

    Write-Host ('  SELECTED: {0}' -f $chosen.FriendlyName) -ForegroundColor Green
    Write-Host ('  Reason: {0}' -f $reason)
    Write-Host ('  Device path: {0}' -f $chosen.Name)
    Write-Host '  Limit: Linux guest access, drivers and CUDA have NOT been verified.'
    Write-Host '  Hyper-V changes: NONE (selection only).'
    # The ONE pipeline result of this function.
    return $chosen
}
