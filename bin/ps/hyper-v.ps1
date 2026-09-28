<#
.SYNOPSIS
Creates or reconfigures an IASI Hyper-V virtual machine from a configuration directory.

.USAGE
    .\hyper-v.ps1
    .\hyper-v.ps1 -f
    .\hyper-v.ps1 -l
    .\hyper-v.ps1 --config <path>
    .\hyper-v.ps1 --path <path>
    .\hyper-v.ps1 --mode normal
    .\hyper-v.ps1 --mode heavy
    .\hyper-v.ps1 --mode heavy -l

.PARAMETERS
    -f
        Force recreation in build mode.
        Invalid together with --mode.

    -l
        No launch.
        In build mode, creates and configures the VM but leaves it powered off.
        In mode-change mode, applies the requested profile and leaves it off.

    --mode <mode>
        Reconfigures CPU and memory on an EXISTING virtual machine.
        Supplying --mode never creates a VM. If the VM does not exist, the
        command fails.

        The available modes are defined by the node configuration. For
        iasi-ai they are currently light, normal, heavy and beast.

    --config <path>
        Configuration directory.
        Default: current working directory.

    --path <path>
        Root directory where a new virtual machine is materialized.
        A subdirectory named after $VMName is created below this path.
        Used when $Path is not defined in configuration.
        Default: Hyper-V VirtualMachinePath.
        Invalid together with --mode because --mode never creates a VM.

.BEHAVIOR
Without --mode, the command is in build mode:
- the node's default mode is used when profiles exist (normal for iasi-ai);
- if the VM does not exist, it is created;
- if it exists, the command leaves it unchanged unless -f is supplied;
- -f recreates it;
- -l leaves it powered off.

With --mode, the command is in resource-profile mode:
- the VM must already exist;
- the VM is shut down if necessary;
- CPU and dynamic-memory values are changed;
- the VM is started again unless -l is supplied;
- no disk, ISO, network or GPU assignment is created or changed.

.CONFIGURATION
The configuration directory contains node-specific files. Build mode requires:

    user-data
    meta-data
    config-data\
        *.ps1

Mode-change mode only requires config-data because it never installs or creates
anything.

All PowerShell files directly under config-data are loaded in name order.

Base configuration must define:

    $VMName
    $Generation
    $DiskSizeBytes

Installation media is selected by $Installer:

    subiquity
        Uses $SourceISO and the existing Subiquity/NoCloud autoinstall flow.
        This is the default when $Installer is omitted.

    calamares
        Uses $SourceISO directly as the live installer ISO.
        Calamares itself is still interactive at this stage.

Every created virtual machine receives two network adapters:

    NIC 1
        Connected to the IASI private switch.
        Uses the node's static address from config\iasi-net.toml.

    NIC 2
        Connected to the Hyper-V Internet switch declared in
        config\iasi-net.toml.
        Uses DHCP and provides Internet connectivity.

$SourceISO is the canonical ISO configuration variable. $UbuntuISO and
$KubuntuISO are accepted temporarily as legacy fallbacks.

A node without profiles must also define:

    $MemoryStartupBytes
    $ProcessorCount

A node with profiles defines:

    $DefaultMode
    $Modes

Optional configuration:

    $Path
    $Packages
    $NetworkInterface
    $InternetNetworkInterface
    $GPUEnabled
    $GPUSelector
    $GPULowMemoryMappedIoSpace
    $GPUHighMemoryMappedIoSpace
    $Installer
    $SourceISO
    $UbuntuISO
    $KubuntuISO

Network topology and node addresses are read from:

    config\iasi-net.toml

GPU assignment is structural VM configuration. It is performed only while
building a GPU-enabled VM. Changing --mode never adds, removes or changes GPU-P.
#>


. "$PSScriptRoot\common\log.ps1"
. "$PSScriptRoot\common\messages.ps1"
. "$PSScriptRoot\common\toml.ps1"
. "$PSScriptRoot\common\gpu.ps1"
. "$PSScriptRoot\common\iso.ps1"


$ScriptArguments = @($args)
$NetworkConfigurationFile = "config\iasi-net.toml"


# =====================================================================
# Initialize
# =====================================================================

function Read-Arguments {
    $script:Force = $false
    $script:NoLaunch = $false
    $script:ModeSpecified = $false
    $script:RequestedMode = $null
    $script:ConfigPath = "."
    $script:TargetPath = $null

    for ($i = 0; $i -lt $ScriptArguments.Count; $i++) {
        switch ($ScriptArguments[$i]) {
            "-f" { $script:Force = $true }
            "-l" { $script:NoLaunch = $true }
            "--mode" {
                $i++
                if ($i -ge $ScriptArguments.Count) { throw "Missing value for --mode." }
                $script:ModeSpecified = $true
                $script:RequestedMode = $ScriptArguments[$i]
            }
            "--config" {
                $i++
                if ($i -ge $ScriptArguments.Count) { throw "Missing value for --config." }
                $script:ConfigPath = $ScriptArguments[$i]
            }
            "--path" {
                $i++
                if ($i -ge $ScriptArguments.Count) { throw "Missing value for --path." }
                $script:TargetPath = $ScriptArguments[$i]
            }
            default { throw "Unknown argument: $($ScriptArguments[$i])" }
        }
    }

    if ($ModeSpecified -and $Force) {
        throw "-f cannot be used together with --mode. --mode never creates or recreates a virtual machine."
    }

    if ($ModeSpecified -and $TargetPath) {
        throw "--path cannot be used together with --mode. --mode operates on an existing virtual machine."
    }
}


function Resolve-IasiRoot {
    $script:IASIRoot = [System.IO.Path]::GetFullPath(
        (Join-Path $PSScriptRoot "..\..")
    )

    $script:NetworkConfigurationPath = Join-Path `
        $IASIRoot `
        $NetworkConfigurationFile
}


function Resolve-ConfigurationPath {
    if (-not (Test-Path $ConfigPath -PathType Container)) {
        throw "Configuration directory '$ConfigPath' does not exist."
    }

    $script:ConfigPath = (Resolve-Path $ConfigPath).Path
    $script:ConfigDataPath = Join-Path $ConfigPath "config-data"
    $script:NodeName = Split-Path $ConfigPath -Leaf

    if (-not $NodeName) {
        throw "Unable to resolve node name from configuration path '$ConfigPath'."
    }

    if (-not (Test-Path $ConfigDataPath -PathType Container)) {
        throw "Missing config-data directory."
    }

    if (-not $ModeSpecified) {
        $script:UserDataPath = Join-Path $ConfigPath "user-data"
        $script:MetaDataPath = Join-Path $ConfigPath "meta-data"
    }
}


function Import-Configuration {
    $ConfigScripts = @(
        Get-ChildItem `
            -Path $ConfigDataPath `
            -Filter "*.ps1" `
            -File |
        Sort-Object Name
    )

    if ($ConfigScripts.Count -eq 0) {
        throw "No PowerShell configuration found in config-data."
    }

    $RequiredVariables = @(
        "VMName",
        "Generation",
        "DiskSizeBytes"
    )

    $OptionalVariables = @(
        "Path",
        "Packages",
        "NetworkInterface",
        "InternetNetworkInterface",
        "ProcessorCount",
        "MemoryStartupBytes",
        "DefaultMode",
        "Modes",
        "GPUEnabled",
        "GPUSelector",
        "GPULowMemoryMappedIoSpace",
        "GPUHighMemoryMappedIoSpace",
        "Installer",
        "SourceISO",
        "UbuntuISO",
        "KubuntuISO"
    )

    $ConfigurationVariables = $RequiredVariables + $OptionalVariables

    $Configuration = & {
        param($Scripts, $VariableNames)

        foreach ($ConfigScript in $Scripts) {
            . $ConfigScript.FullName
        }

        $Values = @{}

        foreach ($VariableName in $VariableNames) {
            $Variable = Get-Variable -Name $VariableName -Scope 0 -ErrorAction SilentlyContinue
            if ($Variable) {
                $Values[$VariableName] = $Variable.Value
            }
        }

        $Values
    } $ConfigScripts $ConfigurationVariables

    foreach ($VariableName in $RequiredVariables) {
        if (-not $Configuration.ContainsKey($VariableName)) {
            throw "Configuration variable '$VariableName' is not defined."
        }

        Set-Variable `
            -Name $VariableName `
            -Value $Configuration[$VariableName] `
            -Scope Script
    }

    foreach ($VariableName in $OptionalVariables) {
        if ($Configuration.ContainsKey($VariableName)) {
            Set-Variable `
                -Name $VariableName `
                -Value $Configuration[$VariableName] `
                -Scope Script
        }
    }
}



function Resolve-InstallerConfiguration {
    if ($ModeSpecified) {
        return
    }

    if (-not $Installer) {
        $script:Installer = "subiquity"
    }

    if (-not $SourceISO) {
        switch ($Installer) {
            "subiquity" {
                if ($UbuntuISO) {
                    $script:SourceISO = $UbuntuISO
                    Write-LogWarning "UbuntuISO is deprecated. Use SourceISO instead."
                }
            }

            "calamares" {
                if ($KubuntuISO) {
                    $script:SourceISO = $KubuntuISO
                    Write-LogWarning "KubuntuISO is deprecated. Use SourceISO instead."
                }
            }
        }
    }

    if (-not $SourceISO) {
        throw "Configuration variable 'SourceISO' is required for installer '$Installer'."
    }

    switch ($Installer) {
        "subiquity" {
            if (-not (Test-Path $UserDataPath -PathType Leaf)) {
                throw "Missing user-data for installer '$Installer'."
            }

            if (-not (Test-Path $MetaDataPath -PathType Leaf)) {
                throw "Missing meta-data for installer '$Installer'."
            }
        }

        "calamares" {
            # Calamares currently uses the source ISO directly.
        }

        default {
            throw "Unsupported installer '$Installer'. Supported installers: subiquity, calamares."
        }
    }
}


function Resolve-ModeConfiguration {
    $HasModes = $null -ne $Modes

    if (-not $HasModes) {
        if ($ModeSpecified) {
            throw "Node '$NodeName' does not define resource modes."
        }

        if ($null -eq $ProcessorCount) {
            throw "Configuration variable 'ProcessorCount' is required when no modes are defined."
        }

        if ($null -eq $MemoryStartupBytes) {
            throw "Configuration variable 'MemoryStartupBytes' is required when no modes are defined."
        }

        $script:EffectiveMode = $null
        $script:UseDynamicMemory = $false
        return
    }

    if (-not $DefaultMode) {
        $script:DefaultMode = "normal"
    }

    $script:EffectiveMode = if ($ModeSpecified) { $RequestedMode } else { $DefaultMode }

    if (-not $Modes.ContainsKey($EffectiveMode)) {
        $Available = @($Modes.Keys | Sort-Object) -join ", "
        throw "Unknown mode '$EffectiveMode'. Available modes: $Available."
    }

    $Profile = $Modes[$EffectiveMode]

    foreach ($Key in @(
        "ProcessorCount",
        "MinimumMemory",
        "StartupMemory",
        "MaximumMemory"
    )) {
        if (-not $Profile.ContainsKey($Key)) {
            throw "Mode '$EffectiveMode' does not define '$Key'."
        }
    }

    $script:ProcessorCount = [int]$Profile["ProcessorCount"]
    $script:MemoryMinimumBytes = [int64]$Profile["MinimumMemory"]
    $script:MemoryStartupBytes = [int64]$Profile["StartupMemory"]
    $script:MemoryMaximumBytes = [int64]$Profile["MaximumMemory"]
    $script:UseDynamicMemory = $true

    if ($MemoryMinimumBytes -le 0 -or $MemoryStartupBytes -le 0 -or $MemoryMaximumBytes -le 0) {
        throw "Mode '$EffectiveMode' contains an invalid memory value."
    }

    if ($MemoryMinimumBytes -gt $MemoryStartupBytes) {
        throw "Mode '$EffectiveMode' has MinimumMemory greater than StartupMemory."
    }

    if ($MemoryStartupBytes -gt $MemoryMaximumBytes) {
        throw "Mode '$EffectiveMode' has StartupMemory greater than MaximumMemory."
    }
}


function Resolve-GpuConfiguration {
    if ($null -eq $GPUEnabled) {
        $script:GPUEnabled = $false
    }

    if (-not $GPUEnabled) { return }

    if (-not $GPUSelector) {
        $script:GPUSelector = "auto"
    }

    if ($null -eq $GPULowMemoryMappedIoSpace) {
        $script:GPULowMemoryMappedIoSpace = 1GB
    }

    if ($null -eq $GPUHighMemoryMappedIoSpace) {
        $script:GPUHighMemoryMappedIoSpace = 32GB
    }
}


function Import-NetworkConfiguration {
    if (-not (Test-Path $NetworkConfigurationPath -PathType Leaf)) {
        throw "Network configuration '$NetworkConfigurationPath' does not exist."
    }

    $Configuration = Read-IasiToml -Path $NetworkConfigurationPath

    foreach ($Section in @("network", "internet", "dns", "nodes")) {
        if (-not $Configuration.Contains($Section)) {
            throw "Missing [$Section] section in '$NetworkConfigurationPath'."
        }
    }

    $Network = $Configuration["network"]
    $Internet = $Configuration["internet"]
    $Dns = $Configuration["dns"]
    $Nodes = $Configuration["nodes"]

    foreach ($Key in @("name", "subnet", "prefix-length", "gateway")) {
        if (-not $Network.Contains($Key)) {
            throw "Missing network.$Key in '$NetworkConfigurationPath'."
        }
    }

    if (-not $Internet.Contains("name")) {
        throw "Missing internet.name in '$NetworkConfigurationPath'."
    }

    if (-not $Dns.Contains("servers")) {
        throw "Missing dns.servers in '$NetworkConfigurationPath'."
    }

    if (-not $Nodes.Contains($NodeName)) {
        throw "Node '$NodeName' is not defined in [nodes] in '$NetworkConfigurationPath'."
    }

    $script:SwitchName = [string]$Network["name"]
    $script:InternetSwitchName = [string]$Internet["name"]
    $script:Subnet = [string]$Network["subnet"]
    $script:PrefixLength = [int]$Network["prefix-length"]
    $script:Gateway = [string]$Network["gateway"]
    $script:DnsServers = @($Dns["servers"])
    $script:IPAddress = [string]$Nodes[$NodeName]

    if (-not $NetworkInterface) {
        $script:NetworkInterface = "eth0"
    }

    if (-not $InternetNetworkInterface) {
        $script:InternetNetworkInterface = "eth1"
    }
}


function Initialize {
    Read-Arguments
    Initialize-Log "hyper-v"
    Resolve-IasiRoot
    Resolve-ConfigurationPath
    Import-Configuration
    Resolve-InstallerConfiguration
    Resolve-ModeConfiguration
    Resolve-GpuConfiguration

    if (-not $ModeSpecified) {
        Import-NetworkConfiguration
    }
}


# =====================================================================
# Validation helpers
# =====================================================================

function Test-IPv4Address {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Address,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $Parsed = $null

    if (-not [System.Net.IPAddress]::TryParse($Address, [ref]$Parsed)) {
        throw "$Name '$Address' is not a valid IP address."
    }

    if ($Parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        throw "$Name '$Address' is not an IPv4 address."
    }
}


function Convert-IPv4ToUInt32 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Address
    )

    $Bytes = [System.Net.IPAddress]::Parse($Address).GetAddressBytes()
    [Array]::Reverse($Bytes)

    return [BitConverter]::ToUInt32($Bytes, 0)
}


function Test-IPv4InSubnet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Address
    )

    if ($Subnet -notmatch '^([^/]+)/(\d+)$') {
        throw "network.subnet '$Subnet' must use IPv4 CIDR notation."
    }

    $NetworkAddress = $Matches[1]
    $CidrPrefix = [int]$Matches[2]

    if ($CidrPrefix -ne $PrefixLength) {
        throw "network.subnet '$Subnet' and network.prefix-length '$PrefixLength' disagree."
    }

    Test-IPv4Address -Address $NetworkAddress -Name "Network address"

    $AddressValue = Convert-IPv4ToUInt32 $Address
    $NetworkValue = Convert-IPv4ToUInt32 $NetworkAddress

    if ($CidrPrefix -eq 0) {
        $Mask = [uint32]0
    }
    else {
        $Mask = [uint32]([uint32]::MaxValue -shl (32 - $CidrPrefix))
    }

    return (($AddressValue -band $Mask) -eq ($NetworkValue -band $Mask))
}


function Test-BuildConfiguration {
    if (-not [System.IO.Path]::IsPathRooted($SourceISO)) {
        $script:SourceISO = Join-Path $ConfigPath $SourceISO
    }

    if (-not (Test-Path $SourceISO -PathType Leaf)) {
        throw "Source ISO '$SourceISO' does not exist."
    }

    $script:SourceISO = (Resolve-Path $SourceISO).Path

    if ($Installer -eq "subiquity") {
        # common\iso.ps1 still uses the historical parameter name UbuntuISO
        # internally. The source itself is now distribution-neutral here.
        $script:UbuntuISO = $SourceISO
    }

    Test-IPv4Address -Address $IPAddress -Name "VM IP address"
    Test-IPv4Address -Address $Gateway -Name "Network gateway"

    foreach ($DnsServer in $DnsServers) {
        Test-IPv4Address -Address ([string]$DnsServer) -Name "DNS server"
    }

    if (-not (Test-IPv4InSubnet -Address $IPAddress)) {
        throw "VM IP address '$IPAddress' is outside configured subnet '$Subnet'."
    }

    if (-not (Test-IPv4InSubnet -Address $Gateway)) {
        throw "Network gateway '$Gateway' is outside configured subnet '$Subnet'."
    }

    if ([string]::IsNullOrWhiteSpace($NetworkInterface)) {
        throw "NetworkInterface cannot be empty."
    }
}


function Test-HyperVEnvironment {
    if (-not (Get-Module -ListAvailable -Name Hyper-V)) {
        throw "Hyper-V PowerShell module is not available."
    }
}


function Test-BuildEnvironment {
    Test-HyperVEnvironment

    if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
        throw "Hyper-V virtual switch '$SwitchName' does not exist."
    }

    if (-not (Get-VMSwitch -Name $InternetSwitchName -ErrorAction SilentlyContinue)) {
        throw "Hyper-V virtual switch '$InternetSwitchName' does not exist."
    }
}


# =====================================================================
# Build preparation
# =====================================================================

function Remove-VirtualMachine {
    param($VM)

    Write-LogInfo "Removing existing virtual machine '$VMName'..."

    $Disks = @(
        Get-VMHardDiskDrive -VMName $VMName |
        Select-Object -ExpandProperty Path -Unique
    )

    if ($VM.State -ne "Off") {
        Stop-VM -Name $VMName -TurnOff -Force
    }

    Remove-VM -Name $VMName -Force

    foreach ($Disk in $Disks) {
        $DiskName = [System.IO.Path]::GetFileName($Disk)

        if ($DiskName.StartsWith($VMName) -and (Test-Path $Disk)) {
            Remove-Item $Disk -Force
        }
    }
}


function Resolve-ExistingVMForBuild {
    $VM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
    if (-not $VM) { return }

    if (-not $Force) {
        Write-LogWarning "Virtual machine '$VMName' already exists. Use -f to recreate it."
        exit 0
    }

    Remove-VirtualMachine $VM
}


function Resolve-Paths {
    $VMHost = Get-VMHost

    if ($Path) {
        $BasePath = $Path
    }
    elseif ($TargetPath) {
        $BasePath = $TargetPath
    }
    else {
        $BasePath = $VMHost.VirtualMachinePath
    }

    if (-not [System.IO.Path]::IsPathRooted($BasePath)) {
        $BasePath = Join-Path (Get-Location).Path $BasePath
    }

    if (-not (Test-Path $BasePath -PathType Container)) {
        New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
    }

    $script:VMPath = Join-Path $BasePath $VMName

    if (-not (Test-Path $VMPath -PathType Container)) {
        New-Item -ItemType Directory -Path $VMPath -Force | Out-Null
    }

    $script:VHDPath = Join-Path $VMPath "$VMName.vhdx"

    if (Test-Path $VHDPath) {
        if (-not $Force) {
            throw "Virtual disk '$VHDPath' already exists."
        }

        Remove-Item $VHDPath -Force
    }
}


function Resolve-InstallationMediaPaths {
    switch ($Installer) {
        "subiquity" {
            $IsoPaths = Get-IsoPaths -UbuntuISO $SourceISO -VMName $VMName
            $script:InstallISO = $IsoPaths.InstallISO
            $script:SeedISO = $IsoPaths.SeedISO
        }

        "calamares" {
            $script:InstallISO = $SourceISO
            $script:SeedISO = $null
        }
    }
}


function Prepare-Build {
    Test-BuildConfiguration
    Test-BuildEnvironment
    Resolve-ExistingVMForBuild
    Resolve-Paths
    Resolve-InstallationMediaPaths

    if ($Installer -eq "subiquity") {
        Test-IsoEnvironment
        Test-IsoOutputDirectory -UbuntuISO $SourceISO
    }
}


# =====================================================================
# VM creation
# =====================================================================

function Set-VirtualMachineResources {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    Set-VMProcessor `
        -VMName $Name `
        -Count $ProcessorCount

    if ($UseDynamicMemory) {
        Set-VMMemory `
            -VMName $Name `
            -DynamicMemoryEnabled $true `
            -MinimumBytes $MemoryMinimumBytes `
            -StartupBytes $MemoryStartupBytes `
            -MaximumBytes $MemoryMaximumBytes
    }
    else {
        Set-VMMemory `
            -VMName $Name `
            -DynamicMemoryEnabled $false `
            -StartupBytes $MemoryStartupBytes
    }
}


function New-VirtualMachine {
    Write-LogInfo "Creating virtual machine '$VMName'..."

    New-VM `
        -Name $VMName `
        -Generation $Generation `
        -MemoryStartupBytes $MemoryStartupBytes `
        -NewVHDPath $VHDPath `
        -NewVHDSizeBytes $DiskSizeBytes `
        -Path $VMPath `
        -SwitchName $SwitchName | Out-Null

    Add-VMNetworkAdapter `
        -VMName $VMName `
        -SwitchName $InternetSwitchName `
        -Name "Internet" | Out-Null

    Set-VirtualMachineResources -Name $VMName

    Set-VM `
        -Name $VMName `
        -AutomaticCheckpointsEnabled $false

    if ($GPUEnabled) {
        Add-IasiGpuPartition `
            -VMName $VMName `
            -Selector $GPUSelector `
            -LowMemoryMappedIoSpace $GPULowMemoryMappedIoSpace `
            -HighMemoryMappedIoSpace $GPUHighMemoryMappedIoSpace | Out-Null
    }
}


function Add-InstallationMedia {
    $InstallDVD = Add-VMDvdDrive `
        -VMName $VMName `
        -Path $InstallISO `
        -Passthru

    if ($SeedISO) {
        Add-VMDvdDrive `
            -VMName $VMName `
            -Path $SeedISO | Out-Null
    }

    if ($Generation -eq 2) {
        Set-VMFirmware `
            -VMName $VMName `
            -EnableSecureBoot On `
            -SecureBootTemplate MicrosoftUEFICertificateAuthority `
            -FirstBootDevice $InstallDVD
    }
}


function Deploy-Build {
    if ($Installer -eq "calamares") {
        Write-LogInfo "Preparing Calamares live environment..."

        New-VirtualMachine
        Add-InstallationMedia
        return
    }

    $Stage = $null

    try {
        $Stage = New-InstallationMediaStage `
            -UbuntuISO $SourceISO `
            -ConfigPath $ConfigPath `
            -VMName $VMName `
            -Packages $Packages `
            -IPAddress $IPAddress `
            -PrefixLength $PrefixLength `
            -Gateway $Gateway `
            -DnsServers $DnsServers `
            -NetworkInterface $NetworkInterface `
            -InternetNetworkInterface $InternetNetworkInterface

        Publish-InstallationMedia `
            -Stage $Stage `
            -InstallISO $InstallISO `
            -SeedISO $SeedISO

        New-VirtualMachine
        Add-InstallationMedia
    }
    finally {
        Remove-InstallationMediaStage -Stage $Stage
    }
}


# =====================================================================
# Mode change
# =====================================================================

function Stop-VirtualMachineForModeChange {
    param($VM)

    if ($VM.State -eq "Off") { return }

    Write-LogInfo "Stopping virtual machine '$VMName' before applying mode '$EffectiveMode'..."

    Stop-VM `
        -Name $VMName `
        -Force `
        -Confirm:$false

    $Deadline = (Get-Date).AddMinutes(6)

    do {
        Start-Sleep -Milliseconds 500
        $VM = Get-VM -Name $VMName
    }
    while ($VM.State -ne "Off" -and (Get-Date) -lt $Deadline)

    if ($VM.State -ne "Off") {
        throw "Virtual machine '$VMName' did not reach the Off state."
    }
}


function Apply-ModeToExistingVirtualMachine {
    Test-HyperVEnvironment

    $VM = Get-VM -Name $VMName -ErrorAction SilentlyContinue

    if (-not $VM) {
        throw "Virtual machine '$VMName' does not exist. --mode never creates a virtual machine."
    }

    Stop-VirtualMachineForModeChange -VM $VM

    Write-LogInfo "Applying mode '$EffectiveMode' to '$VMName'..."
    Set-VirtualMachineResources -Name $VMName

    Write-LogSuccess "Mode '$EffectiveMode' applied to '$VMName'."
}


# =====================================================================
# Complete
# =====================================================================

function Start-VirtualMachine {
    $VM = Get-VM -Name $VMName -ErrorAction Stop

    if ($VM.State -eq "Running") {
        Write-LogInfo "Virtual machine '$VMName' is already running."
        return
    }

    Write-LogInfo "Starting virtual machine '$VMName'..."
    Start-VM -Name $VMName -ErrorAction Stop | Out-Null
    Write-LogSuccess "Virtual machine '$VMName' started."
}


function Show-BuildSummary {
    Write-LogInfo "Virtual machine: $VMName"
    Write-LogInfo "Mode:            $(if ($EffectiveMode) { $EffectiveMode } else { 'fixed' })"
    Write-LogInfo "CPU:             $ProcessorCount"

    if ($UseDynamicMemory) {
        Write-LogInfo "Memory:          $($MemoryMinimumBytes / 1GB) / $($MemoryStartupBytes / 1GB) / $($MemoryMaximumBytes / 1GB) GB"
    }
    else {
        Write-LogInfo "Memory:          $($MemoryStartupBytes / 1GB) GB static"
    }

    Write-LogInfo "GPU:             $(if ($GPUEnabled) { $GPUSelector } else { 'disabled' })"
    Write-LogInfo "Path:            $VMPath"
    Write-LogInfo "VHDX:            $VHDPath"
    Write-LogInfo "Installer:       $Installer"
    Write-LogInfo "Source ISO:      $SourceISO"
    Write-LogInfo "Install ISO:     $InstallISO"
    Write-LogInfo "Seed ISO:        $(if ($SeedISO) { $SeedISO } else { 'none' })"
    Write-LogInfo "Network config:  $NetworkConfigurationPath"
    Write-LogInfo "Node:            $NodeName"
    Write-LogInfo "IASI switch:     $SwitchName"
    Write-LogInfo "IASI interface:  $NetworkInterface"
    Write-LogInfo "IASI address:    $IPAddress/$PrefixLength"
    Write-LogInfo "Internet switch: $InternetSwitchName"
    Write-LogInfo "Internet iface:  $InternetNetworkInterface"
    Write-LogInfo "Internet:        DHCP"
    Write-LogInfo "Log:             $LogFile"
}


function Show-ModeSummary {
    Write-LogInfo "Virtual machine: $VMName"
    Write-LogInfo "Mode:            $EffectiveMode"
    Write-LogInfo "CPU:             $ProcessorCount"
    Write-LogInfo "Memory:          $($MemoryMinimumBytes / 1GB) / $($MemoryStartupBytes / 1GB) / $($MemoryMaximumBytes / 1GB) GB"
    Write-LogInfo "Log:             $LogFile"
}


function Complete-Build {
    if (-not $NoLaunch) {
        Start-VirtualMachine
    }
    else {
        Write-LogInfo "Virtual machine '$VMName' left powered off."
    }

    Show-BuildSummary
}


function Complete-ModeChange {
    if (-not $NoLaunch) {
        Start-VirtualMachine
    }
    else {
        Write-LogInfo "Virtual machine '$VMName' left powered off."
    }

    Show-ModeSummary
}


# =====================================================================
# Main
# =====================================================================

try {
    Initialize

    if ($ModeSpecified) {
        Apply-ModeToExistingVirtualMachine
        Complete-ModeChange
    }
    else {
        Prepare-Build
        Deploy-Build
        Complete-Build
    }
}
catch {
    Write-RawLog $_
    Write-LogError $_.Exception.Message

    if ($LogFile) {
        Write-LogInfo "See log: $LogFile"
    }

    exit 1
}
