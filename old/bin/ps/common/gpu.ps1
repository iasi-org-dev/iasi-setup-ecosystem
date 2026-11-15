. "$PSScriptRoot\gpu-selection.ps1"

function Add-IasiGpuPartition {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VMName,

        [Parameter(Mandatory = $true)]
        $GPU,

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

    $Selected = $GPU
    if (-not $Selected.Name -or $Selected.Kind -notin @('DiscreteCandidate','IntegratedCandidate','DisplayUnknown')) {
        throw "GPU selection did not return an eligible GPU-P device."
    }

    Write-LogInfo "Selected GPU: $($Selected.FriendlyName)"
    Write-LogInfo "GPU instance: $($Selected.Name)"

    Set-VM `
        -Name $VMName `
        -GuestControlledCacheTypes $true `
        -LowMemoryMappedIoSpace $LowMemoryMappedIoSpace `
        -HighMemoryMappedIoSpace $HighMemoryMappedIoSpace `
        -CheckpointType Disabled

    Add-VMGpuPartitionAdapter `
        -VMName $VMName `
        -InstancePath $Selected.Name | Out-Null

    $Adapter = Get-VMGpuPartitionAdapter -VMName $VMName -ErrorAction Stop
    Write-LogSuccess "GPU partition adapter assigned to '$VMName'."

    return [pscustomobject]@{
        GPU     = $Selected
        Adapter = $Adapter
    }
}


# Prepare the selected NVIDIA GPU guest resources before the seed ISO is built.
# All files are staged under this VM's own <ConfigPath>/services/gpu.
function Copy-IasiGpuGuestResources {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] $GPU,
        [Parameter(Mandatory = $true)] [string] $ConfigPath
    )

    if ($GPU.Name -notmatch '(?i)VEN_10DE') {
        throw "Linux GPU guest resource staging is currently implemented only for NVIDIA devices: $($GPU.FriendlyName)"
    }

    # Separate Windows GPU libraries and WSL libraries; no optional source variable.
    $WindowsLib = Join-Path $env:WINDIR 'System32\lxss\lib'
    $WslLib = Join-Path $env:ProgramFiles 'WSL\lib'
    if (-not (Test-Path -LiteralPath $WindowsLib -PathType Container)) {
        throw "Windows GPU library source not found: '$WindowsLib'."
    }
    if (-not (Test-Path -LiteralPath $WslLib -PathType Container)) {
        throw "WSL library source not found: '$WslLib'."
    }
    $LibSource = $WindowsLib

    $ServicesPath = Join-Path $ConfigPath 'services'
    if (-not (Test-Path -LiteralPath $ServicesPath -PathType Container)) {
        throw "Services directory not found: '$ServicesPath'."
    }
    $GpuPath = Join-Path $ServicesPath 'gpu'
    $LibTarget = Join-Path $GpuPath 'lib'
    $DriverTarget = Join-Path $GpuPath 'drivers'
    $WslTarget = Join-Path $GpuPath 'wsl'

    # Only refresh generated folders. Preserve the files copied earlier by scp
    # (and their case-sensitive spellings) in gpu/wsl.
    foreach ($GeneratedDir in @($LibTarget, $DriverTarget)) {
        if (Test-Path -LiteralPath $GeneratedDir) {
            Remove-Item -LiteralPath $GeneratedDir -Recurse -Force -ErrorAction Stop
        }
        New-Item -ItemType Directory -Path $GeneratedDir -Force | Out-Null
    }
    New-Item -ItemType Directory -Path $WslTarget -Force | Out-Null

    Write-LogInfo "Copying Windows guest libraries from '$LibSource' to '$LibTarget'..."
    Get-ChildItem -LiteralPath $LibSource -Force -ErrorAction Stop | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $LibTarget -Recurse -Force -ErrorAction Stop
    }
    $LibcudaFiles = @(Get-ChildItem -LiteralPath $LibTarget -File -Recurse -ErrorAction Stop |
        Where-Object { $_.Name -like 'libcuda.so*' })
    if ($LibcudaFiles.Count -eq 0) {
        throw "No libcuda.so files were copied from '$LibSource'."
    }
    Write-LogSuccess "NVIDIA libraries staged in '$LibTarget'."

    # Stage all WSL library files into their own folder, preserving any files
    # previously recovered with scp. No renaming, filtering or symlinks here.
    Write-LogInfo "Copying WSL libraries from '$WslLib' to '$WslTarget'..."
    $WslItems = @(Get-ChildItem -LiteralPath $WslLib -Force -ErrorAction Stop)
    if ($WslItems.Count -eq 0) {
        throw "WSL library source is empty: '$WslLib'."
    }
    foreach ($Item in $WslItems) {
        Copy-Item -LiteralPath $Item.FullName -Destination $WslTarget -Recurse -Force -ErrorAction Stop
    }
    $WslCopied = @(Get-ChildItem -LiteralPath $WslTarget -Force -ErrorAction Stop)
    if ($WslCopied.Count -eq 0) {
        throw "WSL library staging produced an empty directory: '$WslTarget'."
    }
    Write-LogSuccess "WSL libraries staged in '$WslTarget'."

    # Resolve the selected GPU's exact PnP driver package. Never take the
    # first arbitrary NVIDIA directory from FileRepository.
    if (-not $GPU.PnpId) {
        throw "Selected GPU has no resolved PnP ID: $($GPU.FriendlyName)"
    }
    Write-LogInfo "Resolving installed driver package for $($GPU.PnpId)..."
    $Signed = @(Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop |
        Where-Object { $_.DeviceID -ieq $GPU.PnpId -and $_.InfName })
    if ($Signed.Count -ne 1) {
        throw "Expected one signed PnP driver for '$($GPU.PnpId)', found $($Signed.Count)."
    }
    $InfName = [string]$Signed[0].InfName
    Write-LogInfo "Installed INF: $InfName; driver version: $($Signed[0].DriverVersion)"

    # DISM maps the published oem*.inf to the original INF in DriverStore.
    $Packages = @(Get-WindowsDriver -Online -All -ErrorAction Stop |
        Where-Object { $_.Driver -ieq $InfName })
    if ($Packages.Count -ne 1) {
        throw "Could not uniquely resolve INF '$InfName' in the online DriverStore (matches: $($Packages.Count))."
    }
    $OriginalInf = [string]$Packages[0].OriginalFileName
    if ([string]::IsNullOrWhiteSpace($OriginalInf) -or -not (Test-Path -LiteralPath $OriginalInf -PathType Leaf)) {
        throw "DriverStore original INF is missing: '$OriginalInf'."
    }
    $PackagePath = Split-Path -Parent $OriginalInf
    $DriverStoreRoot = [IO.Path]::GetFullPath((Join-Path $env:WINDIR 'System32\DriverStore\FileRepository'))
    $CanonicalPackagePath = [IO.Path]::GetFullPath($PackagePath)
    if (-not $CanonicalPackagePath.StartsWith($DriverStoreRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Resolved driver directory is outside FileRepository: '$CanonicalPackagePath'."
    }

    # Preserve the original FileRepository package directory as well as its
    # internal NVIDIA subdirectories: drivers/<FileRepositoryPackage>/...
    $PackageFolder = Split-Path $CanonicalPackagePath -Leaf
    $PackageTarget = Join-Path $DriverTarget $PackageFolder
    Write-LogInfo "Copying selected GPU driver package: $CanonicalPackagePath"
    Copy-Item -LiteralPath $CanonicalPackagePath -Destination $PackageTarget -Recurse -Force -ErrorAction Stop
    $CopiedInf = Join-Path $PackageTarget (Split-Path $OriginalInf -Leaf)
    if (-not (Test-Path -LiteralPath $CopiedInf -PathType Leaf)) {
        throw "Copied driver package verification failed: '$CopiedInf'."
    }
    Write-LogSuccess "NVIDIA driver package staged at '$PackageTarget'."

    # Preserve original Windows DriverStore identity for auditability.
    $TracePath = Join-Path $DriverTarget 'driverstore-source.txt'
    @(
        "DriverStoreFolder: $(Split-Path $CanonicalPackagePath -Leaf)"
        "DriverStorePath: $CanonicalPackagePath"
        "PublishedINF: $InfName"
        "OriginalINF: $(Split-Path $OriginalInf -Leaf)"
        "DriverVersion: $($Signed[0].DriverVersion)"
        "GPU: $($GPU.FriendlyName)"
        "PnPDeviceID: $($GPU.PnpId)"
    ) | Set-Content -LiteralPath $TracePath -Encoding UTF8 -ErrorAction Stop
    Write-LogSuccess "GPU driver package contents staged in '$DriverTarget'."
    Write-LogInfo "DriverStore trace saved to '$TracePath'."
    Write-LogInfo 'GPU drivers, lib and wsl directories are ready for inspection.'
}
