$ErrorActionPreference = "Stop"

Write-Host "IASI Ecosystem Setup"
Write-Host "===================="
Write-Host ""
Write-Host "This repository contains the installation guide, binaries, scripts and configuration required to assemble the IASI ecosystem."
Write-Host ""
Write-Host "Current stage: installation procedure validation."
Write-Host "Follow the guide in: guide/"
Write-Host ""

$Bootstrap = Join-Path $PSScriptRoot "bin\ps\setup.ps1"
if (Test-Path $Bootstrap) {
    & $Bootstrap
}
