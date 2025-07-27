#!/usr/bin/env pwsh
# Test script to verify synthwave theme rendering issues

# Load the framework
. ./Start.ps1 -LoadOnly

Write-Host "`nTesting Synthwave Theme Rendering" -ForegroundColor Magenta
Write-Host "=================================" -ForegroundColor Cyan

# Get services
$themeManager = $global:ServiceContainer.GetService('ThemeManager')
$themeManager.SetTheme('synthwave-84')

Write-Host "`nChecking theme color definitions:" -ForegroundColor Yellow

# Check critical colors
$criticalColors = @(
    'background',
    'dialog.background', 
    'dialog.border',
    'border',
    'border.normal',
    'border.focused'
)

foreach ($colorKey in $criticalColors) {
    $color = $themeManager.GetColor($colorKey)
    $bgColor = $themeManager.GetBgColor($colorKey)
    $rgb = $themeManager.GetRGB($colorKey)
    
    Write-Host "`n$colorKey :" -ForegroundColor Green
    Write-Host "  Foreground: " -NoNewline
    if ($color) {
        Write-Host "$color████[0m" -NoNewline
        Write-Host " (len: $($color.Length))"
    } else {
        Write-Host "[EMPTY]" -ForegroundColor Red
    }
    
    Write-Host "  Background: " -NoNewline
    if ($bgColor) {
        Write-Host "$bgColor    [0m" -NoNewline
        Write-Host " (len: $($bgColor.Length))"
    } else {
        Write-Host "[EMPTY]" -ForegroundColor Red
    }
    
    if ($rgb) {
        Write-Host "  RGB: R=$($rgb[0]) G=$($rgb[1]) B=$($rgb[2])"
    } else {
        Write-Host "  RGB: [NOT FOUND]" -ForegroundColor Red
    }
}

Write-Host "`n`nRendering test dialog background:" -ForegroundColor Yellow
$dialogBg = $themeManager.GetBgColor("dialog.background")
$mainBg = $themeManager.GetBgColor("background")

Write-Host "`nDialog background color string: '$dialogBg'" -ForegroundColor Cyan
Write-Host "Main background color string: '$mainBg'" -ForegroundColor Cyan

# Test rendering
Write-Host "`nTest area with dialog background:" -ForegroundColor Green
Write-Host "${dialogBg}This should have deep purple background    [0m"

Write-Host "`nTest area with main background:" -ForegroundColor Green  
Write-Host "${mainBg}This should have deep purple-black background    [0m"

Write-Host "`nPossible Issues:" -ForegroundColor Red
Write-Host "1. If you see grey backgrounds above, the color escape sequences are not being applied"
Write-Host "2. Check if your terminal supports true color (24-bit RGB)"
Write-Host "3. The synthwave background should be RGB(15,0,25) - very dark purple"

Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")