# IASI - WSL bootstrap. PowerShell 5.1+.
# Existing distributions are never reinstalled, moved or unregistered.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$config)

$ErrorActionPreference = 'Stop'

function Assert-Exit([string]$step) {
    if ($LASTEXITCODE -ne 0) { throw "QA FAIL: $step (exit $LASTEXITCODE)" }
}

function Get-Distros {
    $lines = @(& wsl.exe --list --quiet 2>&1)
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        # With no installed distributions, current WSL versions return -1
        # (sometimes exposed as 0xFFFFFFFF). This is a valid empty state.
        if ($exitCode -eq -1 -or $exitCode -eq 4294967295) {
            Write-Host 'IASI WSL: no distributions registered.'
            return @()
        }
        throw "QA FAIL: list WSL distributions (exit $exitCode): $($lines -join ' ')"
    }
    return @($lines | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ })
}

function Get-DefaultDistro {
    # The asterisk identifies the default distro in wsl -l -v, independent of UI language.
    $lines = @(& wsl.exe --list --verbose)
    Assert-Exit 'list WSL default distribution'
    foreach ($line in $lines) {
        $clean = ($line -replace "`0", '').Trim()
        if ($clean -match '^\*\s+(\S+)') { return $Matches[1] }
    }
    return $null
}

function Test-Xorriso([string]$distro) {
    & wsl.exe -d $distro -u root --exec /bin/sh -c 'command -v xorriso >/dev/null 2>&1'
    return ($LASTEXITCODE -eq 0)
}

if (-not (Test-Path -LiteralPath $config -PathType Leaf)) { throw "Missing WSL config: $config" }
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { throw 'WSL unavailable.' }

# Read the repository TOML through the existing common TOML parser.
$tomlScript = Join-Path $PSScriptRoot 'common\toml.ps1'
if (-not (Test-Path -LiteralPath $tomlScript)) { throw "Missing TOML parser: $tomlScript" }
. $tomlScript
$c = Read-IasiToml -Path (Resolve-Path -LiteralPath $config).ProviderPath

$winUser = [Environment]::UserName.ToLowerInvariant()
if ($winUser -notmatch '^[a-z_][a-z0-9_-]*$') { throw "Invalid Linux username derived from Windows: $winUser" }
$basePath = 'C:\Maquinas\WSL'
if ($c.Contains('path') -and -not [string]::IsNullOrWhiteSpace([string]$c['path'])) {
    $basePath = [string]$c['path']
}
$source = 'Ubuntu-24.04'
if ($c.Contains('distribution') -and -not [string]::IsNullOrWhiteSpace([string]$c['distribution'])) {
    $source = [string]$c['distribution']
}

$distros = @(Get-Distros)
$target = $null
if ($distros -contains $winUser) {
    $target = $winUser
    Write-Host "IASI WSL: reusing user distribution '$target'."
} elseif ($distros.Count -gt 0) {
    $default = Get-DefaultDistro
    if ($default -and ($distros -contains $default)) {
        $target = $default
        Write-Host "IASI WSL: reusing default distribution '$target'."
    }
}

if (-not $target) {
    $target = $winUser
    $destination = Join-Path $basePath $target
    if (Test-Path -LiteralPath $destination) { throw "QA FAIL: destination already exists: $destination" }
    if ($distros -contains $source) {
        throw "QA FAIL: '$source' already exists, cannot assume it is temporary. Resolve it manually."
    }
    if (-not (Test-Path -LiteralPath $basePath)) { New-Item -ItemType Directory -Path $basePath -Force | Out-Null }
    $archive = Join-Path $env:TEMP ('iasi-wsl-' + [guid]::NewGuid().ToString('N') + '.tar')
    $temporaryCreated = $false
    try {
        Write-Host "IASI WSL: installing temporary $source..."
        & wsl.exe --install --distribution $source --no-launch
        Assert-Exit 'WSL Ubuntu install'
        $temporaryCreated = $true
        Write-Host "IASI WSL: exporting $source..."
        & wsl.exe --export $source $archive
        Assert-Exit 'WSL export'
        Write-Host "IASI WSL: importing $target at $destination..."
        & wsl.exe --import $target $destination $archive --version 2
        Assert-Exit 'WSL import'
        & wsl.exe -d $target -u root --exec /bin/sh -c 'id -u >/dev/null'
        Assert-Exit 'imported distro verification'

        # Configure the user only for a freshly imported distro.
        & wsl.exe -d $target -u root --exec /bin/sh -c "id -u '$winUser' >/dev/null 2>&1 || useradd -m -s /bin/bash '$winUser'"
        Assert-Exit 'Linux account creation'
        $conf = "[user]`ndefault=$winUser`n"
        $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($conf))
        & wsl.exe -d $target -u root --exec /bin/sh -c "printf '%s' '$b64' | base64 -d > /etc/wsl.conf"
        Assert-Exit 'WSL default Linux user'
        & wsl.exe --terminate $target
        Assert-Exit 'WSL terminate after account setup'
        $actual = (& wsl.exe -d $target --exec /usr/bin/id -un | ForEach-Object { ($_ -replace "`0", "").Trim() }) -join ""
        Assert-Exit 'default account validation'
        if ($actual -ne $winUser) { throw "QA FAIL: expected Linux user '$winUser', got '$actual'" }

        # The Ubuntu source was created by this execution: safe to unregister now.
        & wsl.exe --unregister $source
        Assert-Exit 'temporary Ubuntu removal'
        $temporaryCreated = $false
    }
    finally {
        # Preserve the export when recovery may be necessary; never unregister target.
        if (-not $temporaryCreated -and (Test-Path -LiteralPath $archive)) {
            Remove-Item -LiteralPath $archive -Force
        } elseif (Test-Path -LiteralPath $archive) {
            Write-Warning "Recovery archive retained: $archive"
        }
    }
}

if (-not (Test-Xorriso $target)) {
    Write-Host "IASI WSL: xorriso missing in '$target', installing..."
    & wsl.exe -d $target -u root --exec /usr/bin/apt-get update
    Assert-Exit 'apt-get update'
    & wsl.exe -d $target -u root --exec /usr/bin/apt-get install -y xorriso
    Assert-Exit 'xorriso installation'
}
if (-not (Test-Xorriso $target)) { throw "QA FAIL: xorriso not available in '$target'" }
Write-Host "IASI QA PASS: WSL distribution '$target'; xorriso available." -ForegroundColor Green
