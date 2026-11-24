# IASI Phase 2: declared VS Code extensions, optional R baseline and public GitHub repos.
# Execute in the actual logged-in user session. No WSL, no VM recreation.
param([Parameter(Mandatory)][string]$Manifest, [string]$Sdk = 'C:\SDK')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\common\toml.ps1')
$manifestPath = (Resolve-Path -LiteralPath $Manifest -ErrorAction Stop).ProviderPath
$cfg = Read-IasiToml -Path $manifestPath

function Find-IasiExecutable {
    param([string]$Name,[string[]]$SearchRoots)
    $candidate = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
    if ($candidate) { return $candidate }
    foreach ($root in $SearchRoots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        $candidate = Get-ChildItem -LiteralPath $root -Filter $Name -File -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        if ($candidate) { return $candidate }
    }
    return $null
}

# Full catalog is retained in `extensions`. Only `enabled` entries are installed.
$v = $cfg['vscode']
if ($v) {
    $catalog = @($v['extensions'])
    $enabled = @($v['enabled'])
    foreach ($id in $catalog + $enabled) {
        if ([string]$id -cnotmatch '^[A-Za-z0-9_.-]+$') { throw "Invalid VS Code extension ID: $id" }
    }
    foreach ($id in $enabled) {
        if ($id -notin $catalog) { throw "VS Code enabled extension is not in catalog: $id" }
    }
    if ($enabled.Count -gt 0) {
        $code = Find-IasiExecutable -Name 'code.cmd' -SearchRoots @(
            (Join-Path $Sdk 'Microsoft.VisualStudioCode'),
            (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code'),
            (Join-Path $env:ProgramFiles 'Microsoft VS Code'),
            (Join-Path $Sdk 'VSCode')
        )
        if (-not $code) { throw 'VS Code code.cmd not found. Verify Phase 1 installation.' }
        $installed = @(& $code --list-extensions)
        if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate VS Code extensions.' }
        foreach ($extension in $enabled) {
            if ($installed -contains $extension) {
                Write-Host "IASI VS Code already installed: $extension"
            }
            else {
                Write-Host "IASI VS Code installing: $extension"
                & $code --install-extension ([string]$extension)
                if ($LASTEXITCODE -ne 0) { throw "VS Code installation failed: $extension" }
            }
        }
        $actual = @(& $code --list-extensions)
        if ($LASTEXITCODE -ne 0) { throw 'Cannot verify VS Code extensions.' }
        foreach ($extension in $enabled) {
            if ($actual -notcontains $extension) { throw "IASI QA FAIL: VS Code extension missing: $extension" }
            Write-Host "IASI QA PASS: VS Code extension $extension"
        }
    }
    else { Write-Host 'IASI VS Code: catalog declared, no extensions enabled.' }
}

$r = $cfg['r']
if ($r) {
    $packages = @($r['packages'])
    foreach ($pkg in $packages) {
        if ([string]$pkg -cnotmatch '^[A-Za-z][A-Za-z0-9.]*$') { throw "Invalid R package: $pkg" }
    }
    if ($r.Contains('enabled') -and $r['enabled'] -isnot [bool]) { throw 'r.enabled must be boolean' }
    $rEnabled = $r.Contains('enabled') -and $r['enabled'] -eq $true
    if ($rEnabled) {
        $rscript = Find-IasiExecutable -Name 'Rscript.exe' -SearchRoots @((Join-Path $Sdk 'RProject.R'), 'C:\Program Files\R', (Join-Path $Sdk 'R'))
        if (-not $rscript) { throw 'Rscript.exe not found. Verify Phase 1 installation.' }
        if ([string]$r['repository'] -ne 'https://cloud.r-project.org') { throw 'Unapproved R repository.' }
        $mode = [string]$r['mode']
        if ($mode -notin @('bootstrap', 'restore')) { throw "Invalid R mode: $mode" }
        $lockname = [string]$r['lockfile']
        if ($lockname -cnotmatch '^[A-Za-z0-9_.-]+$') { throw 'Unsafe R lockfile name.' }
        $target = Join-Path (Split-Path -Parent $manifestPath) $lockname
        $script = Join-Path $PSScriptRoot 'postinstall-r.R'
        if (-not (Test-Path -LiteralPath $script -PathType Leaf)) { throw "R adapter missing: $script" }
        & $rscript --vanilla $script $mode $target ([string]$r['repository']) @packages
        if ($LASTEXITCODE -ne 0) { throw "R postinstall FAIL: exit $LASTEXITCODE" }
    }
    else { Write-Host "IASI R: $($packages.Count) packages declared; installation deferred (r.enabled=false)." }
}

$github = $cfg['github']
if ($github) {
    $organization = [string]$github['organization']
    $target = [string]$github['target']
    $policy = [string]$github['update']
    if ($organization -cnotmatch '^[A-Za-z0-9-]+$') { throw 'Invalid GitHub organization.' }
    if (-not [IO.Path]::IsPathRooted($target)) { throw 'GitHub target must be absolute.' }
    if ($policy -ne 'ff-only') { throw 'Unsupported GitHub update policy.' }
    if ($github['public_only'] -ne $true) { throw 'Only public repositories are supported by this adapter.' }
    $task = @{ organization = $organization; target = $target; update = $policy; public_only = $true; skip_dirty = $true }
    & (Join-Path $PSScriptRoot 'action-organization.ps1') -Task $task
    if (-not $?) { throw 'GitHub synchronization failed.' }
}
Write-Host 'IASI post-install steps completed; review GitHub UNKNOWN warnings if any.'
