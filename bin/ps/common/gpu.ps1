<#
.SYNOPSIS
GPU-P discovery and assignment helpers for IASI Hyper-V virtual machines.

.DESCRIPTION
Discovers GPUs exposed by Hyper-V as partitionable, correlates them with
Windows video controllers and selects a GPU without hard-coded vendor, model,
PCI vendor ID or device ID.

The default selector is "auto":
- one partitionable GPU: use it;
- several partitionable GPUs: choose the uniquely largest reported AdapterRAM;
- no GPU, missing data or a tie: fail rather than choose arbitrarily.

GPU assignment is structural VM configuration. Resource profiles such as
light, normal, heavy and beast do not add or remove the GPU.
#>


function Convert-GpuPartitionNameToPnpDeviceId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $Value = $Name

    if ($Value.StartsWith("\\?\")) {
        $Value = $Value.Substring(4)
    }

    $GuidMarker = $Value.IndexOf("#{")
    if ($GuidMarker -ge 0) {
        $Value = $Value.Substring(0, $GuidMarker)
    }

    $Parts = $Value -split "#"
    if ($Parts.Count -lt 3) { return $null }

    return "$($Parts[0])\$($Parts[1])\$($Parts[2])"
}


function Get-IasiGpuInventory {
    if (-not (Get-Command Get-VMHostPartitionableGpu -ErrorAction SilentlyContinue)) {
        throw "Get-VMHostPartitionableGpu is not available on this host."
    }

    $Partitionable = @(Get-VMHostPartitionableGpu)
    $Controllers = @(Get-CimInstance Win32_VideoController)
    $Inventory = @()

    foreach ($GPU in $Partitionable) {
        $PnpDeviceId = Convert-GpuPartitionNameToPnpDeviceId -Name $GPU.Name
        $Controller = $null

        if ($PnpDeviceId) {
            $Controller = @(
                $Controllers |
                Where-Object {
                    $_.PNPDeviceID -and
                    $_.PNPDeviceID.Equals(
                        $PnpDeviceId,
                        [System.StringComparison]::OrdinalIgnoreCase
                    )
                }
            ) | Select-Object -First 1
        }

        $Inventory += [pscustomobject]@{
            PartitionableGpu = $GPU
            PartitionName    = $GPU.Name
            PnpDeviceId      = $PnpDeviceId
            Controller       = $Controller
            FriendlyName     = if ($Controller) { $Controller.Name } else { $null }
            AdapterRAM       = if ($Controller) { $Controller.AdapterRAM } else { $null }
            Status           = if ($Controller) { $Controller.Status } else { $null }
            VideoProcessor   = if ($Controller) { $Controller.VideoProcessor } else { $null }
        }
    }

    return @($Inventory)
}


function Select-IasiGpu {
    param(
        [string]$Selector = "auto"
    )

    if ($Selector -ne "auto") {
        throw "GPU selector '$Selector' is not supported yet."
    }

    $Inventory = @(Get-IasiGpuInventory)

    if ($Inventory.Count -eq 0) {
        throw "No partitionable GPU is available on this Hyper-V host."
    }

    if ($Inventory.Count -eq 1) {
        return $Inventory[0]
    }

    $Matched = @(
        $Inventory |
        Where-Object {
            $null -ne $_.Controller -and
            $null -ne $_.AdapterRAM -and
            [double]$_.AdapterRAM -gt 0
        }
    )

    if ($Matched.Count -eq 0) {
        throw "Automatic GPU selection is ambiguous: no partitionable GPU could be correlated with usable video-memory information."
    }

    $MaxRAM = ($Matched | Measure-Object -Property AdapterRAM -Maximum).Maximum
    $Candidates = @(
        $Matched |
        Where-Object { [double]$_.AdapterRAM -eq [double]$MaxRAM }
    )

    if ($Candidates.Count -ne 1) {
        throw "Automatic GPU selection is ambiguous: $($Candidates.Count) GPUs share the greatest reported video memory."
    }

    return $Candidates[0]
}


function Add-IasiGpuPartition {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VMName,

        [string]$Selector = "auto",

        [uint32]$LowMemoryMappedIoSpace = 1GB,

        [uint64]$HighMemoryMappedIoSpace = 32GB
    )

    $VM = Get-VM -Name $VMName -ErrorAction Stop
    if ($VM.State -ne "Off") {
        throw "GPU-P can only be configured while virtual machine '$VMName' is powered off."
    }

    $Existing = @(Get-VMGpuPartitionAdapter -VMName $VMName -ErrorAction SilentlyContinue)
    if ($Existing.Count -gt 0) {
        throw "Virtual machine '$VMName' already has a GPU partition adapter."
    }

    $Selected = Select-IasiGpu -Selector $Selector

    Write-LogInfo "Selected GPU: $($Selected.FriendlyName)"
    Write-LogInfo "GPU instance: $($Selected.PartitionName)"

    Set-VM `
        -Name $VMName `
        -GuestControlledCacheTypes $true `
        -LowMemoryMappedIoSpace $LowMemoryMappedIoSpace `
        -HighMemoryMappedIoSpace $HighMemoryMappedIoSpace `
        -CheckpointType Disabled

    Add-VMGpuPartitionAdapter `
        -VMName $VMName `
        -InstancePath $Selected.PartitionName | Out-Null

    $Adapter = Get-VMGpuPartitionAdapter -VMName $VMName -ErrorAction Stop
    Write-LogSuccess "GPU partition adapter assigned to '$VMName'."

    return [pscustomobject]@{
        GPU     = $Selected
        Adapter = $Adapter
    }
}
