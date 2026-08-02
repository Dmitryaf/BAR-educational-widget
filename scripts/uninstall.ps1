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

$manifestPath = Join-Path $PSScriptRoot 'production-files.psd1'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Production file manifest is missing: $manifestPath"
}
$productionFiles = Import-PowerShellDataFile -LiteralPath $manifestPath
$widgetDirectory = Join-Path $barDataItem.FullName 'LuaUI\Widgets'
$helperDirectory = Join-Path $barDataItem.FullName 'LuaUI\Include\bar_learning_coach'

$ownedFiles = @()
$ownedFiles += Join-Path $widgetDirectory $productionFiles.EntryPoint
foreach ($legacyName in $productionFiles.LegacyEntryPoints) {
    $ownedFiles += Join-Path $widgetDirectory $legacyName
}
foreach ($helperName in $productionFiles.Helpers) {
    $ownedFiles += Join-Path $helperDirectory $helperName
}

Write-Host 'Removing BAR Learning Coach files:'
foreach ($ownedPath in $ownedFiles) {
    if (Test-Path -LiteralPath $ownedPath -PathType Leaf) {
        Remove-Item -LiteralPath $ownedPath -Force
        Write-Host "  removed: $ownedPath"
    } else {
        Write-Host "  already absent: $ownedPath"
    }
}

if (Test-Path -LiteralPath $helperDirectory -PathType Container) {
    $remainingHelpers = @(Get-ChildItem -LiteralPath $helperDirectory -Force)
    if ($remainingHelpers.Count -eq 0) {
        Remove-Item -LiteralPath $helperDirectory
        Write-Host "  removed empty directory: $helperDirectory"
    } else {
        Write-Host "  kept directory with unowned files: $helperDirectory"
    }
}

Write-Host 'BAR Learning Coach uninstall complete.'
