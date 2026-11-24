param([hashtable]$Task)
# Specific to iasi-dev2: synchronize every public repository in a GitHub organization.
# Uses unauthenticated GitHub REST API and HTTPS git; no SSH keys or GitHub login.
$ErrorActionPreference = 'Stop'
$organization = [string]$Task['organization']
$targetRoot = [string]$Task['target']
if ($organization -cnotmatch '^[A-Za-z0-9-]+$') { throw 'Invalid GitHub organization.' }
if ([string]$Task['update'] -ne 'ff-only') { throw 'Only ff-only updates are supported.' }
if ($Task['public_only'] -ne $true) { throw 'Only public-only synchronization is supported.' }
if (-not [IO.Path]::IsPathRooted($targetRoot)) { throw 'GitHub target must be absolute.' }
$skipDirty = ($Task['skip_dirty'] -eq $true)
$skipped = 0
$git = Join-Path $env:ProgramFiles 'Git\cmd\git.exe'
if (-not (Test-Path -LiteralPath $git)) { throw 'Git missing before organization sync.' }
New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
$env:GIT_TERMINAL_PROMPT = '0'
$env:GCM_INTERACTIVE = 'Never'
$headers = @{ 'User-Agent' = 'IASI-Setup/1.0'; 'Accept' = 'application/vnd.github+json' }
$page = 1
$count = 0
while ($true) {
    # Public repositories only. Rate limits and connectivity failures are propagated.
    $endpoint = "https://api.github.com/orgs/$organization/repos?type=public&per_page=100&page=$page"
    # IRM may return an array as one pipeline object; normalize the JSON array explicitly.
    # Record the actual response per page rather than mistaking a parser issue for no repos.
    Write-Host "IASI GitHub query: organization=$organization page=$page"
    $response = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method Get -ErrorAction Stop
    if ($null -eq $response) { throw "GitHub API returned null for $endpoint" }
    $repos = @($response | ForEach-Object { $_ })
    Write-Host "IASI GitHub repositories received on page ${page}: $($repos.Count)"
    if ($repos.Count -gt 0) {
        $first = $repos[0]
        if ($null -eq $first -or -not ($first.PSObject.Properties.Name -contains 'name') -or -not ($first.PSObject.Properties.Name -contains 'clone_url')) {
            throw "Unexpected GitHub API response structure for $endpoint"
        }
    }
    if ($repos.Count -eq 0) { break }
    foreach ($repo in $repos) {
        if ($repo.private) { continue }
        $repoName = [string]$repo.name
        $url = [string]$repo.clone_url
        if ($repoName -notmatch '^[A-Za-z0-9_.-]+$' -or $url -notmatch '^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\.git$') { throw "Invalid repository entry: $repoName" }
        $destination = Join-Path $targetRoot $repoName
        if (-not (Test-Path -LiteralPath $destination)) {
            Write-Host "IASI org clone: $repoName"
            & $git -c credential.interactive=never clone -- $url $destination
            if ($LASTEXITCODE -ne 0) { throw "Clone failed: $repoName ($LASTEXITCODE)" }
        }
        elseif (Test-Path -LiteralPath (Join-Path $destination '.git')) {
            $origin = & $git -C $destination remote get-url origin
            if ($LASTEXITCODE -ne 0 -or ([string]($origin | Select-Object -First 1)).Trim() -ne $url) { throw "Unexpected remote: $repoName" }
            $dirty = & $git -C $destination status --porcelain
            if ($LASTEXITCODE -ne 0) { throw "Git status failed: $repoName" }
            if ($dirty) {
                if (-not $skipDirty) { throw "Local changes: $repoName" }
                Write-Warning "IASI QA UNKNOWN: local changes in $repoName, skipping update without modifying files."
                $skipped++
            }
            else {
                Write-Host "IASI org update: $repoName"
                & $git -C $destination -c credential.interactive=never pull --ff-only
                if ($LASTEXITCODE -ne 0) { throw "Pull failed: $repoName ($LASTEXITCODE)" }
            }
        }
        else { throw "Non-repository directory in target: $destination" }
        $count++
    }
    if ($repos.Count -lt 100) { break }
    $page++
}
if ($count -eq 0) { throw "No public repositories discovered for $organization; refusing silent success." }
Write-Host "IASI public organization $organization synchronized: $count repositories."

if ($skipped -gt 0) { Write-Warning "IASI QA UNKNOWN: $skipped existing repositories were not updated due to local modifications." }
