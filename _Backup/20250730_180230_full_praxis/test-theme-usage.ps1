#!/usr/bin/env pwsh
# Test that themes are being used properly

Write-Host "THEME USAGE TEST" -ForegroundColor Cyan
Write-Host "================" -ForegroundColor Cyan
Write-Host ""

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

# Get theme manager
$themeManager = $global:ServiceContainer.GetService("ThemeManager")
$currentTheme = $themeManager.GetCurrentTheme()

Write-Host "Current Theme Colors:" -ForegroundColor Yellow
Write-Host "--------------------" -ForegroundColor Yellow

# Check key surface colors
$surfaceBg = $themeManager.GetRGB("surface.background")
Write-Host "surface.background: RGB($($surfaceBg -join ','))" -ForegroundColor Green

$menuBg = $themeManager.GetRGB("menu.background")
Write-Host "menu.background: RGB($($menuBg -join ','))" -ForegroundColor Green

$listBg = $themeManager.GetRGB("list.background")
Write-Host "list.background: RGB($($listBg -join ','))" -ForegroundColor Green

Write-Host ""
Write-Host "Checking for hardcoded colors..." -ForegroundColor Yellow

# Search for hardcoded RGB values
$hardcodedFiles = @()
Get-ChildItem -Path $PSScriptRoot -Include "*.ps1" -Recurse | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match '\[VT\]::RGBBG?\([0-9]+,\s*[0-9]+,\s*[0-9]+\)') {
        $hardcodedFiles += $_.FullName
    }
}

if ($hardcodedFiles.Count -gt 0) {
    Write-Host "⚠️  Found hardcoded colors in:" -ForegroundColor Red
    $hardcodedFiles | ForEach-Object {
        Write-Host "   $_" -ForegroundColor Red
    }
} else {
    Write-Host "✓ No hardcoded colors found!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Theme validation:" -ForegroundColor Yellow
Write-Host "----------------" -ForegroundColor Yellow

# Create a test screen
$testScreen = [ProjectsScreen]::new()
$testScreen.Initialize($global:ServiceContainer)

Write-Host "ProjectsScreen DrawBackground: $($testScreen.DrawBackground)" -ForegroundColor Cyan
Write-Host "ProjectsScreen background color set: $($testScreen._cachedBgColor -ne '')" -ForegroundColor Cyan

Write-Host ""
Write-Host "Press any key to run the app and verify visually..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Run the app
& "$PSScriptRoot/Start.ps1"