# Fase 1B: ejecutar en sesion del usuario Windows FINAL, NO elevada/SYSTEM.
# Importar como IASI; eliminar Ubuntu-24.04 original solo tras verificar IASI.
param([string]$Source = 'Ubuntu-24.04', [string]$Name = 'IASI', [string]$Destination = 'C:\Machines\IASI')
$ErrorActionPreference='Stop'
if ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -eq 'S-1-5-18') {throw 'WSL es por usuario; prohibido ejecutar como SYSTEM.'}
function Invoke-Wsl([string[]]$arguments){ & wsl.exe @arguments; if($LASTEXITCODE -ne 0){throw "WSL: error al ejecutar $($arguments -join ' ') ($LASTEXITCODE)"} }
function Distros { @(wsl.exe --list --quiet | ForEach-Object { ($_ -replace "`0",'').Trim() } | Where-Object {$_}) }
# Features need an elevated user session; a restart may be necessary.
foreach($feature in @('Microsoft-Windows-Subsystem-Linux','VirtualMachinePlatform')) {
    $state = Get-WindowsOptionalFeature -Online -FeatureName $feature
    if($state.State -ne 'Enabled') {
        $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart
        if($result.RestartNeeded) { throw 'WSL_REBOOT_REQUIRED: restart Windows and rerun this phase.' }
    }
}
$names=Distros
if($names -notcontains $Name){
    if($names -notcontains $Source){Invoke-Wsl -arguments @('--install','-d',$Source,'--no-launch','--web-download')}
    # No continuar si Windows necesita reiniciar para habilitar WSL.
    Invoke-Wsl -arguments @('--set-default-version','2')
    $tar=Join-Path $env:TEMP 'iasi-ubuntu-24.04.tar'
    try {
        if(-not(Test-Path -LiteralPath $tar)){Invoke-Wsl -arguments @('--export',$Source,$tar)}
        New-Item -ItemType Directory -Force -Path (Split-Path $Destination -Parent) | Out-Null
        if ((Test-Path $Destination) -and (Get-ChildItem $Destination -Force -ErrorAction SilentlyContinue)) {throw "Destino ocupado sin distro registrada: $Destination"}
        Invoke-Wsl -arguments @('--import',$Name,$Destination,$tar,'--version','2')
    } finally { if((Distros) -contains $Name){Remove-Item -LiteralPath $tar -Force -ErrorAction SilentlyContinue} }
}
# Validar funcionamiento real antes de desregistrar la distribucion temporal.
Invoke-Wsl -arguments @('-d',$Name,'--user','root','--','/bin/sh','-c','test -f /etc/os-release && grep -q "24.04" /etc/os-release')
Invoke-Wsl -arguments @('--set-default',$Name)
if ((Distros) -contains $Source) {Invoke-Wsl -arguments @('--unregister',$Source)}
Write-Host 'WSL: IASI verificada y predeterminada. Fuente temporal eliminada.'
Write-Warning 'Las distribuciones importadas suelen arrancar como root; configurar el usuario Linux en la fase 2.'
