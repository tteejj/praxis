#!/usr/bin/env pwsh
# Simple test for synthwave theme fixes without loading full UI

# Load only what we need
. "$PSScriptRoot/Core/StringCache.ps1"
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Core/ServiceContainer.ps1"
. "$PSScriptRoot/Services/Logger.ps1"
. "$PSScriptRoot/Services/EventBus.ps1"
. "$PSScriptRoot/Services/ThemeManager.ps1"
. "$PSScriptRoot/Utils/ThemeBuilder.ps1"
. "$PSScriptRoot/Themes/ThemeSynthwave.ps1"

Write-Host "Testing Synthwave Theme Registration..." -ForegroundColor Cyan

# Create minimal service container
$global:ServiceContainer = [ServiceContainer]::new()
$logger = [Logger]::new()
$global:Logger = $logger
$global:ServiceContainer.Register("Logger", $logger)

# Create ThemeManager
$themeManager = [ThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $themeManager)

# Register EventBus
$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("EventBus", $eventBus)
$themeManager.SetEventBus($eventBus)

# Register synthwave themes
Write-Host "`nRegistering Synthwave themes..." -ForegroundColor Yellow
[ThemeSynthwave]::CreateSynthwave84()
[ThemeSynthwave]::CreateSynthwaveOutrun()

# Check registration
$themes = $themeManager.GetThemeNames()
Write-Host "`nRegistered themes:" -ForegroundColor Green
foreach ($theme in $themes) {
    Write-Host "  - $theme" -ForegroundColor DarkGray
}

# Test synthwave-84
Write-Host "`nTesting synthwave-84 theme..." -ForegroundColor Yellow
$themeManager.SetTheme('synthwave-84')

$testColors = @('primary', 'secondary', 'background', 'border', 'gradient.border.start', 'gradient.border.end')
foreach ($color in $testColors) {
    $rgb = $themeManager.GetRGB($color)
    if ($rgb) {
        $ansi = $themeManager.GetColor($color)
        Write-Host -NoNewline "  $color : " -ForegroundColor DarkGray
        Write-Host -NoNewline "$ansi██████$([VT]::Reset()) " 
        Write-Host "RGB($($rgb[0]),$($rgb[1]),$($rgb[2]))" -ForegroundColor DarkGray
    } else {
        Write-Host "  $color : NOT FOUND" -ForegroundColor Red
    }
}

# Test synthwave-outrun
Write-Host "`nTesting synthwave-outrun theme..." -ForegroundColor Yellow
$themeManager.SetTheme('synthwave-outrun')

foreach ($color in $testColors) {
    $rgb = $themeManager.GetRGB($color)
    if ($rgb) {
        $ansi = $themeManager.GetColor($color)
        Write-Host -NoNewline "  $color : " -ForegroundColor DarkGray
        Write-Host -NoNewline "$ansi██████$([VT]::Reset()) "
        Write-Host "RGB($($rgb[0]),$($rgb[1]),$($rgb[2]))" -ForegroundColor DarkGray
    } else {
        Write-Host "  $color : NOT FOUND" -ForegroundColor Red
    }
}

# Test gradients
Write-Host "`nTesting gradient generation..." -ForegroundColor Yellow
$gradient = $themeManager.GetGradient('gradient.border.start', 'gradient.border.end', 10)
Write-Host -NoNewline "  Border gradient: "
foreach ($color in $gradient) {
    Write-Host -NoNewline "$color█$([VT]::Reset())"
}
Write-Host ""

Write-Host "`nAll tests completed!" -ForegroundColor Green