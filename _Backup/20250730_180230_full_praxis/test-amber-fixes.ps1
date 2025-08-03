#!/usr/bin/env pwsh
# Test amber theme and dialog rendering

. ./Start.ps1 -LoadOnly

# Check theme
$themeManager = $global:ServiceContainer.GetService("ThemeManager")
$currentTheme = $themeManager.GetCurrentTheme()
Write-Host "`nCurrent theme: $currentTheme" -ForegroundColor Yellow

# Test some color values
Write-Host "`nTesting amber theme colors:" -ForegroundColor Yellow
$testColors = @(
    "text.primary",
    "menu.background", 
    "menu.text",
    "menu.background.selected",
    "border.normal",
    "surface.background"
)

foreach ($colorKey in $testColors) {
    $rgb = $themeManager.GetRGB($colorKey)
    if ($rgb) {
        $r = $rgb[0]; $g = $rgb[1]; $b = $rgb[2]
        $isAmber = ($r -gt 0 -and $g -gt 0 -and $b -eq 0) -or 
                   ($r -gt 150 -and $g -gt 100 -and $b -lt 30)
        $status = if ($isAmber) { "✓ AMBER" } else { "✗ NOT AMBER" }
        Write-Host "  $colorKey : RGB($r, $g, $b) - $status" -ForegroundColor $(if ($isAmber) {"Green"} else {"Red"})
    }
}

# Test dialog
Write-Host "`nTesting dialog layout..." -ForegroundColor Yellow
$dialog = [NewProjectDialog]::new()
Write-Host "  Dialog padding: $($dialog.DialogPadding)" -ForegroundColor Cyan
Write-Host "  Button spacing: $($dialog.ButtonSpacing)" -ForegroundColor Cyan
Write-Host "  Button height: $($dialog.ButtonHeight)" -ForegroundColor Cyan
