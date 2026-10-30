# Generic IASI Windows bootstrap: executes the VM-specific services.toml.
$ErrorActionPreference = 'Stop'
if ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne 'S-1-5-18') {
    throw 'IASI bootstrap must be run by the LocalSystem scheduled task.'
}

$logDir = Join-Path $env:ProgramData 'IASI'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$log = Join-Path $logDir 'bootstrap.log'
$marker = Join-Path $logDir 'bootstrap.completed'
# Idempotency marker is tied to the exact installation instructions, not just existence.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$inputs = @((Join-Path $here 'bootstrap.ps1'), (Join-Path $here 'services\services.toml'))
$inputs += @(Get-ChildItem -LiteralPath $here -Filter 'action-*.ps1' -File | Select-Object -ExpandProperty FullName)
$inputs += @(Get-ChildItem -LiteralPath (Join-Path $here 'services') -File -Recurse | Select-Object -ExpandProperty FullName)
$inputs = @($inputs | Sort-Object -Unique)
$sha = [System.Security.Cryptography.SHA256]::Create()
try {
    $lines = foreach ($inputFile in $inputs) {
        $bytes = [System.IO.File]::ReadAllBytes($inputFile)
        $digest = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant()
        "$(($inputFile.Substring($here.Length)).ToLowerInvariant())=$digest"
    }
    $fingerprintBytes = [System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    $fingerprint = [BitConverter]::ToString($sha.ComputeHash($fingerprintBytes)).Replace('-','').ToLowerInvariant()
} finally { $sha.Dispose() }
if ((Test-Path -LiteralPath $marker) -and ((Get-Content -LiteralPath $marker -Raw).Trim() -eq $fingerprint)) {
    Write-Host 'IASI: current bootstrap configuration already applied.'
    Unregister-ScheduledTask -TaskName 'IASI-Windows-Bootstrap' -Confirm:$false -ErrorAction Stop
    exit 0
}
Start-Transcript -Path $log -Append | Out-Null
try {
    . (Join-Path $here 'toml.ps1')
    $manifest = Read-IasiToml -Path (Join-Path $here 'services\services.toml')
    if (-not $manifest.Contains('install')) { throw 'Missing [[install]] tasks in services.toml.' }
    foreach ($task in $manifest['install']) {
        $action = [string]$task['action']
        switch ($action) {
            'directories' { & (Join-Path $here 'action-directories.ps1') -Task $task; if (-not $?) { throw 'directories failed' } }
            'drives' { & (Join-Path $here 'action-drives.ps1') -Task $task; if (-not $?) { throw 'drives failed' } }
            'git-install' { & (Join-Path $here 'action-git.ps1') -Task $task; if (-not $?) { throw 'git-install failed' } }
            'script' {
                $name = [string]$task['source']
                if ($name -notmatch '^[A-Za-z0-9_-]+$') { throw "Unsafe script name: $name" }
                $path = Join-Path $here ("services\" + $name + '.ps1')
                if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing Windows script: $path" }
                Write-Host "IASI install script: $name (.ps1)"
                & $path
                if (-not $?) { throw "Script failed: $name" }
            }
            'python' {
                $name = [string]$task['source']
                if ($name -notmatch '^[A-Za-z0-9_-]+$') { throw "Unsafe Python script name: $name" }
                $path = Join-Path $here ("services\" + $name + '.py')
                if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing Python script: $path" }
                $python = Get-Command python.exe -ErrorAction SilentlyContinue
                if (-not $python) { throw 'Python interpreter unavailable' }
                & $python.Source $path
                if ($LASTEXITCODE -ne 0) { throw "Python failed: $name ($LASTEXITCODE)" }
            }
            'run' {
                $command = [string]$task['command']
                if ([string]::IsNullOrWhiteSpace($command) -or $command -match '[\r\n]') { throw 'Empty or multiline service command.' }
                if ($command -match '^[^\\/]+\.ps1$') {
                    $scriptPath = Join-Path $here "services\$command"
                    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw "Missing script: $scriptPath" }
                    Write-Host "IASI install script: $command"
                    & $scriptPath
                    if (-not $?) { throw "Task failed: $command" }
                }
                else {
                    Write-Host "IASI install command: $command"
                    & ([scriptblock]::Create($command))
                    if (-not $?) { throw "Command failed: $command" }
                }
            }
            'packages' {
                $catalogue = Join-Path $here 'services\packages.toml'
                if (-not (Test-Path -LiteralPath $catalogue -PathType Leaf)) { throw 'Missing packages.toml for packages action.' }
                Write-Host 'IASI packages: installing declared Windows software.'
                & (Join-Path $here 'install-packages.ps1') -Manifest $catalogue
                if (-not $?) { throw 'Windows package install failed.' }
            }
            'git' {
                $url = [string]$task['repository']
                $target = [string]$task['target']
                $update = [string]$task['update']
                if ($update -ne 'ff-only') { throw "Unsupported git update policy: $update" }
                if ($url -notmatch '^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\.git$') { throw "Unsupported Git repository URL: $url" }
                $target = [Environment]::ExpandEnvironmentVariables($target)
                if (-not [IO.Path]::IsPathRooted($target)) { throw "Git target must be absolute: $target" }
                $gitExe = Join-Path $env:ProgramFiles 'Git\cmd\git.exe'
                if (-not (Test-Path -LiteralPath $gitExe -PathType Leaf)) { throw "Git is not installed: $gitExe" }
                $env:GIT_TERMINAL_PROMPT = '0'
                $env:GCM_INTERACTIVE = 'Never'
                if (-not (Test-Path -LiteralPath $target)) {
                    Write-Host "IASI git clone: $url -> $target"
                    & $gitExe -c credential.interactive=never clone -- $url $target
                    if ($LASTEXITCODE -ne 0) { throw "Git clone failed: $url (exit $LASTEXITCODE)" }
                }
                elseif (Test-Path -LiteralPath (Join-Path $target '.git')) {
                    $origin = & $gitExe -C $target remote get-url origin
                    if ($LASTEXITCODE -ne 0 -or $origin.TrimEnd() -ne $url) { throw "Existing repository origin differs from expected URL: $target" }
                    $changes = & $gitExe -C $target status --porcelain
                    if ($LASTEXITCODE -ne 0) { throw "Could not inspect Git worktree: $target" }
                    if ($changes) { throw "Git worktree has local changes; refusing automatic update: $target" }
                    Write-Host "IASI git pull --ff-only: $target"
                    & $gitExe -C $target -c credential.interactive=never pull --ff-only
                    if ($LASTEXITCODE -ne 0) { throw "Git pull --ff-only failed: $target (exit $LASTEXITCODE)" }
                }
                else { throw "Git target exists but is not a repository: $target" }
            }
            'copy' {
                $source = [string]$task['source']
                $target = [string]$task['target']
                if ([string]::IsNullOrWhiteSpace($source) -or [string]::IsNullOrWhiteSpace($target)) { throw 'copy requires source and target.' }
                if ([IO.Path]::IsPathRooted($source) -or $source -match '(^|[\\/])\.\.([\\/]|$)') { throw "Unsafe services source: $source" }
                $sourceFile = Join-Path (Join-Path $here 'services') $source
                if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) { throw "Missing services source: $sourceFile" }
                $targetExpanded = [Environment]::ExpandEnvironmentVariables($target)
                if (-not [IO.Path]::IsPathRooted($targetExpanded)) { throw "copy target must be absolute: $target" }
                $parent = Split-Path -Parent $targetExpanded
                if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
                Copy-Item -LiteralPath $sourceFile -Destination $targetExpanded -Force -ErrorAction Stop
            }
            default { throw "Unsupported Windows action: $action" }
        }
    }
    # Completion is committed only after all actions succeed. The task is
    # temporary: it must not survive a successful installation.
    [System.IO.File]::WriteAllText($marker, $fingerprint)
    Write-Host 'IASI bootstrap completed. Removing one-time scheduled task.'
    Unregister-ScheduledTask -TaskName 'IASI-Windows-Bootstrap' -Confirm:$false -ErrorAction Stop
    Write-Host 'IASI setup completed. Restarting Windows to apply drive mappings.'
    & shutdown.exe /r /t 10
    if ($LASTEXITCODE -ne 0) { throw "Reboot failed: $LASTEXITCODE" }
}
catch {
    Write-Error "IASI bootstrap failed: $_"
    Write-Host "See log: $log"
    exit 1
}
finally { Stop-Transcript | Out-Null }
