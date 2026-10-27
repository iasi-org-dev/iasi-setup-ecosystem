#requires -RunAsAdministrator
<#
.SYNOPSIS
    Exercises IASI GPU selection WITHOUT modifying Hyper-V.
.EXAMPLE
    .\iasi-gpu-selection-test.ps1
    .\iasi-gpu-selection-test.ps1 -ForcePrompt
    .\iasi-gpu-selection-test.ps1 -Selector 'NVIDIA GeForce RTX 5070 Ti Laptop GPU'
#>
[CmdletBinding()]
param(
    [string]$Selector = 'auto',
    [switch]$AllowIntegrated,
    [switch]$ForcePrompt
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common\gpu-selection.ps1"

$selected = Select-IasiGpu -Selector $Selector -AllowIntegrated:$AllowIntegrated -ForcePrompt:$ForcePrompt
Write-Host "`nTEST RESULT: Selected GPU-P path is $($selected.Name)" -ForegroundColor Green
Write-Host 'This test has not modified Hyper-V.'
