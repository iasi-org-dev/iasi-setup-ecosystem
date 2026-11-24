# VM identity: global defaults, per-machine field overrides. WSL excluded.
function Resolve-IasiIdentity {
    param([Parameter(Mandatory)][string]$RepositoryRoot,
          [Parameter(Mandatory)][string]$VmConfigFile)
    $globalFile = Join-Path $RepositoryRoot 'config\setup.toml'
    $global = Read-IasiToml -Path $globalFile
    if (-not $global.Contains('identity')) { throw "Missing [identity] in $globalFile" }
    $value = @{ user = [string]$global['identity']['user']; password = [string]$global['identity']['password'] }
    $local = Read-IasiToml -Path $VmConfigFile
    if ($local.Contains('identity')) {
        foreach ($key in @('user','password')) {
            if ($local['identity'].Contains($key)) { $value[$key] = [string]$local['identity'][$key] }
        }
    }
    if ($value.user -notmatch '^[a-zA-Z][a-zA-Z0-9_.-]{0,19}$') { throw 'Invalid identity.user' }
    if ([string]::IsNullOrEmpty($value.password)) { throw 'identity.password is required' }
    return $value
}
