#Requires -Version 7.0
<#
.SYNOPSIS
Deploy the Wallbox HMI sources to Home Assistant over SSH/SCP.
.DESCRIPTION
Adapted from esphome-r4875g1-3phase-charger/scripts/deploy-ha.ps1.
Copies one main YAML and its existing device-scoped package tree unchanged.
Excludes secrets.yaml and .env files; never validates, compiles or flashes firmware.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9.-]*$')]
    [string]$HaHost = '10.10.80.9',
    [ValidatePattern('^[A-Za-z_][A-Za-z0-9_-]*$')]
    [string]$HaUser = 'root',
    [ValidateRange(1, 65535)]
    [int]$Port = 22,
    [string]$RemoteDir = '/config/esphome',
    [string]$KeyPath = "$HOME/.ssh/ha_esphome_deploy",
    [string]$MacAlgorithm = 'hmac-sha2-512-etm@openssh.com',
    [switch]$DryRun,
    [switch]$NoBackup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectFile = 'ng-eg-gang-wallbox-hmi.yaml'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$RunId = "$(Get-Date -Format 'yyyyMMdd-HHmmss')-$([guid]::NewGuid().ToString('N'))"
$NetworkTimeoutSeconds = 30
$TransferTimeoutSeconds = 120
$Attempts = 3
$BundlePath = $null
$StagingCreated = $false

function Write-Step([string]$Message) { Write-Host "[DEPLOY] $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "[  OK  ] $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "[ WARN ] $Message" -ForegroundColor Yellow }

function ConvertTo-ShQuotedString([string]$Value) {
    if ($Value -match "['\r\n\x00]") {
        throw "Unsupported character in remote path: $Value"
    }
    return "'$Value'"
}

function Assert-SafeRelativePath([string]$Path) {
    if ($Path -notmatch '^[A-Za-z0-9_./-]+$' -or $Path.StartsWith('/') -or
        (($Path -split '/') -contains '..') -or (($Path -split '/') -contains '.')) {
        throw "Unsafe deployment path: $Path"
    }
}

function Get-NodeName([string]$ProjectPath) {
    # Deliberately require a literal name directly inside the root esphome block.
    # This is a deployment ownership check, not an ESPHome/YAML validator.
    $content = Get-Content -Raw -LiteralPath $ProjectPath
    if ([regex]::Matches($content, '(?m)^esphome:\s*(?:#.*)?$').Count -ne 1) {
        throw 'Expected exactly one root esphome block.'
    }
    $inside = $false
    $names = @()
    foreach ($line in ($content -split '\r?\n')) {
        if ($line -match '^esphome:\s*(?:#.*)?$') { $inside = $true; continue }
        if (-not $inside -or $line -match '^\s*(?:#.*)?$') { continue }
        if ($line -match '^\S') { break }
        if ($line -match '^  name:\s*["'']?([a-z0-9][a-z0-9_-]*)["'']?\s*(?:#.*)?$') {
            $names += $Matches[1]
        }
    }
    if ($names.Count -ne 1) { throw 'Expected one literal esphome.name with two-space indentation.' }
    return $names[0]
}

function Get-ManagedFiles([string]$PackageRelativePath) {
    $root = Join-Path $RepoRoot $PackageRelativePath
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw "Missing device package directory: $PackageRelativePath"
    }
    if ((Get-Item -LiteralPath $root).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'The device package root must not be a symbolic link or junction.'
    }
    $items = @(Get-ChildItem -LiteralPath $root -Force -Recurse)
    $paths = @()
    foreach ($item in $items) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Symbolic links and junctions are not deployable: $($item.FullName)"
        }
        if ($item.PSIsContainer) { continue }
        # Use a source allowlist instead of copying the repository or credentials.
        if ($item.Name -match '^(secrets\.(yaml|yml)|\.env(?:\..*)?)$') { continue }
        if ($item.Extension -notin @('.yaml', '.yml', '.h', '.hpp', '.c', '.cpp', '.ttf', '.otf')) {
            throw "Unsupported package file; review the deployment allowlist: $($item.FullName)"
        }
        $relative = [IO.Path]::GetRelativePath($RepoRoot, $item.FullName).Replace('\', '/')
        Assert-SafeRelativePath $relative
        $paths += $relative
    }
    if ($paths.Count -eq 0) { throw 'The device package tree contains no deployable source files.' }
    foreach ($required in @('trend_buffer.h', 'wallbox_ui.h')) {
        if ($paths -notcontains "$PackageRelativePath/$required") {
            throw "Missing device include: $PackageRelativePath/$required"
        }
    }
    return @($paths | Sort-Object)
}

function Get-GitInfo {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return 'unavailable' }
    try {
        $commit = (& git -C $RepoRoot rev-parse --short HEAD 2>$null) -join ''
        $branch = (& git -C $RepoRoot branch --show-current 2>$null) -join ''
        $dirty = @(& git -C $RepoRoot status --porcelain 2>$null).Count -gt 0
        return "$branch / $commit / $(if ($dirty) { 'DIRTY (local files will be copied)' } else { 'clean' })"
    } catch { return 'unavailable' }
}

function Invoke-ExternalProcess([string]$FileName, [string[]]$Arguments, [int]$TimeoutSeconds) {
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FileName
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    foreach ($argument in $Arguments) { [void]$startInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) { throw "Could not start '$FileName'." }
        # Drain both streams concurrently to avoid blocking on full pipe buffers.
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            try { $process.Kill($true) } catch { }
            throw "Process '$FileName' timed out after $TimeoutSeconds seconds."
        }
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOut = $stdout.GetAwaiter().GetResult()
            StdErr = $stderr.GetAwaiter().GetResult()
        }
    } finally { $process.Dispose() }
}

function Invoke-WithNetworkRetry([string]$FileName, [string[]]$Arguments, [int]$TimeoutSeconds) {
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            $result = Invoke-ExternalProcess $FileName $Arguments $TimeoutSeconds
            if ($result.ExitCode -eq 0) { return $result.StdOut }
            throw "$FileName exited with code $($result.ExitCode): $($result.StdErr.Trim())"
        } catch {
            $failure = $_.Exception.Message
            $transient = $failure -match '(?i)timed out|connection reset|connection closed|connection refused|connection aborted|no route to host|network is unreachable|kex_exchange_identification'
            if (-not $transient -or $attempt -eq $Attempts) { throw }
            Write-Warn "Attempt $attempt/$Attempts failed: $failure"
            Start-Sleep -Seconds 2
        }
    }
}

function Get-SshOptions {
    $options = @(
        '-i', $KeyPath, '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8',
        '-o', 'ConnectionAttempts=1', '-o', 'ServerAliveInterval=5',
        '-o', 'ServerAliveCountMax=3', '-o', 'StrictHostKeyChecking=accept-new'
    )
    if (-not [string]::IsNullOrWhiteSpace($MacAlgorithm)) { $options += @('-o', "MACs=$MacAlgorithm") }
    return $options
}

function Invoke-HaSsh([string]$Command) {
    $arguments = @(Get-SshOptions) + @('-p', "$Port", "$HaUser@$HaHost", $Command)
    return Invoke-WithNetworkRetry 'ssh' $arguments $NetworkTimeoutSeconds
}

function Get-ParentDirectories([string[]]$Paths) {
    $directories = [Collections.Generic.HashSet[string]]::new()
    foreach ($path in $Paths) {
        $parent = [IO.Path]::GetDirectoryName($path)
        while (-not [string]::IsNullOrWhiteSpace($parent)) {
            [void]$directories.Add($parent.Replace('\', '/'))
            $parent = [IO.Path]::GetDirectoryName($parent)
        }
    }
    return @($directories | Sort-Object { ($_ -split '/').Count }, { $_ })
}

function New-RemoteDirectories([string]$Root, [string[]]$Paths) {
    $directories = @($Root) + @(Get-ParentDirectories $Paths | ForEach-Object { "$Root/$_" })
    $commands = @('set -eu')
    foreach ($directory in $directories) {
        $quoted = ConvertTo-ShQuotedString $directory
        $commands += "if [ -L $quoted ]; then echo 'Refusing symbolic-link directory' >&2; exit 1; fi"
        $commands += "mkdir -p $quoted"
    }
    Invoke-HaSsh ($commands -join '; ') | Out-Null
}

function Assert-RemoteHashes([string]$Root, [string[]]$Files) {
    $quotedPaths = @($Files | ForEach-Object { ConvertTo-ShQuotedString "$Root/$_" })
    $output = Invoke-HaSsh ("set -eu; sha256sum " + ($quotedPaths -join ' '))
    $lines = @($output -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($lines.Count -ne $Files.Count) { throw 'Remote SHA-256 output count mismatch.' }
    for ($index = 0; $index -lt $Files.Count; $index++) {
        $hashMatch = [regex]::Match($lines[$index], '^([a-fA-F0-9]{64})\s+')
        if (-not $hashMatch.Success) { throw 'Invalid remote SHA-256 output.' }
        $remoteHash = $hashMatch.Groups[1].Value
        $localHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $BundlePath $Files[$index])).Hash
        if ($localHash -ne $remoteHash) { throw "SHA-256 mismatch: $($Files[$index])" }
    }
}

Write-Step 'Checking local deployment sources'
$RemoteDir = $RemoteDir.TrimEnd('/')
if ($RemoteDir -notmatch '^/[A-Za-z0-9_./-]+$' -or
    (($RemoteDir -split '/') -contains '..') -or (($RemoteDir -split '/') -contains '.')) {
    throw 'RemoteDir must be an absolute, non-root POSIX path without spaces or dot segments.'
}
$projectPath = Join-Path $RepoRoot $ProjectFile
if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) { throw "Missing $ProjectFile" }
if ((Get-Item -LiteralPath $projectPath).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'The main YAML must not be a symbolic link.'
}
$NodeName = Get-NodeName $projectPath
if ($ProjectFile -ne "$NodeName.yaml") { throw 'Main YAML filename and esphome.name must match.' }
$PackageRoot = "packages/$NodeName"
$Files = @($ProjectFile) + @(Get-ManagedFiles $PackageRoot)
$BackupDir = "$RemoteDir/.deploy-backups/$NodeName/$RunId"
$StagingDir = "$RemoteDir/.deploy-staging/$NodeName-$RunId"

Write-Host "  Source : $ProjectFile and $PackageRoot/"
Write-Host "  Git    : $(Get-GitInfo)"
Write-Host "  Target : ${HaUser}@${HaHost}:$RemoteDir (SSH port $Port)"
Write-Host "  Files  : $($Files.Count)"

if ($DryRun) {
    Write-Step 'Dry run: no SSH/SCP, temporary bundle or remote changes'
    foreach ($file in $Files) { Write-Host "  $file -> $RemoteDir/$file" }
    if (-not $NoBackup) { Write-Host "  Backup: $BackupDir" }
    Write-Ok 'Dry run complete; no ESPHome validation or compilation performed'
    return
}

foreach ($command in @('ssh', 'scp')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { throw "Required command not found: $command" }
}
if (-not (Test-Path -LiteralPath $KeyPath -PathType Leaf)) {
    throw "SSH key not found: $KeyPath. Supply -KeyPath for an existing deployment key."
}

try {
    # Freeze one source snapshot; verify uploaded data against these copies,
    # not against working-tree files that could change during the transfer.
    $BundlePath = Join-Path ([IO.Path]::GetTempPath()) "wallbox-deploy-$RunId"
    New-Item -ItemType Directory -Path $BundlePath | Out-Null
    foreach ($file in $Files) {
        $destination = Join-Path $BundlePath $file
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $RepoRoot $file) -Destination $destination
    }

    Write-Step 'Creating isolated remote staging directory'
    New-RemoteDirectories $StagingDir $Files
    $StagingCreated = $true
    $sources = @(Get-ChildItem -LiteralPath $BundlePath | Sort-Object Name | ForEach-Object { $_.FullName })
    $arguments = @(Get-SshOptions) + @('-P', "$Port", '-r') + $sources + @("${HaUser}@${HaHost}:$StagingDir/")
    Write-Step 'Uploading source bundle in one SCP session'
    Invoke-WithNetworkRetry 'scp' $arguments $TransferTimeoutSeconds | Out-Null
    Assert-RemoteHashes $StagingDir $Files
    Write-Ok 'Staged SHA-256 hashes match the local source snapshot'

    # Only these managed paths may be touched. Never remove stale files or
    # replace the shared packages directory, secrets.yaml or other devices.
    New-RemoteDirectories $RemoteDir $Files
    $commands = @('set -eu')
    foreach ($file in $Files) {
        $path = ConvertTo-ShQuotedString "$RemoteDir/$file"
        $commands += "if [ -L $path ] || { [ -e $path ] && [ ! -f $path ]; }; then echo 'Unsafe managed destination' >&2; exit 1; fi"
    }
    Invoke-HaSsh ($commands -join '; ') | Out-Null

    if (-not $NoBackup) {
        Write-Step 'Backing up existing managed files'
        New-RemoteDirectories $BackupDir $Files
        $commands = @('set -eu')
        foreach ($file in $Files) {
            $source = ConvertTo-ShQuotedString "$RemoteDir/$file"
            $destination = ConvertTo-ShQuotedString "$BackupDir/$file"
            $commands += "if [ -f $source ]; then cp -p $source $destination; fi"
        }
        Invoke-HaSsh ($commands -join '; ') | Out-Null
        Write-Ok "Backup retained: $BackupDir"
    } else { Write-Warn 'Backup disabled by -NoBackup' }

    Write-Step 'Installing package sources, then the main YAML'
    $commands = @('set -eu')
    $installOrder = @($Files | Where-Object { $_ -ne $ProjectFile }) + @($ProjectFile)
    foreach ($file in $installOrder) {
        $source = ConvertTo-ShQuotedString "$StagingDir/$file"
        $destination = ConvertTo-ShQuotedString "$RemoteDir/$file"
        $commands += "cp -p $source $destination"
    }
    Invoke-HaSsh ($commands -join '; ') | Out-Null
    Assert-RemoteHashes $RemoteDir $Files
    Write-Ok 'Installed SHA-256 hashes match the source snapshot'
    Write-Ok 'Deployment complete. Validate/build/install manually in ESPHome when ready.'
} catch {
    Write-Warn 'Deployment failed. Installation is not transactional; check the target before building.'
    if (-not $NoBackup) { Write-Warn "Any completed backup remains at: $BackupDir" }
    throw
} finally {
    if ($StagingCreated) {
        try { Invoke-HaSsh ("rm -rf " + (ConvertTo-ShQuotedString $StagingDir)) | Out-Null }
        catch { Write-Warn "Could not remove this run's staging directory: $StagingDir" }
    }
    if ($null -ne $BundlePath -and (Test-Path -LiteralPath $BundlePath)) {
        Remove-Item -LiteralPath $BundlePath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
