#!/usr/bin/env pwsh
# Debug theme issues

# Just load the basic files we need
. ./Base/UIElement.ps1
. ./Services/ThemeManager.ps1
. ./Services/ThemeSystem.ps1
. ./Utils/ThemeBuilder.ps1
. ./Themes/ThemeSynthwave.ps1
. ./Core/VT100.ps1
. ./Core/ServiceContainer.ps1

# Create service container
$global:ServiceContainer = [ServiceContainer]::new()

# Create theme manager
$themeManager = [EnhancedThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $themeManager)

# Initialize synthwave themes
[ThemeSynthwave]::CreateSynthwave84()

# Set theme
$themeManager.SetTheme("synthwave-84")

Write-Host "`nTheme Debug Info:" -ForegroundColor Magenta
Write-Host "Current theme: $($themeManager._currentTheme)" -ForegroundColor Cyan

# Check if theme was registered
$themes = $themeManager.GetThemeNames()
Write-Host "Available themes: $($themes -join ', ')" -ForegroundColor Yellow

# Test critical colors
$testColors = @(
    'background',
    'dialog.background',
    'dialog.border',
    'border',
    'border.normal'
)

foreach ($color in $testColors) {
    $rgb = $themeManager.GetRGB($color)
    $fg = $themeManager.GetColor($color)
    $bg = $themeManager.GetBgColor($color)
    
    Write-Host "`n$color :" -ForegroundColor Green
    if ($rgb) {
        Write-Host "  RGB: R=$($rgb[0]) G=$($rgb[1]) B=$($rgb[2])"
        Write-Host "  FG: " -NoNewline
        Write-Host "$fg████`e[0m" -NoNewline
        Write-Host " (len: $($fg.Length))"
        Write-Host "  BG: " -NoNewline
        Write-Host "$bg    `e[0m" -NoNewline
        Write-Host " (len: $($bg.Length))"
    } else {
        Write-Host "  NOT FOUND" -ForegroundColor Red
    }
}

Write-Host "`n`nDirect theme data check:" -ForegroundColor Yellow
$themeData = $themeManager._themes["synthwave-84"]
if ($themeData) {
    Write-Host "Theme has $($themeData.Count) color definitions" -ForegroundColor Cyan
    
    # Show first few
    $shown = 0
    foreach ($key in $themeData.Keys | Sort-Object) {
        if ($shown -lt 10) {
            $val = $themeData[$key]
            if ($val -is [array]) {
                Write-Host "  $key : [$($val -join ', ')]"
            } else {
                Write-Host "  $key : $val"
            }
            $shown++
        }
    }
    Write-Host "  ... and $($themeData.Count - $shown) more"
} else {
    Write-Host "Theme not found!" -ForegroundColor Red
}