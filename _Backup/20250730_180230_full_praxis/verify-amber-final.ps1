#!/usr/bin/env pwsh
Write-Host "FINAL AMBER VERIFICATION" -ForegroundColor Yellow

. ./Start.ps1 -LoadOnly

$tm = $global:ServiceContainer.GetService("ThemeManager")
Write-Host "`nCurrent Theme: $($tm.GetCurrentTheme())" -ForegroundColor Cyan

# Check some key colors
Write-Host "`nChecking key color values:" -ForegroundColor Yellow

$colors = @(
    "menu.background",
    "menu.foreground", 
    "menu.selected.background",
    "menu.selected.foreground",
    "list.background",
    "list.foreground",
    "surface.background",
    "button.background",
    "button.foreground"
)

foreach ($colorKey in $colors) {
    $rgb = $tm.GetRGB($colorKey)
    if ($rgb) {
        $r = $rgb[0]
        $g = $rgb[1] 
        $b = $rgb[2]
        
        # Check for grey (r=g=b) or blue (b > others)
        $isGrey = ($r -eq $g -and $g -eq $b -and $r -gt 20)
        $hasBlue = ($b -gt 30 -and $b -gt $r -and $b -gt $g)
        
        if ($isGrey -or $hasBlue) {
            Write-Host "$colorKey : RGB($r,$g,$b)" -ForegroundColor Red -NoNewline
            if ($isGrey) { Write-Host " [GREY!]" -ForegroundColor Red }
            if ($hasBlue) { Write-Host " [BLUE!]" -ForegroundColor Red }
        } else {
            Write-Host "$colorKey : RGB($r,$g,$b)" -ForegroundColor Green
        }
    }
}

# Test actual color output
Write-Host "`nTesting actual color output:" -ForegroundColor Yellow
Write-Host "$($tm.GetBgColor('menu.background'))Menu Background$($tm.GetThemeReset())"
Write-Host "$($tm.GetBgColor('list.background'))List Background$($tm.GetThemeReset())"
Write-Host "$($tm.GetColor('menu.foreground'))Menu Text$($tm.GetThemeReset())"