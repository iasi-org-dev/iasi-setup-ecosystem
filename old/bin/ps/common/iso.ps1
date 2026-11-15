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
    param([string]$UbuntuISO, [string]$InstallISO, [string]$VMName, [string]$SeedContentPath)
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
        $GrubText = [IO.File]::ReadAllText($Grub)
        $GrubText = $GrubText.Replace('autoinstall ---', 'autoinstall ds="nocloud;s=/cdrom/" ---')
        [IO.File]::WriteAllText($Grub, $GrubText, [Text.UTF8Encoding]::new($false))
        Invoke-IasiIsoCommand -Directory $Work -Arguments @(
            'grep', '-Fq', 'autoinstall', $WslGrub
        ) -ErrorMessage 'autoinstall was not added to grub.cfg.'
        $Arguments = @('xorriso', '-indev', $InputISO, '-outdev', $OutputISO,
            '-boot_image', 'any', 'replay', '-map', $WslGrub, '/boot/grub/grub.cfg')
        if ($SeedContentPath) {
            foreach ($Required in @('user-data', 'meta-data', 'network-config')) {
                if (-not (Test-Path -LiteralPath (Join-Path $SeedContentPath $Required) -PathType Leaf)) {
                    throw "Expected NoCloud file missing: $Required"
                }
            }
            if (-not (Test-Path -LiteralPath (Join-Path $SeedContentPath 'iasi/install.sh') -PathType Leaf)) {
                throw 'Expected iasi/install.sh missing from seed.'
            }
            foreach ($Entry in (Get-ChildItem -LiteralPath $SeedContentPath -Force)) {
                $EntryLinux = Convert-ToWslPath $Entry.FullName
                $Arguments += @('-map', $EntryLinux, "/$($Entry.Name)")
            }
        }
        Invoke-IasiIsoCommand -Directory $Work -Arguments $Arguments -ErrorMessage 'Unable to create unattended Ubuntu ISO.'
        if ($SeedContentPath) {
            $Probe = Join-Path $Work 'probe'
            New-Item -ItemType Directory -Path $Probe -Force | Out-Null
            foreach ($Relative in @('user-data', 'meta-data', 'network-config', 'iasi/install.sh')) {
                $Target = Join-Path $Probe ($Relative.Replace('/', [IO.Path]::DirectorySeparatorChar))
                New-Item -ItemType Directory -Path (Split-Path -Parent $Target) -Force | Out-Null
                Invoke-IasiIsoCommand -Directory $Work -Arguments @(
                    'xorriso', '-osirrox', 'on', '-indev', $OutputISO,
                    '-extract', "/$Relative", (Convert-ToWslPath $Target)
                ) -ErrorMessage "ISO verification failed for /$Relative."
                if (-not (Test-Path -LiteralPath $Target -PathType Leaf)) {
                    throw "ISO verification found a directory instead of file: /$Relative"
                }
            }
            if ((Get-Item -LiteralPath (Join-Path $Probe 'user-data')).Length -eq 0) {
                throw 'ISO verification found empty user-data.'
            }
        }
        Write-LogSuccess "Unattended Ubuntu ISO created and structurally verified: $InstallISO"
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
    $Names = @($Packages | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
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

# The separate NoCloud network-config controls installer networking. The
# installed system must also receive network settings via autoinstall.network.
function Set-AutoinstallNetwork {
    param([string]$UserDataPath, [string]$NetworkConfigPath)
    $Text = [IO.File]::ReadAllText($UserDataPath)
    if ([regex]::Matches($Text, '(?m)^autoinstall:\s*$').Count -ne 1) {
        throw 'Expected exactly one autoinstall mapping.'
    }
    if ($Text -match '(?m)^  network:\s*$') {
        throw 'Refusing to overwrite preexisting autoinstall.network.'
    }
    $NetworkLines = [IO.File]::ReadAllLines($NetworkConfigPath)
    if ($NetworkLines.Count -eq 0) { throw 'Generated NoCloud network-config is empty.' }
    $IndentedNetwork = ($NetworkLines | ForEach-Object { '    ' + $_ }) -join "`n"
    $Replacement = "autoinstall:`n  network:`n$IndentedNetwork"
    $Text = [regex]::Replace($Text, '(?m)^autoinstall:\s*$', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $Replacement })
    [IO.File]::WriteAllText($UserDataPath, $Text, [Text.UTF8Encoding]::new($false))
    $Check = [IO.File]::ReadAllText($UserDataPath)
    if ($Check -notmatch '(?m)^  network:\s*$' -or $Check -notmatch '(?m)^    ethernets:\s*$') {
        throw 'ISO QA failed: installed-system network configuration missing.'
    }
    Write-LogInfo 'Subiquity autoinstall.network generated for installed system.'
}

function Set-AutoinstallIdentity {
    param([string]$UserDataPath, [string]$User, [string]$Password)
    if ([string]::IsNullOrEmpty($User) -or [string]::IsNullOrEmpty($Password)) {
        throw 'Missing resolved Linux identity.'
    }
    if ($User -notmatch '^[a-z_][a-z0-9_-]*$') {
        throw 'Invalid Linux account name in resolved identity.'
    }
    $SecretFile = Join-Path ([IO.Path]::GetTempPath()) ('iasi-secret-' + [guid]::NewGuid().ToString('N'))
    try {
        [IO.File]::WriteAllBytes($SecretFile, [Text.Encoding]::UTF8.GetBytes($Password))
        $LinuxSecret = Convert-ToWslPath -WindowsPath $SecretFile
        $HashLines = @(& wsl.exe --exec sh -c 'openssl passwd -6 -stdin < "$1"' sh $LinuxSecret)
        $HashExit = $LASTEXITCODE
        if ($HashExit -ne 0 -or $HashLines.Count -ne 1) {
            throw 'OpenSSL failed to generate the Ubuntu password hash.'
        }
        $Hash = [string]$HashLines[0]
        if ($Hash -notmatch '^\$6\$([A-Za-z0-9./]+)\$[A-Za-z0-9./]+$') {
            throw 'Unexpected SHA-512 crypt password hash format.'
        }
        $Salt = $Matches[1]
        $CheckLines = @(& wsl.exe --exec sh -c 'openssl passwd -6 -salt "$1" -stdin < "$2"' sh $Salt $LinuxSecret)
        $CheckExit = $LASTEXITCODE
        if ($CheckExit -ne 0 -or $CheckLines.Count -ne 1 -or [string]$CheckLines[0] -cne $Hash) {
            throw 'IASI identity QA FAIL: generated hash does not match the declared password.'
        }
        $Text = [IO.File]::ReadAllText($UserDataPath)
        $UserPattern = '(?m)^(    username:).*$'
        $PasswordPattern = '(?m)^(    password:).*$'
        if ([regex]::Matches($Text, $UserPattern).Count -ne 1 -or
            [regex]::Matches($Text, $PasswordPattern).Count -ne 1) {
            throw 'Expected exactly one Ubuntu autoinstall identity.'
        }
        $Text = [regex]::Replace($Text, $UserPattern, { param($m) $m.Groups[1].Value + ' ' + $User })
        $Text = [regex]::Replace($Text, $PasswordPattern, { param($m) $m.Groups[1].Value + ' "' + $Hash + '"' })
        [IO.File]::WriteAllText($UserDataPath, $Text, [Text.UTF8Encoding]::new($false))
        Write-LogInfo 'IASI identity QA PASS: Ubuntu credentials generated and checked.'
    }
    finally {
        if (Test-Path -LiteralPath $SecretFile) {
            Remove-Item -LiteralPath $SecretFile -Force -ErrorAction Stop
        }
    }
}

function New-SeedISO {
    param([string]$ConfigPath, [string]$SeedISO, [string]$VMName, [object[]]$Packages,
        [string]$IPAddress, [int]$PrefixLength,
        [string]$NetworkInterface, [string]$InternetNetworkInterface, [hashtable]$ServicePorts,
        [string]$SeedContentPath, [string]$IdentityUser, [string]$IdentityPassword)
    Write-LogInfo 'Creating seed ISO...'
    $Stage = Join-Path ([IO.Path]::GetTempPath()) "$VMName-seed-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $Stage -Force | Out-Null
    try {
        Get-ChildItem -LiteralPath $ConfigPath | Where-Object { $_.Name -ne 'logs' } | Copy-Item -Destination $Stage -Recurse -Force
        $UserData = Join-Path $Stage 'user-data'
        Test-AutoinstallNetworkNotDefined -UserDataPath $UserData
        Set-AutoinstallIdentity -UserDataPath $UserData -User $IdentityUser -Password $IdentityPassword
        Set-AutoinstallPackages -UserDataPath $UserData -Packages $Packages
        $GeneratedYaml = Get-Content -LiteralPath $UserData -Raw -Encoding UTF8
        foreach ($Package in @($Packages)) {
            if ($GeneratedYaml -notmatch ('(?m)^    - ' + [regex]::Escape([string]$Package) + '\s*$')) {
                throw "ISO QA failed: declared package '$Package' is missing from user-data."
            }
        }
        if (@($Packages).Count -gt 0 -and $GeneratedYaml -notmatch '(?m)^  packages:\s*$') {
            throw 'ISO QA failed: no packages section in generated user-data.'
        }
        Set-AutoinstallServices -StagePath $Stage -UserDataPath $UserData -ServicePorts $ServicePorts
        New-NoCloudNetworkConfig -Path (Join-Path $Stage 'network-config') -IPAddress $IPAddress -PrefixLength $PrefixLength -NetworkInterface $NetworkInterface -InternetNetworkInterface $InternetNetworkInterface
        Set-AutoinstallNetwork -UserDataPath $UserData -NetworkConfigPath (Join-Path $Stage 'network-config')
        if ($SeedContentPath) {
            New-Item -ItemType Directory -Path $SeedContentPath -Force | Out-Null
            Get-ChildItem -LiteralPath $Stage -Force | ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination $SeedContentPath -Recurse -Force
            }
            foreach ($Name in @('user-data', 'meta-data', 'network-config')) {
                if (-not (Test-Path -LiteralPath (Join-Path $SeedContentPath $Name) -PathType Leaf)) {
                    throw "Expected NoCloud file missing: $Name"
                }
            }
        }
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
        [string]$IPAddress, [int]$PrefixLength,
        [string]$NetworkInterface, [string]$InternetNetworkInterface, [hashtable]$ServicePorts,
        [string]$IdentityUser, [string]$IdentityPassword)
    $Stage = Join-Path ([IO.Path]::GetTempPath()) "$VMName-media-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $Stage -Force | Out-Null
    $InstallISO = Join-Path $Stage "$VMName.iso"
    $SeedISO = Join-Path $Stage "$VMName-seed.iso"
    try {
        $SeedContentPath = Join-Path $Stage 'seed-content'
        New-SeedISO -ConfigPath $ConfigPath -SeedISO $SeedISO -VMName $VMName -Packages $Packages -IPAddress $IPAddress -PrefixLength $PrefixLength -NetworkInterface $NetworkInterface -InternetNetworkInterface $InternetNetworkInterface -ServicePorts $ServicePorts -SeedContentPath $SeedContentPath -IdentityUser $IdentityUser -IdentityPassword $IdentityPassword
        New-UnattendedUbuntuISO -UbuntuISO $UbuntuISO -InstallISO $InstallISO -VMName $VMName -SeedContentPath $SeedContentPath
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

