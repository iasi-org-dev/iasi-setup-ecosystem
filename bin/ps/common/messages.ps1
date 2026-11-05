<#
PSScriptAnalyzer exception: Write-Host is intentional in this file.
Write-LogMessage writes to the configured log file and uses Write-Host for the
interactive, color-coded console output. Do not replace these calls with
Write-Output because that would change the script output contract.
#>

function Write-LogMessage {
    param(
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type,
        [string]$Message
    )

    $Time = Get-Date -Format "HH:mm:ss"

    if ($script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value "$Time - $Message" -Encoding UTF8
    }

    Write-Host "$Time - " -NoNewline

    switch ($Type) {
        "Info"    { Write-Host $Message }
        "Success" { Write-Host $Message -ForegroundColor Green }
        "Warning" { Write-Host $Message -ForegroundColor Yellow }
        "Error"   { Write-Host $Message -ForegroundColor Red }
    }
}

function Write-LogInfo {
    param([string]$Message)
    Write-LogMessage -Type "Info" -Message $Message
}

function Write-LogSuccess {
    param([string]$Message)
    Write-LogMessage -Type "Success" -Message $Message
}

function Write-LogWarning {
    param([string]$Message)
    Write-LogMessage -Type "Warning" -Message $Message
}

function Write-LogError {
    param([string]$Message)
    Write-LogMessage -Type "Error" -Message $Message
}

