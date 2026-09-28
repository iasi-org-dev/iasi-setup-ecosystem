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
        $Output = & $Command @Arguments 2>&1
        $RC = $LASTEXITCODE
        Write-RawLog $Output
        return $RC
    }
    catch {
        Write-RawLog $_
        return 1
    }
    finally {
        Pop-Location
    }
}
