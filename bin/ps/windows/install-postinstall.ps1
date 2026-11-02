# Windows Phase 2: VS Code and reproducible R packages.
param([Parameter(Mandatory)][string]$Manifest,[string]$Sdk='C:\SDK')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\common\toml.ps1')
$manifestPath = (Resolve-Path -LiteralPath $Manifest).Path
$cfg = Read-IasiToml -Path $manifestPath
$code = Get-ChildItem -LiteralPath (Join-Path $Sdk 'VSCode') -Filter code.cmd -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $code) { $code = (Get-Command code.cmd -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source) }
if (-not $code) { throw 'VS Code code.cmd not found; Phase 2 cannot begin.' }
foreach ($extension in $cfg['vscode']['extensions']) {
    if ([string]$extension -notmatch '^[A-Za-z0-9_.-]+$') { throw "Invalid extension ID: $extension" }
    & $code --install-extension ([string]$extension)
    if ($LASTEXITCODE -ne 0) { throw "VS Code extension failed: $extension" }
}
$rscript = Get-ChildItem -LiteralPath (Join-Path $Sdk 'R') -Filter Rscript.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $rscript) {
    $rscript = Get-ChildItem -LiteralPath 'C:\Program Files\R' -Filter Rscript.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $rscript) { throw 'Rscript.exe not found; Phase 2 cannot begin.' }
$r = $cfg['r']
if ([string]$r['repository'] -ne 'https://cloud.r-project.org') { throw 'R repository must be explicitly approved.' }
$mode = [string]$r['mode']
if ($mode -notin @('bootstrap','restore')) { throw "Invalid R mode: $mode" }
$lockname = [string]$r['lockfile']
if ($lockname -notmatch '^[A-Za-z0-9_.-]+$') { throw 'Unsafe R lockfile filename.' }
$target = Join-Path (Split-Path -Parent $manifestPath) $lockname
$script = Join-Path $PSScriptRoot 'postinstall-r.R'
if (-not (Test-Path -LiteralPath $script)) { throw "Missing R adapter: $script" }
$packages = @($r['packages'])
foreach($pkg in $packages) { if ([string]$pkg -notmatch '^[A-Za-z][A-Za-z0-9.]*$') { throw "Invalid R package: $pkg" } }
& $rscript --vanilla $script $mode $target ([string]$r['repository']) @packages
if ($LASTEXITCODE -ne 0) { throw "R postinstall failed (exit $LASTEXITCODE)" }
Write-Host 'IASI phase 2 completed.'
