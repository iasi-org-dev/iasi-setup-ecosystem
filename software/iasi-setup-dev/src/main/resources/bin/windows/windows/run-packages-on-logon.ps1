# Runs at the first subsequent user logon, elevated, AFTER SYSTEM bootstrap completes.
# A task trigger remains available after interrupted installs and is deleted on success.
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:ProgramData 'IASI'
$setup = Join-Path $root 'setup'
$serviceMarker = Join-Path $root 'bootstrap.completed'
$catalog = Join-Path $setup 'services\packages.toml'
$completion = Join-Path $root 'packages.completed'
$taskName = 'IASI-Windows-Packages'
New-Item -ItemType Directory -Path $root -Force | Out-Null
Start-Transcript -Path (Join-Path $root 'packages.log') -Append | Out-Null
try {
    # Do not install until services have completed. If still running, retry at next logon.
    if (-not (Test-Path -LiteralPath $serviceMarker)) { Write-Host 'IASI services not completed: software deferred.'; exit 0 }
    if (-not (Test-Path -LiteralPath $catalog)) { throw "Missing package catalogue: $catalog" }
    $fingerprint = (Get-FileHash -LiteralPath $catalog -Algorithm SHA256).Hash
    if ((Test-Path -LiteralPath $completion) -and (Get-Content $completion -Raw).Trim() -eq $fingerprint) {
        Write-Host 'IASI software catalogue already completed.'
    } else {
        & (Join-Path $setup 'install-software.ps1') -Manifest $catalog
        if (-not $?) { throw 'Software phase failed.' }
        [System.IO.File]::WriteAllText($completion, $fingerprint)
        Write-Host 'IASI packages phase completed.'
    }
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
    Write-Host 'IASI temporary software task removed.'
} catch {
    Write-Error "IASI software failed: $_"
    exit 1
} finally { Stop-Transcript | Out-Null }
