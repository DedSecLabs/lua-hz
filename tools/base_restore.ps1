# Restore one LuaHZ base installation. Refuses files changed since that install.
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$GamePath
)
$ErrorActionPreference = 'Stop'
$backup = Split-Path -Parent $MyInvocation.MyCommand.Path
$game = (Resolve-Path -LiteralPath $GamePath).ProviderPath
$owner = Split-Path -Parent (Split-Path -Parent $backup)
if ($owner.TrimEnd('\', '/') -ne $game.TrimEnd('\', '/')) { throw 'Backup belongs to a different game.' }
foreach ($name in @('gta_sa', 'samp')) {
    if (Get-Process -Name $name -ErrorAction SilentlyContinue) { throw 'Close GTA and SA-MP first.' }
}
function Convert-GamePath([string]$relative) { return Join-Path $game ($relative -replace '/', [IO.Path]::DirectorySeparatorChar) }
foreach ($line in Get-Content -LiteralPath (Join-Path $backup 'FILES.sha256')) {
    if ($line -notmatch '^([0-9a-fA-F]{64})\s+(.+)$') { continue }
    $relative = $Matches[2]
    $current = Convert-GamePath $relative
    while ($current -and ($current.TrimEnd('\', '/') -ne $game.TrimEnd('\', '/'))) {
        if (Test-Path -LiteralPath $current) {
            if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Symlink refused: $current"
            }
        }
        $parent = Split-Path -Parent $current
        if (-not $parent -or $parent -eq $current) { break }
        $current = $parent
    }
    $target = Convert-GamePath $relative
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Missing installed file: $relative" }
    $got = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($got -ne $Matches[1].ToLowerInvariant()) { throw "Recovery refused because $relative changed after installation." }
}
foreach ($relative in Get-Content -LiteralPath (Join-Path $backup 'written.txt')) {
    if (-not $relative) { continue }
    $saved = Join-Path (Join-Path $backup 'original') ($relative -replace '/', [IO.Path]::DirectorySeparatorChar)
    $target = Convert-GamePath $relative
    if (Test-Path -LiteralPath $saved -PathType Leaf) { Copy-Item -LiteralPath $saved -Destination $target -Force }
    else { Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue }
}
foreach ($owned in @('moonloader/lib/horizonbase', 'moonloader/resource/horizonbase')) {
    $dir = Convert-GamePath $owned
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    Get-ChildItem -LiteralPath $dir -Recurse -Directory -Force |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object { if (-not (Get-ChildItem -LiteralPath $_.FullName -Force)) { Remove-Item -LiteralPath $_.FullName -Force } }
    if (-not (Get-ChildItem -LiteralPath $dir -Force)) { Remove-Item -LiteralPath $dir -Force }
}
Write-Output 'Base files restored. Player settings and unrelated files were preserved; backup retained.'
