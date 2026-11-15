# Windows first-logon launcher. It stages the setup media locally and runs bootstrap as SYSTEM.
$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'IASI first-logon launcher requires an administrative token.'
}
$logDir = Join-Path $env:ProgramData 'IASI'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir 'launcher.log'
Start-Transcript -Path $log -Append | Out-Null
try {
    $sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    $destRoot = Join-Path $logDir 'setup'
    New-Item -ItemType Directory -Force -Path $destRoot | Out-Null
    foreach ($name in @('bootstrap.ps1','toml.ps1','action-directories.ps1','action-drives.ps1','action-git.ps1','action-organization.ps1','install-software.ps1','run-packages-on-logon.ps1')) {
        Copy-Item -LiteralPath (Join-Path $sourceRoot $name) -Destination (Join-Path $destRoot $name) -Force
    }
    # Replace the staged configuration atomically enough for our one-time laboratory provisioning.
    $stagedServices = Join-Path $destRoot 'services'
    if (Test-Path -LiteralPath $stagedServices) { Remove-Item -LiteralPath $stagedServices -Recurse -Force }
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'services') -Destination $stagedServices -Recurse -Force
    $bootstrap = Join-Path $destRoot 'bootstrap.ps1'
    $taskName = 'IASI-Windows-Bootstrap'
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $bootstrap + '"')
    $user = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    # The boot trigger is the recovery path if Windows restarts during installation.
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 2) -StartWhenAvailable -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $user -Settings $settings -Force | Out-Null
    # Software runs as the real logged-in Windows user, not LocalSystem.
    # Register BEFORE starting bootstrap so it survives the bootstrap reboot.
    $softwareTask = 'IASI-Windows-Packages'
    $userId = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $softwareAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + (Join-Path $destRoot 'run-packages-on-logon.ps1') + '"')
    $softwarePrincipal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
    $softwareTrigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
    $softwareSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 4) -StartWhenAvailable -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $softwareTask -Action $softwareAction -Trigger $softwareTrigger -Principal $softwarePrincipal -Settings $softwareSettings -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
    Write-Host "IASI bootstrap started as SYSTEM. See $logDir\bootstrap.log"
} catch {
    Write-Error "IASI launcher failed: $_"
    throw
} finally { Stop-Transcript | Out-Null }
