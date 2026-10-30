#requires -RunAsAdministrator
<#
.SYNOPSIS
Creates an IASI Hyper-V virtual machine from declarative TOML configuration.
.USAGE
    .\hyper-v.ps1 --config <path> --path <path> [-f] [-l]
.PARAMETERS
    -f      Recreate an existing VM (destructive).
    -l      Create without starting.
    --config Configuration directory containing config-data/config.toml.
    --path   Base directory for VM files.
.NOTES
    Machine resources and GPU settings are declared in [vm] of config.toml.
    Installer adapters: subiquity, calamares, interactive.
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
    $script:ConfigPath = "."
    $script:TargetPath = $null

    for ($i = 0; $i -lt $ScriptArguments.Count; $i++) {
        switch ($ScriptArguments[$i]) {
            "-f" { $script:Force = $true }
            "-l" { $script:NoLaunch = $true }
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

    $script:UserDataPath = Join-Path $ConfigPath "user-data"
    $script:MetaDataPath = Join-Path $ConfigPath "meta-data"
}


function Import-Configuration {
    # Configuration is data, never executable PowerShell.
    $Base = Read-IasiToml -Path (Join-Path $ConfigDataPath 'config.toml')
    if (-not $Base.Contains('vm')) { throw 'Missing [vm] in config.toml.' }
    $VM = $Base['vm']
    foreach ($Key in @('name','os','installer','generation','disk_size_gb','source_iso')) {
        if (-not $VM.Contains($Key)) { throw "Missing vm.$Key in config.toml." }
    }
    $script:VMName = [string]$VM['name']
    $script:OSType = [string]$VM['os']
    $script:Installer = [string]$VM['installer']
    $script:Generation = [int]$VM['generation']
    $script:DiskSizeBytes = [int64]$VM['disk_size_gb'] * 1GB
    $script:SourceISO = [string]$VM['source_iso']
    if ($VM.Contains('processors')) { $script:ProcessorCount = [int]$VM['processors'] }
    if ($VM.Contains('memory_startup_gb')) { $script:MemoryStartupBytes = [int64]$VM['memory_startup_gb'] * 1GB }
    if ($VM.Contains('memory_minimum_gb')) { $script:MemoryMinimumBytes = [int64]$VM['memory_minimum_gb'] * 1GB }
    if ($VM.Contains('memory_maximum_gb')) { $script:MemoryMaximumBytes = [int64]$VM['memory_maximum_gb'] * 1GB }
    if ($VM.Contains('gpu_enabled')) { $script:GPUEnabled = [bool]$VM['gpu_enabled'] }
    if ($VM.Contains('gpu_selector')) { $script:GPUSelector = [string]$VM['gpu_selector'] }
    if ($VM.Contains('switch')) { $script:SwitchName = [string]$VM['switch'] }
    if ($VM.Contains('path')) { $script:Path = [string]$VM['path'] }

    $PackagesFile = Join-Path $ConfigDataPath 'packages.toml'
    if (Test-Path -LiteralPath $PackagesFile) {
        $Pkg = Read-IasiToml -Path $PackagesFile
        foreach ($category in @('SDK', 'software', 'custom')) {
            if ($Pkg.Contains($category)) {
                foreach ($entry in $Pkg[$category].GetEnumerator()) {
                    if ($entry.Value -isnot [bool]) { throw "Invalid package flag $category / $($entry.Key): boolean required." }
                }
            }
        }
    }

    $SetupFile = Join-Path $ConfigDataPath 'setup.toml'
    if (Test-Path -LiteralPath $SetupFile) {
        $Data = Read-IasiToml -Path $SetupFile
        if (-not $Data.Contains('setup')) { throw 'Expected [setup] in setup.toml.' }
        $Setup = $Data['setup']
        if ($Setup.Contains('profile')) { $script:SetupProfile = [string]$Setup['profile'] }
        if ($Setup.Contains('user')) { $script:SetupUser = [string]$Setup['user'] }
        if ($Setup.Contains('password')) { $script:SetupPassword = [string]$Setup['password'] }
    }
}


function Get-IasiInstallerAdapter {
    param([Parameter(Mandatory)][string]$Name)
    switch ($Name.ToLowerInvariant()) {
        'subiquity'   { return 'subiquity' }
        'calamares'   { return 'calamares' }
        'interactive' { return 'windows-interactive' }
        default { throw "IASI installer adapter not registered: $Name" }
    }
}

function Resolve-InstallerConfiguration {
    if (-not $OSType) {
        # Compatibility with existing IASI Linux node configurations.
        $script:OSType = "linux"
    }
    $script:OSType = ([string]$OSType).ToLowerInvariant()
    if ($OSType -notin @("linux", "windows")) {
        throw "Unsupported OSType '$OSType'. Supported: linux, windows."
    }

    if (-not $Installer) {
        $script:Installer = if ($OSType -eq "windows") { "interactive" } else { "subiquity" }
    }
    $script:Installer = ([string]$Installer).ToLowerInvariant()

    # Installer adapters are registered here; VM configuration selects an adapter.
    $InstallerAdapters = @{
        'subiquity'   = 'linux'
        'calamares'   = 'linux'
        'interactive' = 'windows'
    }
    if (-not $InstallerAdapters.ContainsKey($Installer)) {
        throw "Unsupported installer '$Installer'. Available: $($InstallerAdapters.Keys -join ', ')."
    }
    if ($OSType -ne $InstallerAdapters[$Installer]) {
        throw "Installer '$Installer' requires OS '$($InstallerAdapters[$Installer])', but VM declares '$OSType'."
    }
    if ($OSType -eq "windows" -and $Generation -ne 2) {
        throw "Windows 11 IASI guests require generation 2."
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

    # Windows profile values are provided by config-data/setup.toml.
    if ($OSType -eq "windows" -and $Installer -eq "interactive" -and
        (-not $SetupProfile -or -not $SetupUser -or $null -eq $SetupPassword)) {
        throw "Missing SetupProfile, SetupUser or SetupPassword in config-data."
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
        "interactive" {
            # The unmodified ISO is attached for manual installation.
        }

        default {
            throw "Unsupported installer '$Installer'. Supported installers: subiquity, calamares, interactive."
        }
    }
}


function Resolve-ResourceConfiguration {
    if ($null -eq $ProcessorCount -or $ProcessorCount -lt 1) { throw 'vm.processors must be a positive integer.' }
    if ($null -eq $MemoryStartupBytes -or $MemoryStartupBytes -le 0) { throw 'vm.memory_startup_gb must be positive.' }
    $script:UseDynamicMemory = ($null -ne $MemoryMinimumBytes -or $null -ne $MemoryMaximumBytes)
    if ($UseDynamicMemory) {
        if ($null -eq $MemoryMinimumBytes) { $script:MemoryMinimumBytes = $MemoryStartupBytes }
        if ($null -eq $MemoryMaximumBytes) { $script:MemoryMaximumBytes = $MemoryStartupBytes }
        if ($MemoryMinimumBytes -le 0 -or $MemoryMinimumBytes -gt $MemoryStartupBytes -or $MemoryStartupBytes -gt $MemoryMaximumBytes) {
            throw 'Invalid vm.memory_minimum_gb / memory_startup_gb / memory_maximum_gb relationship.'
        }
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


function Import-ServicePorts {
    $script:ServicePorts = @{}
    $Path = Join-Path $IASIRoot "config\\ports.toml"
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing shared service port configuration '$Path'."
    }
    $Ports = Read-IasiToml -Path $Path
    foreach ($Service in @($Ports.Keys)) {
        $Entry = $Ports[$Service]
        if (-not $Entry.Contains('node') -or -not $Entry.Contains('host') -or -not $Entry.Contains('container')) {
            throw "Service '$Service' must declare node, host and container in ports.toml."
        }
        $HostPort = [int]$Entry['host']
        $ContainerPort = [int]$Entry['container']
        if ($HostPort -lt 1 -or $HostPort -gt 65535 -or $ContainerPort -lt 1 -or $ContainerPort -gt 65535) {
            throw "Invalid ports for '$Service'."
        }
        if ([string]$Entry['node'] -ne $NodeName) { continue }
        $Key = 'IASI_' + ($Service.ToUpperInvariant() -replace '[^A-Z0-9]', '_') + '_PORT'
        if ($ServicePorts.ContainsKey($Key)) { throw "Duplicate service port variable '$Key'." }
        if (@($ServicePorts.Values) -contains $HostPort) { throw "Duplicate published port $HostPort on node '$NodeName'." }
        $ServicePorts[$Key] = $HostPort
        Write-LogInfo "Port configuration: $Service -> $HostPort (container $ContainerPort)"
    }
}

function Initialize {
    Read-Arguments
    Initialize-Log "hyper-v"
    Resolve-IasiRoot
    Resolve-ConfigurationPath
    Import-Configuration
    Resolve-InstallerConfiguration
    Resolve-ResourceConfiguration
    Resolve-GpuConfiguration

    Import-NetworkConfiguration
    Import-ServicePorts
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
        Stop-VM -Name $VMName -TurnOff -Force -ErrorAction Stop
    }

    Remove-VM -Name $VMName -Force -ErrorAction Stop

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


function Test-WindowsSetupPrerequisites {
    if ($OSType -ne "windows" -or $Installer -ne "interactive") { return }
    if ($SetupProfile -ne "win-dev") {
        throw "Unsupported Windows setup profile '$SetupProfile' (supported: win-dev)."
    }
    if ($SetupUser -notmatch '^[a-zA-Z][a-zA-Z0-9_.-]{0,19}$') {
        throw "SetupUser must start with a letter and contain only letters, digits, underscores, dots or hyphens (max 20)."
    }
    if ([string]::IsNullOrEmpty([string]$SetupPassword)) {
        throw "SetupPassword must not be empty."
    }
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        throw "wsl.exe is unavailable. WSL and xorriso are required for win-dev setup media."
    }
    & wsl.exe --exec sh -c 'command -v xorriso >/dev/null 2>&1'
    if ($LASTEXITCODE -ne 0) {
        throw "xorriso was not found in the default WSL distribution. No VM has been removed."
    }

}

function New-WindowsSetupMedia {
    # Global IASI staging directory. VM creation is sequential.
    # Media must remain present while the interactive OS installation runs.
    $TempRoot = Join-Path $env:TEMP "iasi"
    New-Item -ItemType Directory -Force -Path $TempRoot -ErrorAction Stop | Out-Null
    $StageDir = Join-Path $TempRoot "setup-content"
    # Only remove our own staging files; avoid touching unrelated TEMP data.
    foreach ($Name in @("setup.iso", "setup.building.iso", "setup-content")) {
        $Target = Join-Path $TempRoot $Name
        if (Test-Path -LiteralPath $Target) {
            Remove-Item -LiteralPath $Target -Recurse -Force -ErrorAction Stop
        }
    }
    New-Item -ItemType Directory -Force -Path $StageDir -ErrorAction Stop | Out-Null
    $UserXml = [System.Security.SecurityElement]::Escape([string]$SetupUser)
    $PasswordXml = [System.Security.SecurityElement]::Escape([string]$SetupPassword)
    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <!-- Valid windowsPE settings make this answer file applicable at initial Setup discovery. -->
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <SetupUILanguage>
        <UILanguage>es-ES</UILanguage>
      </SetupUILanguage>
      <InputLocale>es-ES</InputLocale>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <OOBE>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>IASI Windows development bootstrap</Description>
          <CommandLine>powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "&amp; { `$script = Get-PSDrive -PSProvider FileSystem | ForEach-Object { Join-Path `$_.Root 'iasi\launch-bootstrap.ps1' } | Where-Object { Test-Path -LiteralPath `$_ } | Select-Object -First 1; if (-not `$script) { throw 'IASI launcher not found on setup.iso' }; &amp; `$script }"</CommandLine>
        </SynchronousCommand>
      </FirstLogonCommands>
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Name>$UserXml</Name>
            <DisplayName>$UserXml</DisplayName>
            <Group>Administrators</Group>
            <Password>
              <Value>$PasswordXml</Value>
              <PlainText>true</PlainText>
            </Password>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>
    </component>
  </settings>
</unattend>
"@
    $Autounattend = Join-Path $StageDir "Autounattend.xml"
    [System.IO.File]::WriteAllText($Autounattend, $xml, [System.Text.UTF8Encoding]::new($false))
    [xml](Get-Content -LiteralPath $Autounattend -Raw -ErrorAction Stop) | Out-Null

    $ReadmeDir = Join-Path $StageDir "iasi"
    New-Item -ItemType Directory -Force -Path $ReadmeDir -ErrorAction Stop | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $ReadmeDir 'README.txt'), "IASI profile: $SetupProfile`r`nInteractive Windows installation, local account configured by Autounattend.xml.`r`nChange the default lab password after installation if required.`r`n")

    # Bootstrap resources are packaged inside setup.iso, not installed on host.
    $BootstrapSource = Join-Path $PSScriptRoot "windows\bootstrap.ps1"
    if (-not (Test-Path -LiteralPath $BootstrapSource -PathType Leaf)) {
        throw "Windows bootstrap script missing: $BootstrapSource"
    }
    Copy-Item -LiteralPath $BootstrapSource -Destination (Join-Path $ReadmeDir 'bootstrap.ps1') -ErrorAction Stop
    foreach ($actionName in @('directories','drives','git','organization')) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('windows\action-' + $actionName + '.ps1')) -Destination (Join-Path $ReadmeDir ('action-' + $actionName + '.ps1')) -Force -ErrorAction Stop }
    $LauncherSource = Join-Path $PSScriptRoot 'windows\launch-bootstrap.ps1'
    Copy-Item -LiteralPath $LauncherSource -Destination (Join-Path $ReadmeDir 'launch-bootstrap.ps1') -ErrorAction Stop
    # The VM's declarative services are packaged beside the common bootstrap.
    $ServicesSource = Join-Path $ConfigPath 'services'
    if (-not (Test-Path -LiteralPath (Join-Path $ServicesSource 'services.toml') -PathType Leaf)) {
        throw "Missing Windows services manifest: $ServicesSource\services.toml"
    }
    Copy-Item -LiteralPath $ServicesSource -Destination (Join-Path $ReadmeDir 'services') -Recurse -Force -ErrorAction Stop
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'common\toml.ps1') -Destination (Join-Path $ReadmeDir 'toml.ps1') -Force -ErrorAction Stop
    # Optional node software catalog, staged beside the service manifest.
    $PackageManifest = Join-Path $ConfigDataPath 'packages.toml'
    if (Test-Path -LiteralPath $PackageManifest) {
        Copy-Item -LiteralPath $PackageManifest -Destination (Join-Path $ReadmeDir 'services\packages.toml') -Force -ErrorAction Stop
    }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'windows\install-packages.ps1') -Destination (Join-Path $ReadmeDir 'install-packages.ps1') -Force -ErrorAction Stop
    foreach ($name in @('install-software.ps1','run-packages-on-logon.ps1')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('windows\' + $name)) -Destination (Join-Path $ReadmeDir $name) -Force -ErrorAction Stop
    }


    # Microsoft Windows Setup searches removable read-only media for Autounattend.xml.
    # Keep the vendor Windows ISO intact (including its hidden EFI El Torito images).
    # Our separate IASI_SETUP DVD contains Autounattend.xml at its root and the scripts.
    $script:InstallISO = $SourceISO
    $script:SeedISO = Join-Path $TempRoot "setup.iso"
    $TmpSetup = Join-Path $TempRoot "setup.building.iso"
    $StageLinux = (& wsl.exe --exec wslpath -a -u $StageDir | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $StageLinux) { throw "Cannot translate staging path into WSL." }
    $SetupLinux = (& wsl.exe --exec wslpath -a -u $TmpSetup | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $SetupLinux) { throw "Cannot translate setup ISO path into WSL." }
    & wsl.exe --exec xorriso -as mkisofs -J -R -V IASI_SETUP -o $SetupLinux $StageLinux
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $TmpSetup -PathType Leaf)) {
        throw "Failed to generate setup.iso with WSL xorriso (exit code $LASTEXITCODE)."
    }
    Move-Item -LiteralPath $TmpSetup -Destination $SeedISO -Force -ErrorAction Stop
    Remove-Item -LiteralPath $StageDir -Recurse -Force -ErrorAction Stop
    Write-LogInfo "Prepared original Windows ISO and separate IASI_SETUP answer media: $InstallISO; $SeedISO"
    Write-LogWarning "setup.iso contains a plaintext lab password. Do not distribute it."
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
        "interactive" {
            if ($OSType -eq "windows") {
                New-WindowsSetupMedia
            }
            else {
                $script:InstallISO = $SourceISO
                $script:SeedISO = $null
            }
        }
    }
}


function Prepare-Build {
    Test-BuildConfiguration
    Test-BuildEnvironment
    if ((Get-VM -Name $VMName -ErrorAction SilentlyContinue) -and -not $Force) {
        Write-LogWarning "Virtual machine '$VMName' already exists. Use -f to recreate it."
        exit 0
    }
    Test-WindowsSetupPrerequisites
    if ($GPUEnabled) {
        $script:SelectedGPU = Select-IasiGpu -Selector $GPUSelector
        Write-LogInfo "GPU selected: $($SelectedGPU.FriendlyName)"
        Write-LogInfo "GPU classification: $($SelectedGPU.Kind)"
        Write-LogInfo "GPU classification reason: $($SelectedGPU.Reason)"
        Write-LogInfo "GPU-P device path: $($SelectedGPU.Name)"
        Write-LogInfo "GPU guest driver / CUDA support remains unverified."
    }
    # If recreating a Windows VM, release ISO file handles held by its old DVD drives
    # before replacing the shared temporary installation media.
    if ($Force -and $OSType -eq "windows" -and $Installer -eq "interactive") {
        $ExistingVM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
        if ($ExistingVM) {
            if ($ExistingVM.State -ne 'Off') { Stop-VM -Name $VMName -Force -TurnOff -ErrorAction Stop }
            Get-VMDvdDrive -VMName $VMName -ErrorAction Stop | Where-Object {
                $_.Path -and ($_.Path -eq (Join-Path $env:TEMP 'iasi\os.iso') -or $_.Path -eq (Join-Path $env:TEMP 'iasi\setup.iso'))
            } | Set-VMDvdDrive -Path $null -ErrorAction Stop
        }
    }
    # Validate toolchain before potentially destructive -f operations.
    # Stage media before destructive -f. Failure here preserves any existing VM.
    if ($OSType -eq "windows" -and $Installer -eq "interactive") {
        Write-LogInfo "Generando ISOs..."
        Resolve-InstallationMediaPaths
    }
    Resolve-ExistingVMForBuild
    Resolve-Paths
    if ($GPUEnabled -and $Installer -eq "subiquity") {
        Copy-IasiGpuGuestResources -GPU $SelectedGPU -ConfigPath $ConfigPath
    }
    if ($OSType -ne "windows" -or $Installer -ne "interactive") {
        Resolve-InstallationMediaPaths
    }

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
        -Count $ProcessorCount `
        -ErrorAction Stop

    if ($UseDynamicMemory) {
        Set-VMMemory `
            -VMName $Name `
            -DynamicMemoryEnabled $true `
            -MinimumBytes $MemoryMinimumBytes `
            -StartupBytes $MemoryStartupBytes `
            -MaximumBytes $MemoryMaximumBytes `
            -ErrorAction Stop
    }
    else {
        Set-VMMemory `
            -VMName $Name `
            -DynamicMemoryEnabled $false `
            -StartupBytes $MemoryStartupBytes `
            -ErrorAction Stop
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
        -SwitchName $SwitchName -ErrorAction Stop | Out-Null

    Add-VMNetworkAdapter `
        -VMName $VMName `
        -SwitchName $InternetSwitchName `
        -Name "Internet" -ErrorAction Stop | Out-Null

    Set-VirtualMachineResources -Name $VMName

    Set-VM `
        -Name $VMName `
        -AutomaticCheckpointsEnabled $false `
        -ErrorAction Stop

    if ($GPUEnabled) {
        Add-IasiGpuPartition `
            -VMName $VMName `
            -GPU $SelectedGPU `
            -LowMemoryMappedIoSpace $GPULowMemoryMappedIoSpace `
            -HighMemoryMappedIoSpace $GPUHighMemoryMappedIoSpace | Out-Null
    }
}


function Add-InstallationMedia {
    $InstallDVD = Add-VMDvdDrive `
        -VMName $VMName `
        -Path $InstallISO `
        -Passthru `
        -ErrorAction Stop

    if ($SeedISO) {
        Add-VMDvdDrive `
            -VMName $VMName `
            -Path $SeedISO `
            -ErrorAction Stop | Out-Null
    }

    if ($Generation -ne 2) { return }

    if ($OSType -eq "windows") {
        # The VM already uses the MicrosoftWindows template by default.
        # Some hosts reject explicitly reapplying that template, even though
        # enabling Secure Boot alone succeeds. Preserve the existing template.
        $Firmware = Get-VMFirmware -VMName $VMName -ErrorAction Stop
        if ($Firmware.SecureBootTemplate -ne "MicrosoftWindows") {
            throw "Windows VM '$VMName' has unexpected Secure Boot template '$($Firmware.SecureBootTemplate)'. Refusing to change it implicitly."
        }

        Set-VMFirmware `
            -VMName $VMName `
            -EnableSecureBoot On `
            -FirstBootDevice $InstallDVD `
            -ErrorAction Stop

        $Firmware = Get-VMFirmware -VMName $VMName -ErrorAction Stop
        if ($Firmware.SecureBoot -ne "On") {
            throw "Secure Boot verification failed for '$VMName' (current: $($Firmware.SecureBoot))."
        }

        Set-VMKeyProtector `
            -VMName $VMName `
            -NewLocalKeyProtector `
            -ErrorAction Stop

        Enable-VMTPM `
            -VMName $VMName `
            -ErrorAction Stop

        Write-LogInfo "Secure Boot: On (MicrosoftWindows); virtual TPM: enabled"
        return
    }

    # Linux: default off for disposable labs; allow UEFI CA when enabled.
    $SecureBootState = if ($SecureBootEnabled -eq $true) { "On" } else { "Off" }
    if ($SecureBootState -eq "On") {
        Set-VMFirmware `
            -VMName $VMName `
            -EnableSecureBoot On `
            -SecureBootTemplate "MicrosoftUEFICertificateAuthority" `
            -FirstBootDevice $InstallDVD `
            -ErrorAction Stop
    }
    else {
        Set-VMFirmware `
            -VMName $VMName `
            -EnableSecureBoot Off `
            -FirstBootDevice $InstallDVD `
            -ErrorAction Stop
    }
    Write-LogInfo "Secure Boot: $SecureBootState"
}

function Deploy-Build {
    if ($Installer -in @("calamares", "interactive")) {
        Write-LogInfo "Preparing direct ISO installation ($Installer)..."

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
            -ServicePorts $ServicePorts `
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
# Build completion
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
    Write-LogInfo "CPU:             $ProcessorCount"

    if ($UseDynamicMemory) {
        Write-LogInfo "Memory:          $($MemoryMinimumBytes / 1GB) / $($MemoryStartupBytes / 1GB) / $($MemoryMaximumBytes / 1GB) GB"
    }
    else {
        Write-LogInfo "Memory:          $($MemoryStartupBytes / 1GB) GB static"
    }

    Write-LogInfo "GPU:             $(if ($GPUEnabled) { $SelectedGPU.FriendlyName } else { 'disabled' })"
    Write-LogInfo "Path:            $VMPath"
    Write-LogInfo "VHDX:            $VHDPath"
    Write-LogInfo "OS type:         $OSType"
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


function Complete-Build {
    # Provisioning only: VM remains off regardless of installer or OS.
    # No guest installation, startup, operator pause or readiness check here.
    $state = (Get-VM -Name $VMName -ErrorAction Stop).State
    if ($state -ne 'Off') {
        throw "Provisioning must leave VM '$VMName' powered off; actual state: $state"
    }
    Write-LogInfo "VM '$VMName' provisioned and powered off. Guest setup occurs at first manual boot."
    Show-BuildSummary
}

# =====================================================================
# Main
# =====================================================================

try {
    Initialize

    Prepare-Build
    Deploy-Build
    Complete-Build
}
catch {
    Write-RawLog $_
    Write-LogError $_.Exception.Message

    if ($LogFile) {
        Write-LogInfo "See log: $LogFile"
    }

    exit 1
}
