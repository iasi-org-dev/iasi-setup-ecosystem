param([hashtable]$Task)
$ErrorActionPreference = 'Stop'
$git = Join-Path $env:ProgramFiles 'Git\cmd\git.exe'
if (-not (Test-Path -LiteralPath $git)) {
    # winget may not be provisioned for LocalSystem; use the official installer.
    $ProgressPreference = 'SilentlyContinue'
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/git-for-windows/git/releases/latest' -Headers @{ 'User-Agent'='IASI-Setup' }
    $asset = $release.assets | Where-Object { $_.name -match '^Git-.*-64-bit\.exe$' } | Select-Object -First 1
    if (-not $asset) { throw 'Git for Windows x64 installer not found in the official release.' }
    $installerPath = Join-Path $env:TEMP 'iasi-git-installer.exe'
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath -Headers @{ 'User-Agent'='IASI-Setup' }
    try {
        $signature = Get-AuthenticodeSignature -FilePath $installerPath
        if ($signature.Status -ne 'Valid') { throw "Git installer signature is not valid: $($signature.Status)" }
        $process = Start-Process -FilePath $installerPath -ArgumentList '/VERYSILENT','/NORESTART','/SUPPRESSMSGBOXES','/SP-' -Wait -PassThru
        if ($process.ExitCode -ne 0) { throw "Git installer failed: $($process.ExitCode)" }
    } finally { Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue }
}
if (-not (Test-Path -LiteralPath $git)) { throw "Git executable not found: $git" }
& $git --version
