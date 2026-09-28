function Get-IsoPaths {
    param(
        [string]$UbuntuISO,
        [string]$VMName
    )

    $IsoDirectory = Split-Path -Parent $UbuntuISO

    [pscustomobject]@{
        InstallISO = Join-Path $IsoDirectory "$VMName.iso"
        SeedISO = Join-Path $IsoDirectory "$VMName-seed.iso"
    }
}

function Convert-ToWslPath {
    param([string]$WindowsPath)

    $FullPath = [System.IO.Path]::GetFullPath($WindowsPath)

    if ($FullPath -match '^([A-Za-z]):\\(.*)$') {
        $Drive = $Matches[1].ToLowerInvariant()
        $RelativePath = $Matches[2] -replace '\\', '/'
        return "/mnt/$Drive/$RelativePath"
    }

    throw "Cannot convert path '$WindowsPath' to a WSL path."
}

function Test-IsoEnvironment {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { throw "wsl.exe was not found." }

    $RC = Invoke-LoggedCommand `
        -Directory (Get-Location).Path `
        -Command "wsl.exe" `
        -Arguments @("sh", "-lc", "command -v xorriso >/dev/null 2>&1")

    if ($RC -ne 0) { throw "xorriso was not found in WSL." }
}

function Test-IsoOutputDirectory {
    param([string]$UbuntuISO)

    $IsoDirectory = Split-Path -Parent $UbuntuISO
    $ProbePath = Join-Path $IsoDirectory ".iasi-write-test-$([guid]::NewGuid().ToString('N')).tmp"

    try {
        [System.IO.File]::WriteAllText($ProbePath, "test")
    }
    catch {
        throw "Cannot write to ISO directory '$IsoDirectory'."
    }
    finally {
        if (Test-Path $ProbePath) { Remove-Item $ProbePath -Force }
    }
}


function New-UnattendedUbuntuISO {
    param(
        [string]$UbuntuISO,
        [string]$InstallISO,
        [string]$VMName
    )

    Write-LogInfo "Creating unattended Ubuntu ISO..."

    if ([System.IO.Path]::GetFullPath($UbuntuISO) -eq [System.IO.Path]::GetFullPath($InstallISO)) { throw "Generated ISO cannot overwrite the Ubuntu source ISO." }

    $WorkPath = Join-Path ([System.IO.Path]::GetTempPath()) "$VMName-iso-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $WorkPath -Force | Out-Null

    $GrubPath = Join-Path $WorkPath "grub.cfg"
    $WslUbuntuISO = Convert-ToWslPath $UbuntuISO
    $WslInstallISO = Convert-ToWslPath $InstallISO
    $WslGrubPath = Convert-ToWslPath $GrubPath

    try {
        $RC = Invoke-LoggedCommand `
            -Directory $WorkPath `
            -Command "wsl.exe" `
            -Arguments @(
                "xorriso",
                "-osirrox", "on",
                "-indev", $WslUbuntuISO,
                "-extract", "/boot/grub/grub.cfg", $WslGrubPath
            )

        if ($RC -ne 0) { throw "Unable to extract grub.cfg from Ubuntu ISO. See log: $LogFile" }

        $RC = Invoke-LoggedCommand `
            -Directory $WorkPath `
            -Command "wsl.exe" `
            -Arguments @(
                "chmod", "u+w", "--", $WslGrubPath
            )

        if ($RC -ne 0) { throw "Unable to make grub.cfg writable. See log: $LogFile" }

        $RC = Invoke-LoggedCommand `
            -Directory $WorkPath `
            -Command "wsl.exe" `
            -Arguments @(
                "sed", "-i", "-E",
                "-e", 's/^set timeout=.*/set timeout=0/',
                "-e", 's|^([[:space:]]*linux[[:space:]]+[^[:space:]]+[[:space:]]+)---[[:space:]]*$|\1autoinstall ---|',
                $WslGrubPath
            )

        if ($RC -ne 0) { throw "Unable to update grub.cfg with sed. See log: $LogFile" }

        $RC = Invoke-LoggedCommand `
            -Directory $WorkPath `
            -Command "wsl.exe" `
            -Arguments @(
                "grep", "-Eq", '^[[:space:]]*linux[[:space:]]+[^[:space:]]+[[:space:]]+autoinstall[[:space:]]+---[[:space:]]*$',
                $WslGrubPath
            )

        if ($RC -ne 0) { throw "autoinstall was not added to grub.cfg." }

        $RC = Invoke-LoggedCommand `
            -Directory $WorkPath `
            -Command "wsl.exe" `
            -Arguments @(
                "xorriso",
                "-indev", $WslUbuntuISO,
                "-outdev", $WslInstallISO,
                "-boot_image", "any", "replay",
                "-map", $WslGrubPath, "/boot/grub/grub.cfg"
            )

        if ($RC -ne 0) { throw "Unable to create unattended Ubuntu ISO. See log: $LogFile" }
        Write-LogSuccess "Unattended Ubuntu ISO created: $InstallISO"
    }
    finally {
        if (Test-Path $WorkPath) { Remove-Item $WorkPath -Recurse -Force }
    }
}



function Test-AutoinstallNetworkNotDefined {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserDataPath
    )

    $Text = Get-Content -Path $UserDataPath -Raw -Encoding UTF8

    if ($Text -match '(?m)^[ ]{2}network:[ ]*$') {
        throw "user-data defines an autoinstall network section. Remove it: network configuration is generated from config\iasi-net.toml."
    }
}

function Set-AutoinstallPackages {
    param(
        [string]$UserDataPath,
        [object[]]$Packages
    )

    if (-not $Packages -or $Packages.Count -eq 0) { return }

    $PackageNames = @(
        $Packages |
        ForEach-Object { "$($_)".Trim() } |
        Where-Object { $_ }
    )

    if ($PackageNames.Count -eq 0) { return }

    Write-LogInfo "Adding autoinstall packages: $($PackageNames -join ', ')"

    $WslUserDataPath = Convert-ToWslPath $UserDataPath
    $SedPath = Join-Path ([System.IO.Path]::GetDirectoryName($UserDataPath)) ".iasi-packages-$([guid]::NewGuid().ToString('N')).sed"
    $WslSedPath = Convert-ToWslPath $SedPath

    $EmptyPackagesRC = Invoke-LoggedCommand `
        -Directory ([System.IO.Path]::GetDirectoryName($UserDataPath)) `
        -Command "wsl.exe" `
        -Arguments @(
            "grep", "-Eq",
            '^[[:space:]]*packages:[[:space:]]*\[\][[:space:]]*$',
            $WslUserDataPath
        )

    $AnyPackagesRC = Invoke-LoggedCommand `
        -Directory ([System.IO.Path]::GetDirectoryName($UserDataPath)) `
        -Command "wsl.exe" `
        -Arguments @(
            "grep", "-Eq",
            '^[[:space:]]*packages:[[:space:]]*',
            $WslUserDataPath
        )

    if ($EmptyPackagesRC -ne 0 -and $AnyPackagesRC -eq 0) {
        throw "user-data already contains a non-empty packages section. Refusing to replace it automatically."
    }

    $YamlLines = @("  packages:") + @($PackageNames | ForEach-Object { "    - $_" })

    if ($EmptyPackagesRC -eq 0) {
        $SedLines = @(
            '/^[[:space:]]*packages:[[:space:]]*\[\][[:space:]]*$/c\'
        )
    }
    else {
        $SedLines = @(
            '/^autoinstall:[[:space:]]*$/a\'
        )
    }

    for ($i = 0; $i -lt $YamlLines.Count; $i++) {
        if ($i -lt ($YamlLines.Count - 1)) {
            $SedLines += "$($YamlLines[$i])\"
        }
        else {
            $SedLines += $YamlLines[$i]
        }
    }

    try {
        $UTF8 = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($SedPath, ($SedLines -join "`n") + "`n", $UTF8)

        $RC = Invoke-LoggedCommand `
            -Directory ([System.IO.Path]::GetDirectoryName($UserDataPath)) `
            -Command "wsl.exe" `
            -Arguments @(
                "sed", "-i", "-E", "-f", $WslSedPath,
                $WslUserDataPath
            )

        if ($RC -ne 0) { throw "Unable to add packages to user-data. See log: $LogFile" }

        foreach ($PackageName in $PackageNames) {
            $RC = Invoke-LoggedCommand `
                -Directory ([System.IO.Path]::GetDirectoryName($UserDataPath)) `
                -Command "wsl.exe" `
                -Arguments @(
                    "grep", "-Fq", "    - $PackageName",
                    $WslUserDataPath
                )

            if ($RC -ne 0) { throw "Package '$PackageName' was not added to user-data." }
        }
    }
    finally {
        if (Test-Path $SedPath) { Remove-Item $SedPath -Force }
    }
}


function New-NoCloudNetworkConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$IPAddress,

        [Parameter(Mandatory = $true)]
        [int]$PrefixLength,

        [Parameter(Mandatory = $true)]
        [string]$NetworkInterface,

        [Parameter(Mandatory = $true)]
        [string]$InternetNetworkInterface
    )

    $Lines = @(
        "version: 2",
        "ethernets:",
        "  ${NetworkInterface}:",
        "    dhcp4: false",
        "    addresses:",
        "      - ${IPAddress}/${PrefixLength}",
        "  ${InternetNetworkInterface}:",
        "    dhcp4: true",
        "    dhcp6: false"
    )

    $UTF8 = [System.Text.UTF8Encoding]::new($false)

    [System.IO.File]::WriteAllText(
        $Path,
        ($Lines -join "`n") + "`n",
        $UTF8
    )

    Write-LogInfo "NoCloud network-config created: $NetworkInterface=$IPAddress/$PrefixLength, $InternetNetworkInterface=DHCP."
}

function New-SeedISO {
    param(
        [string]$ConfigPath,
        [string]$SeedISO,
        [string]$VMName,
        [object[]]$Packages,
        [string]$IPAddress,
        [int]$PrefixLength,
        [string]$Gateway,
        [object[]]$DnsServers,
        [string]$NetworkInterface,
        [string]$InternetNetworkInterface
    )

    Write-LogInfo "Creating seed ISO..."

    $StagePath = Join-Path ([System.IO.Path]::GetTempPath()) "$VMName-seed-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $StagePath -Force | Out-Null

    try {
        Get-ChildItem -LiteralPath $ConfigPath |
            Where-Object { $_.Name -ne "logs" } |
            Copy-Item -Destination $StagePath -Recurse -Force

        $StageUserDataPath = Join-Path $StagePath "user-data"
        Test-AutoinstallNetworkNotDefined -UserDataPath $StageUserDataPath
        Set-AutoinstallPackages -UserDataPath $StageUserDataPath -Packages $Packages

        $StageNetworkConfigPath = Join-Path $StagePath "network-config"

        New-NoCloudNetworkConfig `
            -Path $StageNetworkConfigPath `
            -IPAddress $IPAddress `
            -PrefixLength $PrefixLength `
            -NetworkInterface $NetworkInterface `
            -InternetNetworkInterface $InternetNetworkInterface

        $WslStagePath = Convert-ToWslPath $StagePath
        $WslSeedISO = Convert-ToWslPath $SeedISO

        $RC = Invoke-LoggedCommand `
            -Directory $StagePath `
            -Command "wsl.exe" `
            -Arguments @(
                "xorriso",
                "-as", "mkisofs",
                "-V", "CIDATA",
                "-J",
                "-R",
                "-o", $WslSeedISO,
                $WslStagePath
            )

        if ($RC -ne 0) { throw "Unable to create seed ISO. See log: $LogFile" }
        Write-LogSuccess "Seed ISO created: $SeedISO"
    }
    finally {
        if (Test-Path $StagePath) { Remove-Item $StagePath -Recurse -Force }
    }
}

function New-InstallationMediaStage {
    param(
        [string]$UbuntuISO,
        [string]$ConfigPath,
        [string]$VMName,
        [object[]]$Packages,
        [string]$IPAddress,
        [int]$PrefixLength,
        [string]$Gateway,
        [object[]]$DnsServers,
        [string]$NetworkInterface,
        [string]$InternetNetworkInterface
    )

    $StagePath = Join-Path ([System.IO.Path]::GetTempPath()) "$VMName-media-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $StagePath -Force | Out-Null

    $StageInstallISO = Join-Path $StagePath "$VMName.iso"
    $StageSeedISO = Join-Path $StagePath "$VMName-seed.iso"

    try {
        New-UnattendedUbuntuISO -UbuntuISO $UbuntuISO -InstallISO $StageInstallISO -VMName $VMName

        New-SeedISO `
            -ConfigPath $ConfigPath `
            -SeedISO $StageSeedISO `
            -VMName $VMName `
            -Packages $Packages `
            -IPAddress $IPAddress `
            -PrefixLength $PrefixLength `
            -Gateway $Gateway `
            -DnsServers $DnsServers `
            -NetworkInterface $NetworkInterface `
            -InternetNetworkInterface $InternetNetworkInterface

        return [pscustomobject]@{
            Path = $StagePath
            InstallISO = $StageInstallISO
            SeedISO = $StageSeedISO
        }
    }
    catch {
        if (Test-Path $StagePath) { Remove-Item $StagePath -Recurse -Force }
        throw
    }
}

function Publish-InstallationMedia {
    param(
        [object]$Stage,
        [string]$InstallISO,
        [string]$SeedISO
    )

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
