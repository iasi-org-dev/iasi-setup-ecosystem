function Initialize-Log {
    param([string]$CommandName)

    $LogDirectory = Join-Path (Get-Location).Path "logs"
    if (-not (Test-Path $LogDirectory -PathType Container)) { New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null }

    $Timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $script:LogFile = Join-Path $LogDirectory "iasi-$CommandName-$Timestamp.log"

    New-Item -ItemType File -Path $script:LogFile -Force | Out-Null
}

function Write-CommandLog {
    param(
        [string]$Directory,
        [string]$Command,
        [string[]]$Arguments
    )

    if (-not $script:LogFile) { return }

    $FormattedArguments = @(
        foreach ($Argument in $Arguments) {
            if ($Argument -match '[\s"]') { '"' + ($Argument -replace '"', '\"') + '"' }
            else { $Argument }
        }
    )

    $CommandLine = $Command
    if ($FormattedArguments.Count -gt 0) { $CommandLine += " " + ($FormattedArguments -join " ") }

    $Time = Get-Date -Format "HH:mm:ss"
    Add-Content -LiteralPath $script:LogFile -Value "$Time - Command [$Directory]: $CommandLine" -Encoding UTF8
}

function Write-RawLog {
    param([object]$Data)

    if (-not $script:LogFile -or $null -eq $Data) { return }

    $Text = ($Data | Out-String).TrimEnd()
    if ($Text) { Add-Content -LiteralPath $script:LogFile -Value $Text -Encoding UTF8 }
}

function Invoke-LoggedCommand {
    param(
        [string]$Directory,
        [string]$Command,
        [string[]]$Arguments
    )

    Write-CommandLog -Directory $Directory -Command $Command -Arguments $Arguments

    Push-Location $Directory
    try {
        # In Windows PowerShell 5.1, native stderr redirected with 2>&1 can
        # become a NativeCommandError. With Stop inherited from the caller it
        # would throw even when the native process exits successfully.
        # Native success/failure must be decided by its process exit code.
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = $null
        $Output = & $Command @Arguments 2>&1
        $CommandSucceeded = $?
        $RC = $global:LASTEXITCODE
        Write-RawLog $Output

        if ($null -eq $RC) {
            # Fallback for a PowerShell command rather than a native executable.
            if ($CommandSucceeded) { return 0 }
            return 1
        }
        return [int]$RC
    }
    catch {
        Write-RawLog $_
        return 1
    }
    finally {
        Pop-Location
    }
}
