#!/usr/bin/env pwsh
# Quick test to verify amber theme

Write-Host "Testing amber theme..." -ForegroundColor Yellow

# Load framework
. ./Start.ps1 -LoadOnly

# Get theme manager and verify
$tm = $global:ServiceContainer.GetService("ThemeManager")
$current = $tm.GetCurrentTheme()
Write-Host "Current theme: $current" -ForegroundColor Cyan

# Test key colors
$testColors = @{
    "menu.background" = "Menu BG"
    "list.background" = "List BG"  
    "button.background" = "Button BG"
    "surface.background" = "Surface BG"
    "text.primary" = "Text"
    "border.normal" = "Border"
}

Write-Host "`nColor values:" -ForegroundColor Yellow
foreach ($key in $testColors.Keys) {
    $rgb = $tm.GetRGB($key)
    if ($rgb) {
        $hasGrey = ($rgb[0] -eq $rgb[1] -and $rgb[1] -eq $rgb[2])
        $hasBlue = ($rgb[2] -gt 0 -and $rgb[2] -gt 30)
        
        $status = "✓ AMBER"
        if ($hasGrey) { $status = "✗ GREY!" }
        elseif ($hasBlue) { $status = "✗ HAS BLUE!" }
        
        $color = if ($status -eq "✓ AMBER") { "Green" } else { "Red" }
        Write-Host "$($testColors[$key].PadRight(12)): RGB($($rgb[0]),$($rgb[1]),$($rgb[2])) $status" -ForegroundColor $color
    }
}

Write-Host "`nTheme cache:" -ForegroundColor Yellow
Write-Host "Cache entries: $($tm._cache.Count)" -ForegroundColor Cyan

Write-Host "`nNow run ./Start.ps1 to see the application" -ForegroundColor Yellow