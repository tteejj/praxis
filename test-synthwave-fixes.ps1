#!/usr/bin/env pwsh
# Test script to verify Synthwave theme fixes and improvements

param(
    [switch]$TestGradient
)

# Load the framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

Write-Host "`nTesting Synthwave Theme Fixes..." -ForegroundColor Cyan

# Test 1: Verify themes are registered
Write-Host "`n1. Checking theme registration..." -ForegroundColor Yellow
$themeManager = $global:ServiceContainer.GetService('ThemeManager')
$themes = $themeManager.GetThemeNames()

$synthwaveThemes = @('synthwave-84', 'synthwave-outrun')
foreach ($theme in $synthwaveThemes) {
    if ($themes -contains $theme) {
        Write-Host "  ✓ $theme registered" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $theme NOT registered" -ForegroundColor Red
    }
}

# Test 2: Apply synthwave-84 theme
Write-Host "`n2. Applying synthwave-84 theme..." -ForegroundColor Yellow
try {
    $themeManager.SetTheme('synthwave-84')
    Write-Host "  ✓ Theme applied successfully" -ForegroundColor Green
    
    # Check some key colors
    $primaryColor = $themeManager.GetRGB('primary')
    if ($primaryColor[0] -eq 255 -and $primaryColor[1] -eq 0 -and $primaryColor[2] -eq 144) {
        Write-Host "  ✓ Primary color correct (Hot Pink)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Primary color incorrect" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Error applying theme: $_" -ForegroundColor Red
}

# Test 3: Check gradient support
Write-Host "`n3. Testing gradient support..." -ForegroundColor Yellow
try {
    $gradient = $themeManager.GetGradient('gradient.border.start', 'gradient.border.end', 5)
    if ($gradient.Count -eq 5) {
        Write-Host "  ✓ Gradient generation works ($($gradient.Count) steps)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Gradient generation failed" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Error generating gradient: $_" -ForegroundColor Red
}

# Test 4: Test synthwave-outrun theme (which uses AutoGenerateTextColors)
Write-Host "`n4. Testing synthwave-outrun theme..." -ForegroundColor Yellow
try {
    $themeManager.SetTheme('synthwave-outrun')
    Write-Host "  ✓ synthwave-outrun applied successfully" -ForegroundColor Green
    
    # Check that all required colors are present
    $requiredColors = @('primary', 'secondary', 'background', 'border', 'button.background')
    $allPresent = $true
    foreach ($color in $requiredColors) {
        $rgb = $themeManager.GetRGB($color)
        if (-not $rgb) {
            Write-Host "  ✗ Missing color: $color" -ForegroundColor Red
            $allPresent = $false
        }
    }
    if ($allPresent) {
        Write-Host "  ✓ All required colors present" -ForegroundColor Green
    }
} catch {
    Write-Host "  ✗ Error with synthwave-outrun: $_" -ForegroundColor Red
}

# Test 5: Test gradient button if requested
if ($TestGradient) {
    Write-Host "`n5. Testing GradientButton component..." -ForegroundColor Yellow
    try {
        # Set synthwave theme for best effect
        $themeManager.SetTheme('synthwave-84')
        
        # Create gradient demo screen
        $demoScreen = [GradientDemoScreen]::new()
        $global:ScreenManager.Push($demoScreen)
        
        Write-Host "  ✓ GradientButton demo launched" -ForegroundColor Green
        Write-Host "`n  Press ESC to exit demo" -ForegroundColor DarkGray
        
        # Run the screen manager
        $global:ScreenManager.Run()
    } catch {
        Write-Host "  ✗ Error with GradientButton: $_" -ForegroundColor Red
    }
} else {
    Write-Host "`nSkipping gradient demo. Use -TestGradient to test." -ForegroundColor DarkGray
}

Write-Host "`nAll tests completed!" -ForegroundColor Green