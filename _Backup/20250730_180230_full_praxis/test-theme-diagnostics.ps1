#!/usr/bin/env pwsh
# Theme diagnostic tool - traces where amber colors are lost

param(
    [switch]$FullReport = $false
)

# Load the framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

Write-Host "`n=== THEME DIAGNOSTIC TOOL ===" -ForegroundColor Yellow
Write-Host "Current theme: amber (hardcoded in ThemeManager)" -ForegroundColor Cyan

# Check ThemeManager initialization
$themeManager = $global:ServiceContainer.GetService("ThemeManager")
if (-not $themeManager) {
    Write-Host "ERROR: ThemeManager not found!" -ForegroundColor Red
    exit 1
}

Write-Host "`nTheme Manager Status:" -ForegroundColor Green
Write-Host "  Current theme: $($themeManager.GetCurrentTheme())"
Write-Host "  Available themes: $($themeManager.GetThemeNames() -join ', ')"

# Test direct color retrieval
Write-Host "`nDirect Color Tests:" -ForegroundColor Green
$testKeys = @(
    'text.primary',
    'text.heading', 
    'border.focused',
    'button.text',
    'focus.reverse.background'
)

foreach ($key in $testKeys) {
    $rgb = $themeManager.GetRGB($key)
    $ansi = $themeManager.GetColor($key)
    if ($rgb) {
        Write-Host "  $key : RGB($($rgb -join ',')) " -NoNewline
        Write-Host "███" -ForegroundColor Black -BackgroundColor ([System.ConsoleColor]::Yellow)
    } else {
        Write-Host "  $key : NULL!" -ForegroundColor Red
    }
}

# Check theme cache
Write-Host "`nTheme Cache Analysis:" -ForegroundColor Green
$cacheCount = $themeManager._cache.Count
Write-Host "  Cache entries: $cacheCount"
if ($FullReport) {
    Write-Host "  Sample entries:"
    $themeManager._cache.Keys | Select-Object -First 5 | ForEach-Object {
        Write-Host "    $_"
    }
}

# Test component color application
Write-Host "`nComponent Color Application:" -ForegroundColor Green

# Test ThemedComponent
$testComponent = [MinimalButton]::new("Test Button")
$testComponent.Initialize($global:ServiceContainer)

Write-Host "  MinimalButton theme reference: $(if ($testComponent.Theme) { 'OK' } else { 'NULL!' })"
if ($testComponent.Theme) {
    Write-Host "  Button text color: " -NoNewline
    $btnColor = $testComponent.Theme.GetColor('button.text')
    if ($btnColor) {
        Write-Host "OK (has ANSI sequence)" -ForegroundColor Green
    } else {
        Write-Host "NULL!" -ForegroundColor Red
    }
}

# Check RenderHelper
Write-Host "`nRenderHelper Analysis:" -ForegroundColor Green
[RenderHelper]::Initialize()
Write-Host "  RenderHelper initialized: OK"

# Test button rendering
$sb = [System.Text.StringBuilder]::new()
$content = [RenderHelper]::RenderButtonContent("Test", 10, $themeManager, $false)
Write-Host "  Button content rendering: $(if ($content -match '\e\[') { 'Contains ANSI codes' } else { 'NO ANSI CODES!' })"

# Find components not using theme properly
Write-Host "`nScanning for hardcoded colors..." -ForegroundColor Green
$componentsPath = "$PSScriptRoot/Components"
$screensPath = "$PSScriptRoot/Screens"

$problemFiles = @()

# Check for RGB hardcoding
Get-ChildItem -Path $componentsPath, $screensPath -Filter "*.ps1" -Recurse | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    
    # Look for hardcoded RGB values
    if ($content -match '\[VT\]::RGB\s*\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)') {
        $problemFiles += @{
            File = $_.Name
            Issue = "Hardcoded RGB values"
            Path = $_.FullName
        }
    }
    
    # Look for color fallbacks
    if ($content -match 'GetColor.*\?\?') {
        $problemFiles += @{
            File = $_.Name
            Issue = "Color fallback operator (??)"
            Path = $_.FullName
        }
    }
    
    # Look for non-themed colors
    if ($content -match '\$.*Color\s*=\s*["\'']') {
        if ($content -notmatch 'Theme\.GetColor') {
            $problemFiles += @{
                File = $_.Name  
                Issue = "Possible hardcoded color string"
                Path = $_.FullName
            }
        }
    }
}

if ($problemFiles.Count -gt 0) {
    Write-Host "`nPROBLEM FILES FOUND:" -ForegroundColor Red
    $problemFiles | ForEach-Object {
        Write-Host "  $($_.File): $($_.Issue)" -ForegroundColor Yellow
        if ($FullReport) {
            Write-Host "    Path: $($_.Path)" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  No obvious hardcoded colors found" -ForegroundColor Green
}

# Test actual rendering
Write-Host "`nLive Rendering Test:" -ForegroundColor Green
Write-Host "Creating a test dialog to check theme application..." -ForegroundColor Cyan

# Create test dialog
$dialog = [ConfirmationDialog]::new("Testing amber theme colors")
$dialog.Initialize($global:ServiceContainer)

# Check dialog theme
Write-Host "  Dialog theme reference: $(if ($dialog.Theme) { 'OK' } else { 'NULL!' })"
Write-Host "  Dialog border color: " -NoNewline
if ($dialog.Theme) {
    $borderColor = $dialog.Theme.GetColor('border.dialog')
    if ($borderColor) {
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host "NULL!" -ForegroundColor Red
    }
} else {
    Write-Host "No theme!" -ForegroundColor Red
}

Write-Host "`n=== RECOMMENDATIONS ===" -ForegroundColor Yellow

$issues = @()

# Check for theme issues
if ($themeManager.GetCurrentTheme() -ne 'amber') {
    $issues += "Theme is not set to amber!"
}

if ($problemFiles.Count -gt 0) {
    $issues += "$($problemFiles.Count) files contain hardcoded colors"
}

if ($issues.Count -eq 0) {
    Write-Host "Theme system appears to be working correctly." -ForegroundColor Green
    Write-Host "If colors are still wrong, check:" -ForegroundColor Cyan
    Write-Host "  1. Terminal color support (true color vs 256 color)" 
    Write-Host "  2. Component render caching (may need invalidation)"
    Write-Host "  3. Parent container color inheritance"
} else {
    Write-Host "Issues found:" -ForegroundColor Red
    $issues | ForEach-Object {
        Write-Host "  - $_" -ForegroundColor Yellow
    }
}

Write-Host "`nRun with -FullReport for detailed analysis" -ForegroundColor Gray
Write-Host ""