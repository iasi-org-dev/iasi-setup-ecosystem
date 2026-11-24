<#
.SYNOPSIS
Minimal TOML reader for IASI PowerShell infrastructure.
.DESCRIPTION
Supports tables, arrays of tables, strings, integers, booleans and scalar arrays.
#>

function ConvertFrom-IasiTomlScalar {
    param([Parameter(Mandatory)][string]$Value)
    $Value = $Value.Trim()
    if ($Value -match '^"(.*)"$') { return $Matches[1] }
    if ($Value -match "^'(.*)'$") { return $Matches[1] }
    if ($Value -match '^(true|false)$') { return [bool]::Parse($Value) }
    if ($Value -match '^[+-]?\d+$') { return [long]$Value }
    throw "Unsupported TOML value: $Value"
}

function ConvertFrom-IasiTomlArray {
    param([Parameter(Mandatory)][string]$Value)
    $Inner = $Value.Trim()
    if (-not ($Inner.StartsWith('[') -and $Inner.EndsWith(']'))) { throw "Invalid TOML array: $Value" }
    $Inner = $Inner.Substring(1, $Inner.Length - 2).Trim()
    if (-not $Inner) { return ,@() }
    $Items = @(); $Current = ''; $Quote = $null
    foreach ($Character in $Inner.ToCharArray()) {
        if ($Quote) {
            $Current += $Character
            if ($Character -eq $Quote) { $Quote = $null }
            continue
        }
        if ($Character -eq '"' -or $Character -eq "'") { $Quote = $Character; $Current += $Character; continue }
        if ($Character -eq ',') {
            if ($Current.Trim()) { $Items += ConvertFrom-IasiTomlScalar $Current }
            $Current = ''; continue
        }
        $Current += $Character
    }
    if ($Quote) { throw 'Unterminated quoted TOML array element.' }
    if ($Current.Trim()) { $Items += ConvertFrom-IasiTomlScalar $Current }
    return ,$Items
}

function Read-IasiToml {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "TOML configuration file '$Path' does not exist." }
    $Result = [ordered]@{}; $Section = $Result
    $PendingKey = $null; $PendingValue = ''
    foreach ($RawLine in Get-Content -LiteralPath $Path -Encoding UTF8) {
        # Strip inline comments only when outside TOML quoted strings.
        $quoted = $null; $escaped = $false; $clean = ''
        foreach ($ch in $RawLine.ToCharArray()) {
            if ($quoted) {
                $clean += $ch
                if ($quoted -eq '"' -and $ch -eq '\' -and -not $escaped) { $escaped = $true; continue }
                if ($ch -eq $quoted -and -not $escaped) { $quoted = $null }
                $escaped = $false
                continue
            }
            if ($ch -eq '"' -or $ch -eq "'") { $quoted = $ch }
            if ($ch -eq '#') { break }
            $clean += $ch
        }
        $Line = $clean.Trim()
        if (-not $Line -or $Line.StartsWith('#')) { continue }
        if ($PendingKey) {
            $PendingValue += ' ' + $Line
            if ($Line.Contains(']')) {
                $Section[$PendingKey] = ConvertFrom-IasiTomlArray $PendingValue
                $PendingKey = $null; $PendingValue = ''
            }
            continue
        }
        if ($Line -match '^\[\[([A-Za-z0-9_.-]+)\]\]$') {
            $Name = $Matches[1]
            if ($Result.Contains($Name) -and $Result[$Name] -isnot [System.Collections.ArrayList]) {
                throw "TOML section '$Name' is already defined as a regular table."
            }
            if (-not $Result.Contains($Name)) { $Result[$Name] = [System.Collections.ArrayList]::new() }
            $Section = [ordered]@{}
            [void]$Result[$Name].Add($Section)
            continue
        }
        if ($Line -match '^\[([A-Za-z0-9_.-]+)\]$') {
            $Name = $Matches[1]
            if ($Result.Contains($Name)) { throw "Duplicate TOML section '$Name'." }
            $Result[$Name] = [ordered]@{}
            $Section = $Result[$Name]
            continue
        }
        if ($Line -notmatch '^(?:"([^"]+)"|([A-Za-z0-9_.-]+))\s*=\s*(.+)$') { throw "Unable to parse TOML line: $RawLine" }
        $Key = if ($Matches[1]) { $Matches[1] } else { $Matches[2] }; $Value = $Matches[3].Trim()
        if ($Section.Contains($Key)) { throw "Duplicate TOML key '$Key'." }
        if ($Value.StartsWith('[') -and -not $Value.Contains(']')) {
            $PendingKey = $Key; $PendingValue = $Value; continue
        }
        if ($Value.StartsWith('[')) { $Section[$Key] = ConvertFrom-IasiTomlArray $Value }
        else { $Section[$Key] = ConvertFrom-IasiTomlScalar $Value }
    }
    if ($PendingKey) { throw "Unterminated TOML array for key '$PendingKey'." }
    return $Result
}
