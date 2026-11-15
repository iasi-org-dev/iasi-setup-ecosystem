param([hashtable]$Task)
$ErrorActionPreference = 'Stop'
$prj = [string]$Task['root']
$dev = Join-Path $prj 'iasi-dev'
foreach ($dir in @($prj,$dev,([string]$Task['sdk']))) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Write-Host "Directory: $dir"
}

# Lab directories are writable by the local Users group, including the interactive account.
# S-1-5-32-545 is the well-known SID for BUILTIN\Users, independent of locale.
foreach ($dir in @($prj,([string]$Task['sdk']))) {
    & icacls.exe $dir /grant:r '*S-1-5-32-545:(OI)(CI)M' /T /C | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to grant Users access to $dir" }
}
