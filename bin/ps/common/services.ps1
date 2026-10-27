<#
.SYNOPSIS
Builds Subiquity/NoCloud install and first-boot instructions from services.toml.

.DESCRIPTION
The optional services/services.toml has ordered [[install]] and [[startup]]
operations. Each operation is copy (source, target) or run (command).
Resources are kept beneath services/ on the CIDATA ISO; no agent is installed.
#>

function ConvertTo-IasiShellLiteral {
    param([Parameter(Mandatory)][string]$Value)
    $Quote = [string][char]34
    $Escaped = $Value.Replace("'", "'" + $Quote + "'" + $Quote + "'")
    return "'" + $Escaped + "'"
}

function Write-IasiUtf8File {
    param([string]$Path, [string[]]$Lines)
    $Utf8 = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, ($Lines -join "`n") + "`n", $Utf8)
}

function Read-IasiServices {
    param([string]$ServicesPath)
    $Path = Join-Path $ServicesPath 'services.toml'
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $Manifest = Read-IasiToml -Path $Path
    foreach ($Key in $Manifest.Keys) {
        if ($Key -notin @('install', 'startup')) { throw "Unexpected services.toml section '$Key'." }
    }
    foreach ($Phase in @('install', 'startup')) {
        foreach ($Step in @($Manifest[$Phase])) {
            if ($null -eq $Step) { continue }
            if ($Step.action -notin @('copy', 'run')) { throw "Invalid $Phase action '$($Step.action)'." }
            $Expected = if ($Step.action -eq 'copy') { @('action', 'source', 'target') } else { @('action', 'command') }
            $Allowed = if ($Step.action -eq 'run' -and $Phase -eq 'install') { $Expected + @('context') } else { $Expected }
            foreach ($Key in $Step.Keys) {
                if ($Key -notin $Allowed) { throw "Unexpected '$Key' in $Phase $($Step.action)." }
            }
            foreach ($Key in $Expected) {
                if (-not ($Step[$Key] -is [string]) -or [string]::IsNullOrWhiteSpace($Step[$Key])) {
                    throw "Missing or invalid '$Key' in $Phase $($Step.action)."
                }
            }
            if ($Step.action -eq 'copy') {
                $Source = $Step.source.Replace('\', '/')
                if ($Source.StartsWith('/') -or $Source.Split('/') -contains '..' -or $Source.Split('/') -contains '.' -or $Source -match '^[A-Za-z]:') {
                    throw "Unsafe services source '$Source'."
                }
                $SourcePath = Join-Path $ServicesPath ($Source -replace '/', [IO.Path]::DirectorySeparatorChar)
                if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) { throw "Missing service resource '$Source'." }
                if (-not $Step.target.StartsWith('/') -or $Step.target -match '[\r\n]' -or $Step.target.Split('/') -contains '..') {
                    throw "Invalid Linux target '$($Step.target)'."
                }
            }
            elseif ($Step.command -match '[\r\n]') { throw 'Multiline run commands are not supported.' }
            if ($Step.action -eq 'run' -and $Phase -eq 'install' -and $Step.Contains('context') -and $Step.context -ne 'installer') {
                throw "Invalid install run context '$($Step.context)'; expected 'installer'."
            }
        }
    }
    return $Manifest
}

function ConvertTo-IasiServiceCommands {
    param($Steps, [string]$Phase)
    $Lines = @('#!/bin/sh', 'set -eu')
    foreach ($Step in @($Steps)) {
        if ($null -eq $Step) { continue }
        if ($Step.action -eq 'run') {
            if ($Phase -eq 'install' -and $Step.context -ne 'installer') {
                $Lines += 'curtin in-target --target=/target -- sh -c ' + (ConvertTo-IasiShellLiteral $Step.command)
            }
            else { $Lines += 'sh -c ' + (ConvertTo-IasiShellLiteral $Step.command) }
            continue
        }
        $Source = '/mnt/iasi-seed/services/' + $Step.source.Replace('\', '/')
        $Target = if ($Phase -eq 'install') { '/target' + $Step.target } else { $Step.target }
        if ($Phase -eq 'startup') {
            # The seed CD-ROM need not be present at first boot; install all resources in late-commands.
            throw 'COPY is only supported in install. Copy files before first boot.'
        }
        $Lines += 'mkdir -p -- "$(dirname -- ' + (ConvertTo-IasiShellLiteral $Target) + ')"'
        $Lines += 'cp -- ' + (ConvertTo-IasiShellLiteral $Source) + ' ' + (ConvertTo-IasiShellLiteral $Target)
    }
    return $Lines
}

function New-IasiServiceScripts {
    param([string]$StagePath, $Manifest)
    $Directory = Join-Path $StagePath 'iasi'
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    $Install = @(ConvertTo-IasiServiceCommands -Steps $Manifest['install'] -Phase 'install')
    $Startup = @(ConvertTo-IasiServiceCommands -Steps $Manifest['startup'] -Phase 'startup')
    if ($Manifest.Contains('startup') -and $Manifest['startup'].Count -gt 0) {
        $Install += 'mkdir -p /target/usr/local/sbin'
        $Install += 'cp /mnt/iasi-seed/iasi/startup.sh /target/usr/local/sbin/iasi-startup.sh'
        $Install += 'chmod 755 /target/usr/local/sbin/iasi-startup.sh'
    }
    Write-IasiUtf8File -Path (Join-Path $Directory 'install.sh') -Lines $Install
    Write-IasiUtf8File -Path (Join-Path $Directory 'startup.sh') -Lines $Startup
}

function Add-IasiAutoinstallHooks {
    param([string]$UserDataPath, [bool]$HasStartup)
    $Text = Get-Content -LiteralPath $UserDataPath -Raw -Encoding UTF8
    if ($Text -match '(?m)^  (late-commands|user-data):\s*$') {
        throw 'user-data already declares late-commands or nested user-data; refusing to overwrite.'
    }
    $Lines = @(
        '  late-commands:',
        "    - 'mkdir -p /mnt/iasi-seed && mount -L CIDATA /mnt/iasi-seed && sh /mnt/iasi-seed/iasi/install.sh'"
    )
    if ($HasStartup) {
        $Lines += @(
            '  user-data:',
            '    runcmd:',
            '      - [ sh, /usr/local/sbin/iasi-startup.sh ]'
        )
    }
    $Utf8 = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText($UserDataPath, $Text.TrimEnd("`r", "`n") + "`n`n" + ($Lines -join "`n") + "`n", $Utf8)
}

function Set-AutoinstallServices {
    param([string]$StagePath, [string]$UserDataPath, [hashtable]$ServicePorts)
    $ServicesPath = Join-Path $StagePath 'services'
    if (-not (Test-Path -LiteralPath (Join-Path $ServicesPath "services.toml"))) { return }
    if ($ServicePorts -and $ServicePorts.Count -gt 0) {
        $Lines = @()
        foreach ($Key in @($ServicePorts.Keys | Sort-Object)) {
            if ($Key -cnotmatch '^[A-Z][A-Z0-9_]*$') { throw "Invalid service port variable '$Key'." }
            $Value = [string]$ServicePorts[$Key]
            if ($Value -notmatch '^[0-9]+$' -or [int]$Value -lt 1 -or [int]$Value -gt 65535) {
                throw "Invalid port for '$Key': $Value."
            }
            $Lines += "$Key=$Value"
            Write-LogInfo "Service port: $Key=$Value"
        }
        Write-IasiUtf8File -Path (Join-Path $ServicesPath 'iasi-services.env') -Lines $Lines
    }
    $Manifest = Read-IasiServices -ServicesPath $ServicesPath
    Write-LogInfo 'Adding services.toml install/startup provisioning...'
    New-IasiServiceScripts -StagePath $StagePath -Manifest $Manifest
    Add-IasiAutoinstallHooks -UserDataPath $UserDataPath -HasStartup ($Manifest.Contains('startup') -and $Manifest['startup'].Count -gt 0)
}
