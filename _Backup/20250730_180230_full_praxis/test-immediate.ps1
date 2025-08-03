#!/usr/bin/env pwsh
# Test amber theme is working

Write-Host "Testing amber theme application..." -ForegroundColor Yellow

# Clear PowerShell type cache
[System.Management.Automation.PSInvalidCastException]
Remove-TypeData * -ErrorAction SilentlyContinue

# Load framework
. ./Start.ps1 -LoadOnly

# Force theme manager to amber
$tm = $global:ServiceContainer.GetService("ThemeManager")
$tm.SetTheme("amber")
$tm.RebuildCache()

# Test colors
Write-Host "`nTheme colors:" -ForegroundColor Yellow
$testKeys = @("menu.background", "list.background", "button.background", "surface.background")
foreach ($key in $testKeys) {
    $rgb = $tm.GetRGB($key)
    Write-Host "$key = RGB($($rgb -join ', '))"
}

Write-Host "`nIf any color shows grey (equal RGB values), the theme is NOT applied correctly!" -ForegroundColor Red
