# Generic Phase 2 Windows configurator, for intended logged-on user only.
param([Parameter(Mandatory)][string]$Manifest,[string]$Sdk='C:\SDK')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\common\toml.ps1')
$cfg = Read-IasiToml -Path (Resolve-Path -LiteralPath $Manifest)
$code = Get-ChildItem -LiteralPath (Join-Path $Sdk 'VSCode') -Filter code.cmd -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $code) { throw 'VS Code executable not found in SDK; Phase 2 cannot begin.' }
foreach($extension in $cfg['vscode']['extensions']) {
    if ([string]$extension -notmatch '^[A-Za-z0-9_.-]+$') { throw "Invalid extension ID: $extension" }
    & $code --install-extension ([string]$extension)
    if($LASTEXITCODE -ne 0) { throw "VS Code extension failed: $extension" }
}
$rscript=Get-ChildItem -LiteralPath (Join-Path $Sdk 'R') -Filter Rscript.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $rscript) { throw 'Rscript.exe not found in SDK; Phase 2 cannot begin.' }
$repo=[string]$cfg['r']['repository']
if ($repo -ne 'https://cloud.r-project.org') { throw 'R repository must be explicitly approved.' }
foreach($pkg in $cfg['r']['packages']) {
    if ([string]$pkg -notmatch '^[A-Za-z][A-Za-z0-9.]*$') { throw "Invalid R package: $pkg" }
    & $rscript -e "if (!requireNamespace('$pkg', quietly=TRUE)) install.packages('$pkg', repos='$repo')"
    if($LASTEXITCODE -ne 0) { throw "R package failed: $pkg" }
}
Write-Host 'IASI phase 2 completed.'
