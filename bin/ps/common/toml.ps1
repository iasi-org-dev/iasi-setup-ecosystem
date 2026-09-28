<#
.SYNOPSIS
Minimal TOML reader used by IASI PowerShell infrastructure scripts.

.DESCRIPTION
Parses the TOML subset currently used by IASI configuration files:
- tables
- strings
- integers
- booleans
- arrays of scalar values

It intentionally does not try to implement the complete TOML specification.
IASI configuration should remain within this supported subset unless this
reader is explicitly extended.
#>


function ConvertFrom-IasiTomlScalar {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $Value = $Value.Trim()

    if ($Value -match '^"(.*)"$') {
        return $Matches[1]
    }

    if ($Value -match "^'(.*)'$") {
        return $Matches[1]
    }

    if ($Value -match '^(true|false)$') {
        return [System.Convert]::ToBoolean($Value)
    }

    if ($Value -match '^[+-]?\d+$') {
        return [long]$Value
    }

    throw "Unsupported TOML value: $Value"
}


function ConvertFrom-IasiTomlArray {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $Inner = $Value.Trim()
    if (-not ($Inner.StartsWith("[") -and $Inner.EndsWith("]"))) {
        throw "Invalid TOML array: $Value"
    }

    $Inner = $Inner.Substring(1, $Inner.Length - 2).Trim()
    if (-not $Inner) {
        return @()
    }

    $Items = @()
    $Current = ""
    $Quote = $null

    for ($i = 0; $i -lt $Inner.Length; $i++) {
        $Character = $Inner[$i]

        if ($Quote) {
            $Current += $Character
            if ($Character -eq $Quote) {
                $Quote = $null
            }
            continue
        }

        if ($Character -eq '"' -or $Character -eq "'") {
            $Quote = $Character
            $Current += $Character
            continue
        }

        if ($Character -eq ",") {
            if ($Current.Trim()) {
                $Items += ConvertFrom-IasiTomlScalar $Current
            }
            $Current = ""
            continue
        }

        $Current += $Character
    }

    if ($Current.Trim()) {
        $Items += ConvertFrom-IasiTomlScalar $Current
    }

    return @($Items)
}


function Read-IasiToml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path -PathType Leaf)) {
        throw "TOML configuration file '$Path' does not exist."
    }

    $Result = [ordered]@{}
    $Section = $Result
    $PendingKey = $null
    $PendingValue = ""

    foreach ($RawLine in Get-Content -Path $Path -Encoding UTF8) {
        $Line = $RawLine.Trim()

        if (-not $Line -or $Line.StartsWith("#")) {
            continue
        }

        if ($PendingKey) {
            $PendingValue += " " + $Line
            if ($Line.Contains("]")) {
                $Section[$PendingKey] = ConvertFrom-IasiTomlArray $PendingValue
                $PendingKey = $null
                $PendingValue = ""
            }
            continue
        }

        if ($Line -match '^\[([A-Za-z0-9_.-]+)\]$') {
            $SectionName = $Matches[1]

            if (-not $Result.Contains($SectionName)) {
                $Result[$SectionName] = [ordered]@{}
            }

            $Section = $Result[$SectionName]
            continue
        }

        if ($Line -notmatch '^([A-Za-z0-9_.-]+)\s*=\s*(.+)$') {
            throw "Unable to parse TOML line: $RawLine"
        }

        $Key = $Matches[1]
        $Value = $Matches[2].Trim()

        if ($Value.StartsWith("[") -and -not $Value.Contains("]")) {
            $PendingKey = $Key
            $PendingValue = $Value
            continue
        }

        if ($Value.StartsWith("[")) {
            $Section[$Key] = ConvertFrom-IasiTomlArray $Value
        }
        else {
            $Section[$Key] = ConvertFrom-IasiTomlScalar $Value
        }
    }

    if ($PendingKey) {
        throw "Unterminated TOML array for key '$PendingKey'."
    }

    return $Result
}
