#!/usr/bin/env pwsh
Write-Host "AMBER THEME VERIFICATION" -ForegroundColor Yellow

. ./Start.ps1 -LoadOnly

$tm = $global:ServiceContainer.GetService("ThemeManager")
Write-Host "`nCurrent Theme: $($tm.GetCurrentTheme())" -ForegroundColor Cyan
Write-Host "Available Themes: $($tm.GetThemeNames() -join ', ')" -ForegroundColor Cyan

Write-Host "`nChecking all color definitions:" -ForegroundColor Yellow

$themeData = $tm.GetTheme("amber")
$allColors = @{}

# Collect all color keys
foreach ($category in $themeData.Keys) {
    if ($themeData[$category] -is [hashtable]) {
        foreach ($colorKey in $themeData[$category].Keys) {
            $fullKey = "$category.$colorKey"
            $allColors[$fullKey] = $themeData[$category][$colorKey]
        }
    }
}

# Check each color
$greyFound = $false
$blueFound = $false

foreach ($colorKey in $allColors.Keys | Sort-Object) {
    $rgb = $allColors[$colorKey]
    if ($rgb -is [array] -and $rgb.Count -eq 3) {
        $r = $rgb[0]
        $g = $rgb[1] 
        $b = $rgb[2]
        
        # Check for grey (r=g=b)
        $isGrey = ($r -eq $g -and $g -eq $b -and $r -gt 20)
        
        # Check for blue component
        $hasBlue = ($b -gt 30 -and $b -gt $r -and $b -gt $g)
        
        if ($isGrey -or $hasBlue) {
            if ($isGrey) { $greyFound = $true }
            if ($hasBlue) { $blueFound = $true }
            
            Write-Host "$colorKey : RGB($r,$g,$b)" -ForegroundColor Red -NoNewline
            if ($isGrey) { Write-Host " [GREY]" -ForegroundColor Red -NoNewline }
            if ($hasBlue) { Write-Host " [BLUE]" -ForegroundColor Red -NoNewline }
            Write-Host ""
        } else {
            Write-Host "$colorKey : RGB($r,$g,$b)" -ForegroundColor Green
        }
    }
}

Write-Host "`nSUMMARY:" -ForegroundColor Yellow
if (-not $greyFound -and -not $blueFound) {
    Write-Host "✓ ALL COLORS ARE AMBER!" -ForegroundColor Green
} else {
    if ($greyFound) { Write-Host "✗ Grey colors found!" -ForegroundColor Red }
    if ($blueFound) { Write-Host "✗ Blue colors found!" -ForegroundColor Red }
}

# Test actual rendering
Write-Host "`nTesting rendered colors:" -ForegroundColor Yellow
$menuBg = $tm.GetRgbEscape("menu.background")
$listBg = $tm.GetRgbEscape("list.background") 
$surfaceBg = $tm.GetRgbEscape("surface.background")

Write-Host "${menuBg}Menu Background$([VT]::Reset)"
Write-Host "${listBg}List Background$([VT]::Reset)"
Write-Host "${surfaceBg}Surface Background$([VT]::Reset)"