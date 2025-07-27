#!/usr/bin/env pwsh
# Test theme in live environment

# Load framework
. ./Start.ps1 -LoadOnly

# Get theme manager
$tm = $global:ServiceContainer.GetService('ThemeManager')

Write-Host "`nCurrent theme: $($tm._currentTheme)" -ForegroundColor Cyan
Write-Host "Available themes: $($tm.GetThemeNames() -join ', ')" -ForegroundColor Yellow

# Set synthwave theme
$tm.SetTheme('synthwave-84')

Write-Host "`nTheme set to: synthwave-84" -ForegroundColor Magenta

# Test background colors
Write-Host "`nTesting background colors:" -ForegroundColor Green

$bg = $tm.GetBgColor('background')
$dialogBg = $tm.GetBgColor('dialog.background')

Write-Host "Background escape sequence length: $($bg.Length)"
Write-Host "Dialog bg escape sequence length: $($dialogBg.Length)"

# Show the actual escape sequences
Write-Host "`nBackground escape: " -NoNewline
for ($i = 0; $i -lt $bg.Length; $i++) {
    $char = $bg[$i]
    $code = [int]$char
    if ($code -eq 27) {
        Write-Host "[ESC]" -NoNewline -ForegroundColor Yellow
    } elseif ($code -lt 32) {
        Write-Host "[#$code]" -NoNewline -ForegroundColor Red
    } else {
        Write-Host $char -NoNewline
    }
}
Write-Host ""

# Test rendering
Write-Host "`nRendering test:"
Write-Host "${bg}Should have deep purple background (15,0,25)`e[0m"
Write-Host "${dialogBg}Should have dialog purple background (25,10,40)`e[0m"

# Check if it's in the cache
Write-Host "`nCache check:" -ForegroundColor Yellow
$cacheKeys = $tm._cache.Keys | Where-Object { $_ -like "*background*" } | Sort-Object
Write-Host "Background-related cache keys: $($cacheKeys -join ', ')"

Write-Host "`nPress any key to launch PRAXIS with synthwave theme..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Launch with theme
./Start.ps1 -Theme "synthwave-84"