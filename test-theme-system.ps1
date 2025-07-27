#!/usr/bin/env pwsh
# Test the enhanced theme system

# Load the framework
. ./Start.ps1 -LoadOnly

Write-Host "`nTesting Enhanced Theme System..." -ForegroundColor Cyan

# Get the theme manager
$themeManager = $global:ServiceContainer.GetService('ThemeManager')

if ($themeManager -is [EnhancedThemeManager]) {
    Write-Host "✓ EnhancedThemeManager is loaded" -ForegroundColor Green
    
    # Test semantic colors
    Write-Host "`nSemantic colors available:" -ForegroundColor Yellow
    [ThemeSystem]::SemanticTokens.Keys | ForEach-Object {
        Write-Host "  - $_" -ForegroundColor Gray
    }
    
    # Test current theme
    $currentTheme = $themeManager.GetCurrentTheme()
    Write-Host "`nCurrent theme: $currentTheme" -ForegroundColor Yellow
    
    # Test getting semantic colors
    Write-Host "`nTesting semantic color retrieval:" -ForegroundColor Yellow
    @("primary", "background", "surface", "error") | ForEach-Object {
        $color = $themeManager.GetColor($_)
        if ($color) {
            Write-Host "  $_ : $color" -NoNewline
            Write-Host " SAMPLE" -ForegroundColor White -BackgroundColor Black
        }
    }
    
    # Test theme builder
    Write-Host "`nTesting ThemeBuilder:" -ForegroundColor Yellow
    try {
        [ThemeBuilder]::new("test-theme").
            BasedOn("dark").
            WithPrimary(100, 200, 255).
            WithBackground(20, 20, 20).
            AutoGenerateTextColors().
            Build()
        Write-Host "✓ Theme builder works" -ForegroundColor Green
    } catch {
        Write-Host "✗ Theme builder failed: $_" -ForegroundColor Red
    }
    
    # Test accessibility validation
    Write-Host "`nTesting accessibility validation:" -ForegroundColor Yellow
    $results = $themeManager.ValidateAccessibility()
    Write-Host "  Passed: $($results.Passed.Count)" -ForegroundColor Green
    Write-Host "  Warnings: $($results.Warnings.Count)" -ForegroundColor Yellow
    Write-Host "  Failed: $($results.Failed.Count)" -ForegroundColor Red
    
} else {
    Write-Host "✗ EnhancedThemeManager is NOT loaded" -ForegroundColor Red
    Write-Host "  Theme manager type: $($themeManager.GetType().Name)" -ForegroundColor Gray
}

Write-Host "`nTheme system test complete." -ForegroundColor Cyan