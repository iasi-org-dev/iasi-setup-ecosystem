<#
.SYNOPSIS
Creates the Hyper-V virtual machine for the IASI tools node.

.DESCRIPTION
Creates a Generation 2 Hyper-V virtual machine named "vm-iasi-tools".

This first version only creates and configures the virtual machine:
- VM definition
- memory
- processors
- virtual disk
- connection to the IASI virtual switch

It does not attach an ISO and does not install Ubuntu Server.

The configurable values are grouped in the Configuration section.

.REQUIREMENTS
- Windows with Hyper-V enabled
- PowerShell executed with Administrator privileges
- Hyper-V PowerShell module available
- Hyper-V virtual switch "iasi-net" already created

.OUTPUTS
Hyper-V virtual machine:
    vm-iasi-tools

.NOTES
IASI Infrastructure
Node: iasi-tools
VM:   vm-iasi-tools
#>


# =====================================================================
# Configuration
# =====================================================================

$VMName = "vm-iasi-tools"

$Generation = 2
$MemoryStartupBytes = 8GB
$ProcessorCount = 4
$DiskSizeBytes = 80GB

$SwitchName = "iasi-net"


# =====================================================================
# Validation
# =====================================================================

if (-not (Get-Module -ListAvailable -Name Hyper-V)) {
    throw "Hyper-V PowerShell module is not available."
}

if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
    throw "The virtual machine '$VMName' already exists."
}

if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
    throw "The Hyper-V virtual switch '$SwitchName' does not exist."
}


# =====================================================================
# Paths
# =====================================================================

$VMHost = Get-VMHost

$VMPath = $VMHost.VirtualMachinePath
$VHDPath = Join-Path $VMHost.VirtualHardDiskPath "$VMName.vhdx"


# =====================================================================
# Create VM
# =====================================================================

Write-Host "Creating virtual machine '$VMName'..."

New-VM `
    -Name $VMName `
    -Generation $Generation `
    -MemoryStartupBytes $MemoryStartupBytes `
    -NewVHDPath $VHDPath `
    -NewVHDSizeBytes $DiskSizeBytes `
    -Path $VMPath `
    -SwitchName $SwitchName | Out-Null

Set-VMProcessor `
    -VMName $VMName `
    -Count $ProcessorCount

Set-VMMemory `
    -VMName $VMName `
    -DynamicMemoryEnabled $false

Set-VM `
    -Name $VMName `
    -AutomaticCheckpointsEnabled $false

Write-Host "Virtual machine '$VMName' created successfully."
Write-Host "VHDX: $VHDPath"
Write-Host "Switch: $SwitchName"
