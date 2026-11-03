#requires -RunAsAdministrator
# IASI WSL bootstrap: verify first, repair minimally, never unregister an existing distro.
# A reboot is always manual; rerun the same setup.ps1 command afterwards.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common\toml.ps1')
if ($args.Count -ne 2 -or $args[0] -ne '--config') { throw 'Usage: wsl.ps1 --config <wsl.toml>' }
$configFile = (Resolve-Path -LiteralPath ([string]$args[1]) -ErrorAction Stop).ProviderPath
$data = Read-IasiToml -Path $configFile
if (-not $data.Contains('wsl')) { throw "Missing [wsl] in $configFile" }
$c = $data['wsl']
$enabled = $c.Contains('enabled') -and [bool]$c['enabled']

function Stop-IasiForReboot {
    Write-Warning 'IASI REBOOT_REQUIRED: reinicia Windows manualmente y vuelve a ejecutar EL MISMO comando setup.ps1 (sin -f).'
    exit 194
}
function Test-IasiDefaultDistro {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return $false }
    & wsl.exe --exec /bin/sh -c 'true' 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}
function Test-IasiXorriso {
    & wsl.exe --exec /bin/sh -c 'command -v xorriso >/dev/null 2>&1' 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}
function Install-IasiXorriso {
    Write-Host 'IASI: falta xorriso; instalando SOLO xorriso en la distro predeterminada.' -ForegroundColor Yellow
    & wsl.exe -u root --exec /bin/sh -c 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xorriso'
    if ($LASTEXITCODE -ne 0) { throw 'QA FAIL: no se ha podido instalar xorriso.' }
    if (-not (Test-IasiXorriso)) { throw 'QA FAIL: xorriso no esta disponible tras instalarlo.' }
}
function Get-IasiWslNames {
    $lines = @(& wsl.exe --list --quiet 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'QA FAIL: no se pueden enumerar las distribuciones de WSL.' }
    return @($lines | ForEach-Object { ([string]$_ -replace "`0", '').Trim() } | Where-Object { $_ })
}

# Existing functional DEFAULT distribution always wins. Do not import, rename or change it.
if (Test-IasiDefaultDistro) {
    if (-not (Test-IasiXorriso)) { Install-IasiXorriso }
    Write-Host 'IASI WSL QA PASS: distro predeterminada funcional con xorriso; distro conservada.' -ForegroundColor Green
    return
}
if (-not $enabled) { throw 'QA FAIL: no hay WSL predeterminado funcional y [wsl].enabled=false.' }

$source = [string]$c['distribution']
$instance = [string]$c['name']
$basePath = [string]$c['path']
if (-not $source -or -not $instance -or -not $basePath) { throw 'Requiere [wsl]: distribution, name, path.' }
if ($source -eq $instance) { throw 'La distribucion origen y la instancia importada deben llamarse diferente.' }
if (-not [IO.Path]::IsPathRooted($basePath)) { throw 'WSL path debe ser absoluta.' }
if ($c.Contains('default') -and -not [bool]$c['default']) {
    throw 'No hay distro predeterminada: configure [wsl].default=true para autorizar seleccionar la nueva instancia.'
}

# Enable prerequisites only if missing. Never restart the host automatically.
$needsReboot = $false
foreach ($feature in @('Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform')) {
    $state = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction Stop
    if ($state.State -eq 'EnablePending') { $needsReboot = $true; continue }
    if ($state.State -ne 'Enabled') {
        $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction Stop
        if ($result.RestartNeeded -or $result.State -eq 'EnablePending') { $needsReboot = $true }
    }
}
if ($needsReboot) { Stop-IasiForReboot }
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { throw 'QA FAIL: wsl.exe no existe pese a habilitar las caracteristicas.' }

$names = @(Get-IasiWslNames)
if ($names -notcontains $instance) {
    if ($names -notcontains $source) {
        Write-Host "IASI: descargando e instalando $source (sin iniciarla)."
        & wsl.exe --install --distribution $source --no-launch
        if ($LASTEXITCODE -ne 0) {
            throw "No se pudo instalar $source. Si Windows solicita reinicio, reinicia manualmente y repite setup.ps1."
        }
        $names = @(Get-IasiWslNames)
        if ($names -notcontains $source) { Stop-IasiForReboot }
    }
    & wsl.exe -d $source -u root --exec /bin/sh -c 'true'
    if ($LASTEXITCODE -ne 0) { Stop-IasiForReboot }

    $target = Join-Path $basePath $instance
    if (Test-Path -LiteralPath $target) { throw "QA FAIL: el destino $target ya existe. No se sobrescribe." }
    New-Item -ItemType Directory -Path $basePath -Force -ErrorAction Stop | Out-Null
    $archive = Join-Path $env:TEMP ('iasi-wsl-' + [guid]::NewGuid().ToString('N') + '.tar')
    try {
        Write-Host "IASI: exportando $source a un archivo temporal..."
        & wsl.exe --export $source $archive
        if ($LASTEXITCODE -ne 0) { throw 'QA FAIL: export de WSL.' }
        Write-Host "IASI: importando $instance en $target..."
        & wsl.exe --import $instance $target $archive --version 2
        if ($LASTEXITCODE -ne 0) { throw 'QA FAIL: import de WSL; inspecciona el destino antes de reintentar.' }
    }
    finally { if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force } }

    # Only configure the account on a NEW IASI instance.
    $winUser = [Environment]::UserName.ToLowerInvariant()
    $linuxUser = if ($c.Contains('user') -and [string]$c['user'] -ne 'auto') { [string]$c['user'] } else { $winUser }
    if ($linuxUser -cnotmatch '^[a-z_][a-z0-9_-]*$') { throw "Nombre de usuario WSL invalido: $linuxUser" }
    & wsl.exe -d $instance -u root --exec id -u $linuxUser 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        & wsl.exe -d $instance -u root --exec useradd -m -s /bin/bash $linuxUser
        if ($LASTEXITCODE -ne 0) { throw 'QA FAIL: creacion del usuario WSL.' }
    }
    $userConfig = "[user]`ndefault=$linuxUser`n"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($userConfig))
    & wsl.exe -d $instance -u root --exec /bin/sh -c "printf '%s' '$encoded' | base64 -d > /etc/wsl.conf"
    if ($LASTEXITCODE -ne 0) { throw 'QA FAIL: no se pudo escribir /etc/wsl.conf.' }
}

# Existing named instance is never overwritten and never has its user modified.
if (@(Get-IasiWslNames) -notcontains $instance) { throw "QA FAIL: $instance no esta registrada." }
& wsl.exe --set-default $instance
if ($LASTEXITCODE -ne 0) { throw "QA FAIL: no se puede seleccionar $instance como predeterminada." }
if (-not (Test-IasiDefaultDistro)) { throw 'QA FAIL: la distro predeterminada no arranca.' }
if (-not (Test-IasiXorriso)) { Install-IasiXorriso }
Write-Host 'IASI WSL QA PASS: distro predeterminada funcional y xorriso disponible.' -ForegroundColor Green
