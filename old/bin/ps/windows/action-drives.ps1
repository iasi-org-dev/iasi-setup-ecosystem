param([hashtable]$Task)
$ErrorActionPreference = 'Stop'
$prj = [string]$Task['root']
$dev = Join-Path $prj 'iasi-dev'
foreach ($dir in @($prj,$dev)) { if (-not (Test-Path -LiteralPath $dir -PathType Container)) { throw "Missing directory: $dir" } }
function Escape-Reg([string]$value) { $value.Replace('\','\\').Replace('"','\"') }
$p = Escape-Reg ('\??\' + $prj)
$i = Escape-Reg ('\??\' + $dev)
$logDir = Join-Path $env:ProgramData 'IASI'; New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$regFile = Join-Path $logDir 'drives.reg'
$txt = @('Windows Registry Editor Version 5.00','','[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\DOS Devices]',('"P:"="'+$p+'"'),('"I:"="'+$i+'"')) -join "`r`n"
[System.IO.File]::WriteAllText($regFile,$txt+"`r`n",[System.Text.UnicodeEncoding]::new($false,$true))
& reg.exe import $regFile
if ($LASTEXITCODE -ne 0) { throw "Registry import failed: $LASTEXITCODE" }
Write-Host "Mapped P: and I: in registry. Reboot required."
