# Install the LuaHZ base payload onto a clean GTA folder. Not yet tested on native Windows.
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$GamePath
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$game = (Resolve-Path -LiteralPath $GamePath).ProviderPath

function Test-GameClosed {
    foreach ($name in @('gta_sa', 'samp')) {
        if (Get-Process -Name $name -ErrorAction SilentlyContinue) { throw 'Close GTA and SA-MP first.' }
    }
}
function Convert-GamePath([string]$relative) { return Join-Path $game ($relative -replace '/', [IO.Path]::DirectorySeparatorChar) }
function Test-NoReparse([string]$path) {
    $current = $path
    while ($current -and ($current.TrimEnd('\', '/') -ne $game.TrimEnd('\', '/'))) {
        if (Test-Path -LiteralPath $current) {
            if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Symlink target refused: $current"
            }
        }
        $parent = Split-Path -Parent $current
        if (-not $parent -or $parent -eq $current) { break }
        $current = $parent
    }
}
function Read-HashList([string]$file) {
    $rows = @()
    foreach ($line in Get-Content -LiteralPath $file) {
        if ($line -match '^([0-9a-fA-F]{64})\s+(.+)$') {
            $rows += [pscustomobject]@{ Hash = $Matches[1].ToLowerInvariant(); Relative = $Matches[2] }
        }
    }
    if (-not $rows.Count) { throw "No hashes in $file" }
    return $rows
}
function Assert-Hash([string]$base, $row) {
    $target = Join-Path $base ($row.Relative -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Missing file: $($row.Relative)" }
    $got = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($got -ne $row.Hash) { throw "Hash mismatch: $($row.Relative)" }
}
function Clear-EmptyOwned([string]$relative) {
    $dir = Convert-GamePath $relative
    if (-not (Test-Path -LiteralPath $dir)) { return }
    Get-ChildItem -LiteralPath $dir -Recurse -Directory -Force |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object { if (-not (Get-ChildItem -LiteralPath $_.FullName -Force)) { Remove-Item -LiteralPath $_.FullName -Force } }
    if (-not (Get-ChildItem -LiteralPath $dir -Force)) { Remove-Item -LiteralPath $dir -Force }
}

Test-GameClosed
if (-not (Test-Path -LiteralPath (Join-Path $game 'gta_sa.exe') -PathType Leaf)) { throw "No gta_sa.exe in $game" }
foreach ($marker in @('moonloader/HorizonBase.lua', 'moonloader/lib/horizonbase', 'moonloader/resource/horizonbase', 'LuaHZLoading.asi')) {
    if (Test-Path -LiteralPath (Convert-GamePath $marker)) { throw 'Use a separate clean game copy; LuaHZ files already exist here.' }
}
$payloadHashes = Read-HashList (Join-Path $root 'FILES.sha256')
foreach ($row in $payloadHashes) { Assert-Hash (Join-Path $root 'payload') $row }
foreach ($row in (Read-HashList (Join-Path $root 'PREREQUISITES.sha256'))) { Assert-Hash $game $row }
foreach ($required in @('moonloader/lib/moonloader.lua', 'moonloader/lib/vkeys.lua', 'moonloader/lib/windows/message.lua', 'moonloader/lib/mimgui/init.lua', 'moonloader/lib/mimgui/cimguidx9.dll')) {
    if (-not (Test-Path -LiteralPath (Convert-GamePath $required) -PathType Leaf)) { throw "Missing prerequisite: $required" }
}
foreach ($row in $payloadHashes) {
    $target = Convert-GamePath $row.Relative
    Test-NoReparse $target
    if (Test-Path -LiteralPath $target -PathType Container) { throw "File/directory collision: $($row.Relative)" }
}
$backupRoot = Join-Path $game 'LuaHZ-backups'
Test-NoReparse $backupRoot
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
$backup = Join-Path $backupRoot ('base-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'FILES.sha256') -Destination (Join-Path $backup 'FILES.sha256')
Copy-Item -LiteralPath (Join-Path $root 'restore.ps1') -Destination (Join-Path $backup 'restore.ps1')
$written = Join-Path $backup 'written.txt'
Set-Content -LiteralPath $written -Value @() -Encoding ascii
$installed = New-Object System.Collections.Generic.List[string]
try {
    foreach ($row in $payloadHashes) {
        $target = Convert-GamePath $row.Relative
        $source = Join-Path (Join-Path $root 'payload') ($row.Relative -replace '/', [IO.Path]::DirectorySeparatorChar)
        if (Test-Path -LiteralPath $target) {
            $saved = Join-Path (Join-Path $backup 'original') ($row.Relative -replace '/', [IO.Path]::DirectorySeparatorChar)
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $saved) | Out-Null
            Copy-Item -LiteralPath $target -Destination $saved -Force
        }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        Add-Content -LiteralPath $written -Value $row.Relative -Encoding ascii
        $installed.Add($row.Relative)
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
    foreach ($row in $payloadHashes) { Assert-Hash $game $row }
} catch {
    foreach ($relative in $installed) {
        $saved = Join-Path (Join-Path $backup 'original') ($relative -replace '/', [IO.Path]::DirectorySeparatorChar)
        $target = Convert-GamePath $relative
        if (Test-Path -LiteralPath $saved -PathType Leaf) { Copy-Item -LiteralPath $saved -Destination $target -Force }
        else { Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue }
    }
    Clear-EmptyOwned 'moonloader/lib/horizonbase'
    Clear-EmptyOwned 'moonloader/resource/horizonbase'
    [Console]::Error.WriteLine("Installation failed; original files restored. Backup: $backup. $($_.Exception.Message)")
    exit 1
}
Write-Output "Installed. Recovery: powershell -NoProfile -ExecutionPolicy Bypass -File `"$backup\restore.ps1`" `"$game`""
Write-Output 'Launch Horizon from SA-MP in this game copy. F9: settings; I: stats; X: cruise. Native Windows QA has not been run.'
