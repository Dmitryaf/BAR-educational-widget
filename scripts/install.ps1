[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$BarDataDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $barDataItem = Get-Item -LiteralPath $BarDataDir -ErrorAction Stop
} catch {
    throw "BAR data directory does not exist: $BarDataDir"
}
if (-not $barDataItem.PSIsContainer) {
    throw "BAR data directory is not a directory: $BarDataDir"
}

$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$manifestPath = Join-Path $PSScriptRoot 'production-files.psd1'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Production file manifest is missing: $manifestPath"
}
$productionFiles = Import-PowerShellDataFile -LiteralPath $manifestPath

$sourceWidgets = @()
foreach ($entryPointName in $productionFiles.EntryPoints) {
    $sourceWidgets += Join-Path $repositoryRoot (Join-Path 'LuaUI\Widgets' $entryPointName)
}
$sourceHelperRoot = Join-Path $repositoryRoot 'LuaUI\Include\bar_learning_coach'
$requiredSources = @($sourceWidgets)
foreach ($helperName in $productionFiles.Helpers) {
    $requiredSources += Join-Path $sourceHelperRoot $helperName
}
foreach ($sourcePath in $requiredSources) {
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required production source is missing: $sourcePath"
    }
}

$widgetDirectory = Join-Path $barDataItem.FullName 'LuaUI\Widgets'
$helperDirectory = Join-Path $barDataItem.FullName 'LuaUI\Include\bar_learning_coach'
New-Item -ItemType Directory -Force -Path $widgetDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $helperDirectory | Out-Null

$removedLegacy = @()
foreach ($legacyName in $productionFiles.LegacyEntryPoints) {
    $legacyPath = Join-Path $widgetDirectory $legacyName
    if (Test-Path -LiteralPath $legacyPath -PathType Leaf) {
        Remove-Item -LiteralPath $legacyPath -Force
        $removedLegacy += $legacyName
    }
}

for ($index = 0; $index -lt $productionFiles.EntryPoints.Count; $index++) {
    $entryPointName = $productionFiles.EntryPoints[$index]
    Copy-Item -LiteralPath $sourceWidgets[$index] `
        -Destination (Join-Path $widgetDirectory $entryPointName) -Force
}
foreach ($helperName in $productionFiles.Helpers) {
    Copy-Item -LiteralPath (Join-Path $sourceHelperRoot $helperName) `
        -Destination (Join-Path $helperDirectory $helperName) -Force
}

Write-Host 'BAR Replay Coach and Opening Practice installed or updated.'
Write-Host "  BAR data directory: $($barDataItem.FullName)"
Write-Host "  Entrypoints copied: $($productionFiles.EntryPoints -join ', ')"
Write-Host "  Production helpers copied: $($productionFiles.Helpers.Count)"
if ($removedLegacy.Count -gt 0) {
    Write-Host "  Legacy entrypoints removed: $($removedLegacy -join ', ')"
} else {
    Write-Host '  Legacy entrypoints removed: none found'
}
