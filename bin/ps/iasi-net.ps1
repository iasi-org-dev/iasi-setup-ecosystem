#requires -RunAsAdministrator
<#
.SYNOPSIS
Materializes the IASI private Hyper-V network on the Windows host.

.DESCRIPTION
Creates and maintains the Windows-side networking required by IASI virtual
machines.

The network topology itself is not defined in this script. Its source of truth
is:

    config\iasi-net.toml

The script locates that file relative to its own repository position, not
relative to the current working directory. Therefore it can be invoked from
any directory as long as the canonical IASI repository structure is kept:

    iasi-dev-tools\
    ├── bin\
    │   └── ps\
    │       ├── iasi-net.ps1
    │       └── common\
    └── config\
        └── iasi-net.toml

The script materializes:
- The Hyper-V internal switch declared by network.name.
- The gateway address declared by network.gateway.
- The Windows/iasi-dev host address declared by nodes.iasi-dev.
- The NAT declared by nat.name and network.subnet.
- A managed IASI block in the Windows hosts file from the [nodes] table.

The gateway address is configured with SkipAsSource enabled so Windows normally
originates traffic using the iasi-dev host address instead of the gateway.

The DNS servers declared in the TOML are loaded and validated here but are not
configured on the Windows vEthernet adapter. They are shared network metadata
intended primarily for guest configuration by hyper-v.ps1.

The script is intentionally idempotent. Running it again should leave an
already-correct IASI network unchanged.

It owns only the switch, NAT and host-side IPv4 addresses belonging to the
IASI network. It never removes unrelated Hyper-V switches or NAT definitions.

.CONFIGURATION
Network topology:

    config\iasi-net.toml

Script behaviour is configured at the beginning of this file:

    $NetworkConfigurationFile
        Repository-relative path to the network TOML.

    $RemoveUnexpectedIPv4
        When true, removes stale IPv4 addresses from the IASI virtual adapter
        that are neither the configured gateway nor the configured host IP.

    $AdapterTimeoutSeconds
        Maximum time to wait for Windows to expose vEthernet after creating
        the Hyper-V internal switch.

    $AdapterPollMilliseconds
        Poll interval while waiting for the virtual adapter.

    $HostsBeginMarker / $HostsEndMarker
        Delimit the block owned by IASI inside the Windows hosts file.
        Everything outside this block is preserved unchanged.

The hosts file location is derived from $env:SystemRoot and is never
hard-coded to C:\Windows.

.REQUIREMENTS
- Windows with Hyper-V enabled.
- Hyper-V PowerShell module.
- NetTCPIP and NetNat PowerShell cmdlets.
- PowerShell executed as Administrator.
- bin\ps\common\toml.ps1.

.USAGE
Run from any directory:

    iasi-net.ps1

No command-line parameters are currently required.

.NOTES
IASI Infrastructure

Network values belong to iasi-net.toml so that iasi-net.ps1, hyper-v.ps1 and
future infrastructure consumers share one source of truth.
#>


. "$PSScriptRoot\common\log.ps1"
. "$PSScriptRoot\common\messages.ps1"
. "$PSScriptRoot\common\toml.ps1"


# =====================================================================
# Configuration
# =====================================================================

$NetworkConfigurationFile = "config\iasi-net.toml"

$RemoveUnexpectedIPv4 = $true
$AdapterTimeoutSeconds = 15
$AdapterPollMilliseconds = 250

$HostsBeginMarker = "# BEGIN IASI"
$HostsEndMarker = "# END IASI"


# =====================================================================
# Repository and network configuration
# =====================================================================

function Resolve-Configuration {
    $script:IASIRoot = [System.IO.Path]::GetFullPath(
        (Join-Path $PSScriptRoot "..\..")
    )

    $script:NetworkConfigurationPath = Join-Path `
        $IASIRoot `
        $NetworkConfigurationFile

    Write-LogInfo "Network configuration: $NetworkConfigurationPath"

    $Configuration = Read-IasiToml -Path $NetworkConfigurationPath

    foreach ($Section in @("network", "nat", "dns", "nodes")) {
        if (-not $Configuration.Contains($Section)) {
            throw "Missing [$Section] section in '$NetworkConfigurationPath'."
        }
    }

    $Network = $Configuration["network"]
    $Nat = $Configuration["nat"]
    $Dns = $Configuration["dns"]
    $Nodes = $Configuration["nodes"]

    foreach ($Key in @("name", "subnet", "prefix-length", "gateway")) {
        if (-not $Network.Contains($Key)) {
            throw "Missing network.$Key in '$NetworkConfigurationPath'."
        }
    }

    if (-not $Nat.Contains("name")) {
        throw "Missing nat.name in '$NetworkConfigurationPath'."
    }

    if (-not $Dns.Contains("servers")) {
        throw "Missing dns.servers in '$NetworkConfigurationPath'."
    }

    if (-not $Nodes.Contains("iasi-dev")) {
        throw "Missing nodes.iasi-dev in '$NetworkConfigurationPath'."
    }

    $script:SwitchName = [string]$Network["name"]
    $script:Subnet = [string]$Network["subnet"]
    $script:PrefixLength = [int]$Network["prefix-length"]
    $script:GatewayAddress = [string]$Network["gateway"]
    $script:HostAddress = [string]$Nodes["iasi-dev"]
    $script:NatName = [string]$Nat["name"]
    $script:DnsServers = @($Dns["servers"])
    $script:Nodes = $Nodes

    $script:InterfaceAlias = "vEthernet ($SwitchName)"
}


# =====================================================================
# Validation
# =====================================================================

function Test-Environment {
    if (-not (Get-Module -ListAvailable -Name Hyper-V)) {
        throw "Hyper-V PowerShell module is not available."
    }

    foreach ($Command in @(
        "Get-NetAdapter",
        "Get-NetIPAddress",
        "New-NetIPAddress",
        "Set-NetIPAddress",
        "Remove-NetIPAddress",
        "Get-NetNat",
        "New-NetNat",
        "Remove-NetNat"
    )) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required PowerShell command '$Command' is not available."
        }
    }
}

function Test-Configuration {
    if (-not $SwitchName) {
        throw "network.name cannot be empty."
    }

    if (-not $NatName) {
        throw "nat.name cannot be empty."
    }

    if ($PrefixLength -lt 1 -or $PrefixLength -gt 32) {
        throw "network.prefix-length must be between 1 and 32."
    }

    if ($Subnet -notmatch '/(\d+)$') {
        throw "network.subnet must use CIDR notation."
    }

    if ([int]$Matches[1] -ne $PrefixLength) {
        throw "network.subnet '$Subnet' and network.prefix-length '$PrefixLength' disagree."
    }

    $Parsed = $null

    if (-not [System.Net.IPAddress]::TryParse($GatewayAddress, [ref]$Parsed)) {
        throw "network.gateway '$GatewayAddress' is not a valid IP address."
    }

    $Parsed = $null

    if (-not [System.Net.IPAddress]::TryParse($HostAddress, [ref]$Parsed)) {
        throw "nodes.iasi-dev '$HostAddress' is not a valid IP address."
    }

    if ($GatewayAddress -eq $HostAddress) {
        throw "network.gateway and nodes.iasi-dev must be different."
    }

    $SeenNodeAddresses = @{}

    foreach ($NodeName in $Nodes.Keys) {
        $NodeAddress = [string]$Nodes[$NodeName]
        $Parsed = $null

        if (-not [System.Net.IPAddress]::TryParse($NodeAddress, [ref]$Parsed)) {
            throw "nodes.$NodeName '$NodeAddress' is not a valid IP address."
        }

        if ($NodeAddress -eq $GatewayAddress) {
            throw "nodes.$NodeName cannot use gateway address '$GatewayAddress'."
        }

        if ($SeenNodeAddresses.ContainsKey($NodeAddress)) {
            throw "Duplicate node address '$NodeAddress' used by '$($SeenNodeAddresses[$NodeAddress])' and '$NodeName'."
        }

        $SeenNodeAddresses[$NodeAddress] = $NodeName
    }

    if ($DnsServers.Count -eq 0) {
        throw "dns.servers must contain at least one DNS server."
    }

    foreach ($DnsServer in $DnsServers) {
        $Parsed = $null

        if (-not [System.Net.IPAddress]::TryParse([string]$DnsServer, [ref]$Parsed)) {
            throw "DNS server '$DnsServer' is not a valid IP address."
        }
    }
}


# =====================================================================
# Hyper-V switch
# =====================================================================

function Resolve-VirtualSwitch {
    $Switch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue

    if (-not $Switch) {
        Write-LogInfo "Creating Hyper-V internal switch '$SwitchName'..."
        New-VMSwitch -Name $SwitchName -SwitchType Internal | Out-Null
        return
    }

    if ($Switch.SwitchType -ne "Internal") {
        throw "Hyper-V switch '$SwitchName' exists but is '$($Switch.SwitchType)', expected 'Internal'."
    }

    Write-LogInfo "Hyper-V internal switch '$SwitchName' already exists."
}

function Resolve-VirtualAdapter {
    $Deadline = (Get-Date).AddSeconds($AdapterTimeoutSeconds)

    do {
        $Adapter = Get-NetAdapter -Name $InterfaceAlias -ErrorAction SilentlyContinue

        if ($Adapter) {
            return $Adapter
        }

        Start-Sleep -Milliseconds $AdapterPollMilliseconds
    }
    while ((Get-Date) -lt $Deadline)

    throw "Windows network adapter '$InterfaceAlias' was not created within $AdapterTimeoutSeconds seconds."
}


# =====================================================================
# Host addresses
# =====================================================================

function Remove-UnexpectedIPv4Addresses {
    if (-not $RemoveUnexpectedIPv4) {
        return
    }

    $Expected = @($GatewayAddress, $HostAddress)

    $Addresses = @(
        Get-NetIPAddress `
            -InterfaceAlias $InterfaceAlias `
            -AddressFamily IPv4 `
            -ErrorAction SilentlyContinue
    )

    foreach ($Address in $Addresses) {
        if ($Expected -contains $Address.IPAddress) {
            continue
        }

        Write-LogWarning "Removing unexpected IPv4 address '$($Address.IPAddress)/$($Address.PrefixLength)' from '$InterfaceAlias'."

        Remove-NetIPAddress `
            -InterfaceAlias $InterfaceAlias `
            -IPAddress $Address.IPAddress `
            -Confirm:$false
    }
}

function Set-IasiIPAddress {
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,

        [Parameter(Mandatory = $true)]
        [bool]$SkipAsSource
    )

    $Conflicts = @(
        Get-NetIPAddress `
            -AddressFamily IPv4 `
            -IPAddress $IPAddress `
            -ErrorAction SilentlyContinue |
        Where-Object {
            $_.InterfaceAlias -ne $InterfaceAlias
        }
    )

    if ($Conflicts.Count -gt 0) {
        $ConflictInterfaces = (
            $Conflicts |
            Select-Object -ExpandProperty InterfaceAlias -Unique
        ) -join ", "

        throw "IPv4 address '$IPAddress' is already assigned outside '$InterfaceAlias': $ConflictInterfaces."
    }

    $Existing = Get-NetIPAddress `
        -InterfaceAlias $InterfaceAlias `
        -AddressFamily IPv4 `
        -IPAddress $IPAddress `
        -ErrorAction SilentlyContinue

    if ($Existing -and $Existing.PrefixLength -ne $PrefixLength) {
        Write-LogWarning "Recreating '$IPAddress' with prefix length $PrefixLength."

        Remove-NetIPAddress `
            -InterfaceAlias $InterfaceAlias `
            -IPAddress $IPAddress `
            -Confirm:$false

        $Existing = $null
    }

    if (-not $Existing) {
        Write-LogInfo "Assigning '$IPAddress/$PrefixLength' to '$InterfaceAlias'..."

        New-NetIPAddress `
            -InterfaceAlias $InterfaceAlias `
            -IPAddress $IPAddress `
            -PrefixLength $PrefixLength `
            -AddressFamily IPv4 `
            -SkipAsSource $SkipAsSource | Out-Null

        return
    }

    if ([bool]$Existing.SkipAsSource -ne $SkipAsSource) {
        Write-LogInfo "Updating SkipAsSource for '$IPAddress' to '$SkipAsSource'..."

        Set-NetIPAddress `
            -InterfaceAlias $InterfaceAlias `
            -IPAddress $IPAddress `
            -SkipAsSource $SkipAsSource
    }
    else {
        Write-LogInfo "IPv4 address '$IPAddress/$PrefixLength' is already configured."
    }
}

function Resolve-HostAddresses {
    Remove-UnexpectedIPv4Addresses

    Set-IasiIPAddress `
        -IPAddress $GatewayAddress `
        -SkipAsSource $true

    Set-IasiIPAddress `
        -IPAddress $HostAddress `
        -SkipAsSource $false
}


# =====================================================================
# NAT
# =====================================================================

function Resolve-Nat {
    $ConflictingNat = @(
        Get-NetNat -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -ne $NatName -and
            $_.InternalIPInterfaceAddressPrefix -eq $Subnet
        }
    )

    if ($ConflictingNat.Count -gt 0) {
        $Names = (
            $ConflictingNat |
            Select-Object -ExpandProperty Name -Unique
        ) -join ", "

        throw "Subnet '$Subnet' is already owned by another NAT definition: $Names."
    }

    $Nat = Get-NetNat -Name $NatName -ErrorAction SilentlyContinue

    if (-not $Nat) {
        Write-LogInfo "Creating NAT '$NatName' for '$Subnet'..."

        New-NetNat `
            -Name $NatName `
            -InternalIPInterfaceAddressPrefix $Subnet | Out-Null

        return
    }

    if ($Nat.InternalIPInterfaceAddressPrefix -ne $Subnet) {
        Write-LogWarning "NAT '$NatName' uses '$($Nat.InternalIPInterfaceAddressPrefix)', expected '$Subnet'."
        Write-LogInfo "Recreating owned NAT '$NatName'..."

        Remove-NetNat `
            -Name $NatName `
            -Confirm:$false

        New-NetNat `
            -Name $NatName `
            -InternalIPInterfaceAddressPrefix $Subnet | Out-Null

        return
    }

    Write-LogInfo "NAT '$NatName' already maps '$Subnet'."
}


# =====================================================================
# Windows hosts file
# =====================================================================

function Resolve-HostsFile {
    if (-not $env:SystemRoot) {
        throw "SystemRoot environment variable is not defined."
    }

    $HostsPath = Join-Path `
        $env:SystemRoot `
        "System32\drivers\etc\hosts"

    if (-not (Test-Path $HostsPath -PathType Leaf)) {
        throw "Windows hosts file '$HostsPath' does not exist."
    }

    $OriginalText = [System.IO.File]::ReadAllText($HostsPath)

    $NewLine = if ($OriginalText.Contains("`r`n")) {
        "`r`n"
    }
    else {
        "`n"
    }

    $Lines = @(
        if ($OriginalText.Length -eq 0) {
            @()
        }
        else {
            $OriginalText -split "`r?`n", -1
        }
    )

    $BeginIndexes = @()
    $EndIndexes = @()

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i].Trim() -eq $HostsBeginMarker) {
            $BeginIndexes += $i
        }

        if ($Lines[$i].Trim() -eq $HostsEndMarker) {
            $EndIndexes += $i
        }
    }

    if ($BeginIndexes.Count -gt 1 -or $EndIndexes.Count -gt 1) {
        throw "Windows hosts file contains multiple IASI managed blocks."
    }

    if ($BeginIndexes.Count -ne $EndIndexes.Count) {
        throw "Windows hosts file contains an incomplete IASI managed block."
    }

    $ManagedBlock = @($HostsBeginMarker)

    foreach ($NodeName in $Nodes.Keys) {
        $NodeAddress = [string]$Nodes[$NodeName]
        $ManagedBlock += ("{0}`t{1}" -f $NodeAddress, $NodeName)
    }

    $ManagedBlock += $HostsEndMarker

    if ($BeginIndexes.Count -eq 1) {
        $BeginIndex = $BeginIndexes[0]
        $EndIndex = $EndIndexes[0]

        if ($EndIndex -lt $BeginIndex) {
            throw "Windows hosts file contains an invalid IASI managed block."
        }

        $Before = if ($BeginIndex -gt 0) {
            @($Lines[0..($BeginIndex - 1)])
        }
        else {
            @()
        }

        $After = if ($EndIndex + 1 -lt $Lines.Count) {
            @($Lines[($EndIndex + 1)..($Lines.Count - 1)])
        }
        else {
            @()
        }

        $ResultLines = @($Before) + $ManagedBlock + @($After)
    }
    else {
        $ResultLines = @($Lines)

        while ($ResultLines.Count -gt 0 -and $ResultLines[-1] -eq "") {
            if ($ResultLines.Count -eq 1) {
                $ResultLines = @()
                break
            }

            $ResultLines = @($ResultLines[0..($ResultLines.Count - 2)])
        }

        if ($ResultLines.Count -gt 0) {
            $ResultLines += ""
        }

        $ResultLines += $ManagedBlock
        $ResultLines += ""
    }

    $NewText = $ResultLines -join $NewLine

    if ($NewText -eq $OriginalText) {
        Write-LogInfo "Windows hosts file is already synchronized with IASI nodes."
        return
    }

    $UTF8 = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($HostsPath, $NewText, $UTF8)

    if (Get-Command Clear-DnsClientCache -ErrorAction SilentlyContinue) {
        Clear-DnsClientCache
    }

    Write-LogInfo "Windows hosts file updated: $HostsPath"
}


# =====================================================================
# Result
# =====================================================================

function Show-NetworkSummary {
    Write-LogSuccess "IASI network is materialized."

    Write-Host ""
    Write-Host "Configuration: $NetworkConfigurationPath"
    Write-Host "Switch       : $SwitchName (Internal)"
    Write-Host "Adapter      : $InterfaceAlias"
    Write-Host "Gateway      : $GatewayAddress/$PrefixLength"
    Write-Host "Host         : $HostAddress/$PrefixLength"
    Write-Host "NAT          : $NatName -> $Subnet"
    Write-Host "DNS          : $($DnsServers -join ', ')"
    Write-Host "Hosts        : $HostsBeginMarker ... $HostsEndMarker"
}


# =====================================================================
# Main
# =====================================================================

try {
    Initialize-Log "net"

    Resolve-Configuration
    Test-Environment
    Test-Configuration

    Resolve-VirtualSwitch
    Resolve-VirtualAdapter | Out-Null
    Resolve-HostAddresses
    Resolve-Nat
    Resolve-HostsFile

    Show-NetworkSummary
}
catch {
    Write-LogError $_.Exception.Message

    if ($script:LogFile) {
        Write-LogInfo "See log: $script:LogFile"
    }

    exit 1
}
