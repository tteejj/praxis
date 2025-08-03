#!/usr/bin/env pwsh
Write-Host "Testing forced amber theme..." -ForegroundColor Yellow

. ./Start.ps1 -LoadOnly

$tm = $global:ServiceContainer.GetService("ThemeManager")
$tm.RebuildCache()

Write-Host "`nTheme: $($tm.GetCurrentTheme())" -ForegroundColor Cyan

# Test all surface colors
@("surface.background", "surface.elevated", "surface.dialog", 
  "menu.background", "list.background") | ForEach-Object {
    $rgb = $tm.GetRGB($_)
    $isGrey = ($rgb[0] -eq $rgb[1] -and $rgb[1] -eq $rgb[2] -and $rgb[0] -gt 20)
    Write-Host "$_ : RGB($($rgb -join ','))" -ForegroundColor $(if ($isGrey) {"Red"} else {"Green"})
}

Write-Host "`nRun ./Start.ps1 to test" -ForegroundColor Yellow
