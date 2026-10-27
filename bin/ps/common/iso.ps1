<#
.SYNOPSIS
Produces the bootable Subiquity ISO and NoCloud seed ISO for an IASI node.
#>
. "$PSScriptRoot\services.ps1"

function Get-IsoPaths {
    param([string]$UbuntuISO, [string]$VMName)
    $Directory = Split-Path -Parent $UbuntuISO
    [pscustomobject]@{ InstallISO = Join-Path $Directory "$VMName.iso"; SeedISO = Join-Path $Directory "$VMName-seed.iso" }
}

function Convert-ToWslPath {
    param([string]$WindowsPath)
    $FullPath = [IO.Path]::GetFullPath($WindowsPath)
    if ($FullPath -match '^([A-Za-z]):\\(.*)$') {
        return '/mnt/' + $Matches[1].ToLowerInvariant() + '/' + $Matches[2].Replace('\', '/')
    }
    throw "Cannot convert path '$WindowsPath' to a WSL path."
}

function Invoke-IasiIsoCommand {
    param([string]$Directory, [string[]]$Arguments, [string]$ErrorMessage)
    $RC = Invoke-LoggedCommand -Directory $Directory -Command 'wsl.exe' -Arguments $Arguments
    if ($RC -ne 0) { throw "$ErrorMessage See log: $LogFile" }
}

function Test-IsoEnvironment {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { throw 'wsl.exe was not found.' }
    Invoke-IasiIsoCommand -Directory (Get-Location).Path -Arguments @('sh', '-lc', 'command -v xorriso >/dev/null 2>&1') -ErrorMessage 'xorriso was not found in WSL.'
}

function Test-IsoOutputDirectory {
    param([string]$UbuntuISO)
    $Directory = Split-Path -Parent $UbuntuISO
    $Probe = Join-Path $Directory ".iasi-write-test-$([guid]::NewGuid().ToString('N')).tmp"
    try { [IO.File]::WriteAllText($Probe, 'test') }
    catch { throw "Cannot write to ISO directory '$Directory'." }
    finally { if (Test-Path $Probe) { Remove-Item $Probe -Force } }
}

function New-UnattendedUbuntuISO {
    param([string]$UbuntuISO, [string]$InstallISO, [string]$VMName)
    Write-LogInfo 'Creating unattended Ubuntu ISO...'
    if ([IO.Path]::GetFullPath($UbuntuISO) -eq [IO.Path]::GetFullPath($InstallISO)) {
        throw 'Generated ISO cannot overwrite the Ubuntu source ISO.'
    }
    $Work = Join-Path ([IO.Path]::GetTempPath()) "$VMName-iso-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $Work -Force | Out-Null
    $Grub = Join-Path $Work 'grub.cfg'
    $InputISO = Convert-ToWslPath $UbuntuISO
    $OutputISO = Convert-ToWslPath $InstallISO
    $WslGrub = Convert-ToWslPath $Grub
    try {
        Invoke-IasiIsoCommand -Directory $Work -Arguments @(
            'xorriso', '-osirrox', 'on', '-indev', $InputISO,
            '-extract', '/boot/grub/grub.cfg', $WslGrub
        ) -ErrorMessage 'Unable to extract grub.cfg.'
        Invoke-IasiIsoCommand -Directory $Work -Arguments @('chmod', 'u+w', '--', $WslGrub) -ErrorMessage 'Unable to make grub.cfg writable.'
        Invoke-IasiIsoCommand -Directory $Work -Arguments @(
            'sed', '-i', '-E', '-e', 's/^set timeout=.*/set timeout=0/',
            '-e', 's|^([[:space:]]*linux[[:space:]]+[^[:space:]]+[[:space:]]+)---[[:space:]]*$|\1autoinstall ---|', $WslGrub
        ) -ErrorMessage 'Unable to set autoinstall boot entry.'
        Invoke-IasiIsoCommand -Directory $Work -Arguments @(
            'grep', '-Eq', '^[[:space:]]*linux[[:space:]]+[^[:space:]]+[[:space:]]+autoinstall[[:space:]]+---[[:space:]]*$', $WslGrub
        ) -ErrorMessage 'autoinstall was not added to grub.cfg.'
        Invoke-IasiIsoCommand -Directory $Work -Arguments @(
            'xorriso', '-indev', $InputISO, '-outdev', $OutputISO,
            '-boot_image', 'any', 'replay', '-map', $WslGrub, '/boot/grub/grub.cfg'
        ) -ErrorMessage 'Unable to create unattended Ubuntu ISO.'
        Write-LogSuccess "Unattended Ubuntu ISO created: $InstallISO"
    }
    finally { if (Test-Path $Work) { Remove-Item $Work -Recurse -Force } }
}

function Test-AutoinstallNetworkNotDefined {
    param([string]$UserDataPath)
    $Text = Get-Content -LiteralPath $UserDataPath -Raw -Encoding UTF8
    if ($Text -match '(?m)^[ ]{2}network:[ ]*$') {
        throw 'user-data defines an autoinstall network section. Remove it: network configuration is generated from config\iasi-net.toml.'
    }
}

function Set-AutoinstallPackages {
    param([string]$UserDataPath, [object[]]$Packages)
    $Names = @($Packages | ForEach-Object { "$($_)".Trim() } | Where-Object { $_ })
    if (-not $Names.Count) { return }
    Write-LogInfo "Adding autoinstall packages: $($Names -join ', ')"
    $Text = Get-Content -LiteralPath $UserDataPath -Raw -Encoding UTF8
    if ($Text -match '(?m)^  packages:\s*\[\]\s*$') {
        $Text = [regex]::Replace($Text, '(?m)^  packages:\s*\[\]\s*$', ('  packages:' + "`n" + (($Names | ForEach-Object { '    - ' + $_ }) -join "`n")))
    }
    elseif ($Text -match '(?m)^  packages:') {
        throw 'user-data already contains a non-empty packages section.'
    }
    else {
        $Text = $Text -replace '(?m)^autoinstall:\s*$', ('autoinstall:' + "`n" + '  packages:' + "`n" + (($Names | ForEach-Object { '    - ' + $_ }) -join "`n"))
    }
    [IO.File]::WriteAllText($UserDataPath, $Text, [Text.UTF8Encoding]::new($false))
}

function New-NoCloudNetworkConfig {
    param([string]$Path, [string]$IPAddress, [int]$PrefixLength, [string]$NetworkInterface, [string]$InternetNetworkInterface)
    $Lines = @(
        'version: 2', 'ethernets:', "  ${NetworkInterface}:",
        '    dhcp4: false', '    addresses:', "      - ${IPAddress}/${PrefixLength}",
        "  ${InternetNetworkInterface}:", '    dhcp4: true', '    dhcp6: false'
    )
    [IO.File]::WriteAllText($Path, ($Lines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
    Write-LogInfo "NoCloud network-config created: $NetworkInterface=$IPAddress/$PrefixLength, $InternetNetworkInterface=DHCP."
}

function New-SeedISO {
    param([string]$ConfigPath, [string]$SeedISO, [string]$VMName, [object[]]$Packages,
        [string]$IPAddress, [int]$PrefixLength, [string]$Gateway, [object[]]$DnsServers,
        [string]$NetworkInterface, [string]$InternetNetworkInterface, [hashtable]$ServicePorts)
    Write-LogInfo 'Creating seed ISO...'
    $Stage = Join-Path ([IO.Path]::GetTempPath()) "$VMName-seed-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $Stage -Force | Out-Null
    try {
        Get-ChildItem -LiteralPath $ConfigPath | Where-Object { $_.Name -ne 'logs' } | Copy-Item -Destination $Stage -Recurse -Force
        $UserData = Join-Path $Stage 'user-data'
        Test-AutoinstallNetworkNotDefined -UserDataPath $UserData
        Set-AutoinstallPackages -UserDataPath $UserData -Packages $Packages
        Set-AutoinstallServices -StagePath $Stage -UserDataPath $UserData -ServicePorts $ServicePorts
        New-NoCloudNetworkConfig -Path (Join-Path $Stage 'network-config') -IPAddress $IPAddress -PrefixLength $PrefixLength -NetworkInterface $NetworkInterface -InternetNetworkInterface $InternetNetworkInterface
        Invoke-IasiIsoCommand -Directory $Stage -Arguments @(
            'xorriso', '-as', 'mkisofs', '-V', 'CIDATA', '-J', '-R', '-o',
            (Convert-ToWslPath $SeedISO), (Convert-ToWslPath $Stage)
        ) -ErrorMessage 'Unable to create seed ISO.'
        Write-LogSuccess "Seed ISO created: $SeedISO"
    }
    finally { if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force } }
}

function New-InstallationMediaStage {
    param([string]$UbuntuISO, [string]$ConfigPath, [string]$VMName, [object[]]$Packages,
        [string]$IPAddress, [int]$PrefixLength, [string]$Gateway, [object[]]$DnsServers,
        [string]$NetworkInterface, [string]$InternetNetworkInterface, [hashtable]$ServicePorts)
    $Stage = Join-Path ([IO.Path]::GetTempPath()) "$VMName-media-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $Stage -Force | Out-Null
    $InstallISO = Join-Path $Stage "$VMName.iso"
    $SeedISO = Join-Path $Stage "$VMName-seed.iso"
    try {
        New-UnattendedUbuntuISO -UbuntuISO $UbuntuISO -InstallISO $InstallISO -VMName $VMName
        New-SeedISO -ConfigPath $ConfigPath -SeedISO $SeedISO -VMName $VMName -Packages $Packages -IPAddress $IPAddress -PrefixLength $PrefixLength -Gateway $Gateway -DnsServers $DnsServers -NetworkInterface $NetworkInterface -InternetNetworkInterface $InternetNetworkInterface -ServicePorts $ServicePorts
        return [pscustomobject]@{ Path = $Stage; InstallISO = $InstallISO; SeedISO = $SeedISO }
    }
    catch { if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }; throw }
}

function Publish-InstallationMedia {
    param([object]$Stage, [string]$InstallISO, [string]$SeedISO)
    if (Test-Path $InstallISO) { Remove-Item $InstallISO -Force }
    if (Test-Path $SeedISO) { Remove-Item $SeedISO -Force }
    Move-Item -LiteralPath $Stage.InstallISO -Destination $InstallISO -Force
    Move-Item -LiteralPath $Stage.SeedISO -Destination $SeedISO -Force
    Write-LogSuccess "Installation media ready: $InstallISO"
    Write-LogSuccess "Seed media ready: $SeedISO"
}

function Remove-InstallationMediaStage {
    param([object]$Stage)
    if ($Stage -and $Stage.Path -and (Test-Path $Stage.Path)) { Remove-Item $Stage.Path -Recurse -Force }
}
