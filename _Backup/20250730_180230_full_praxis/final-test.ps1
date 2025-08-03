#!/usr/bin/env pwsh
Write-Host "FINAL AMBER TEST" -ForegroundColor Yellow

. ./Start.ps1 -LoadOnly

$tm = $global:ServiceContainer.GetService("ThemeManager")
Write-Host "Current: $($tm.GetCurrentTheme())" -ForegroundColor Cyan
Write-Host "Available: $($tm.GetThemeNames() -join ', ')" -ForegroundColor Cyan

# Force rebuild cache
$tm.RebuildCache()

# Test a color
$menuBg = $tm.GetRGB("menu.background")
Write-Host "Menu BG: RGB($($menuBg -join ','))" -ForegroundColor $(if ($menuBg[0] -gt 0 -and $menuBg[2] -eq 0) {"Green"} else {"Red"})

Write-Host "`nRun ./Start.ps1" -ForegroundColor Yellow
