#!/usr/bin/env pwsh

# Check what themes are actually available
Set-Location $PSScriptRoot

Write-Host "`nChecking PRAXIS themes..." -ForegroundColor Cyan

# Load minimal required files
. ./Core/ServiceContainer.ps1
. ./Services/Logger.ps1
. ./Services/EventBus.ps1
. ./Services/ThemeManager.ps1
. ./Utils/ThemeBuilder.ps1
. ./Themes/ThemeSynthwave.ps1

# Initialize
$global:ServiceContainer = [ServiceContainer]::new()
$global:Logger = [Logger]::new()
$global:ServiceContainer.RegisterService('Logger', $global:Logger)

$eventBus = [EventBus]::new()
$global:ServiceContainer.RegisterService('EventBus', $eventBus)

$themeManager = [ThemeManager]::new()

Write-Host "`nThemes available in ThemeManager:" -ForegroundColor Green
$themes = $themeManager.GetThemeNames()
foreach ($theme in $themes) {
    Write-Host "  - $theme" -ForegroundColor Yellow
}

Write-Host "`nCurrent theme:" -ForegroundColor Green
Write-Host "  $($themeManager.GetCurrentTheme())" -ForegroundColor Cyan

# Check if synthwave themes exist
Write-Host "`nCreating synthwave themes..." -ForegroundColor Green
try {
    [ThemeSynthwave]::CreateSynthwave84()
    [ThemeSynthwave]::CreateSynthwaveOutrun()
    Write-Host "  Synthwave themes created!" -ForegroundColor Green
    
    Write-Host "`nThemes after synthwave creation:" -ForegroundColor Green
    $themes = $themeManager.GetThemeNames()
    foreach ($theme in $themes) {
        Write-Host "  - $theme" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Error creating synthwave themes: $_" -ForegroundColor Red
}

# Check settings.json
Write-Host "`nSettings.json theme configuration:" -ForegroundColor Green
$settings = Get-Content "_Config/settings.json" | ConvertFrom-Json
Write-Host "  CurrentTheme: $($settings.Theme.CurrentTheme)" -ForegroundColor Yellow
Write-Host "  AvailableThemes: $($settings.Theme.AvailableThemes -join ', ')" -ForegroundColor Yellow

Write-Host "`nPress any key to exit..."
[Console]::ReadKey($true) | Out-Null