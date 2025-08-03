#!/usr/bin/env pwsh
# Test the proper amber theme fix

Write-Host "Testing PROPER amber theme fix..." -ForegroundColor Yellow

. ./Start.ps1 -LoadOnly

# Get theme manager
$tm = $global:ServiceContainer.GetService("ThemeManager")
Write-Host "Current theme: $($tm.GetCurrentTheme())" -ForegroundColor Cyan

# Test data grid theme propagation
Write-Host "`nTesting DataGrid theme propagation:" -ForegroundColor Yellow
$grid = [MinimalDataGrid]::new()
$grid.Initialize($global:ServiceContainer)

Write-Host "  DataGrid has Theme: $($grid.Theme -ne $null)" -ForegroundColor Cyan
Write-Host "  Colors cached: $($grid._colors.Count)" -ForegroundColor Cyan

if ($grid._colors.headerBg) {
    Write-Host "  Header BG color set: YES" -ForegroundColor Green
} else {
    Write-Host "  Header BG color set: NO" -ForegroundColor Red
}

# Test screen theme propagation
Write-Host "`nTesting Screen theme propagation:" -ForegroundColor Yellow
$screen = [ProjectsScreen]::new()
$screen.Initialize($global:ServiceContainer)

Write-Host "  Screen has Theme: $($screen.Theme -ne $null)" -ForegroundColor Cyan

# Check if UIElement has PropagateTheme
$uiElement = [UIElement]::new()
if ($uiElement.PSObject.Methods['PropagateTheme']) {
    Write-Host "  UIElement.PropagateTheme: EXISTS" -ForegroundColor Green
} else {
    Write-Host "  UIElement.PropagateTheme: MISSING" -ForegroundColor Red
}

Write-Host "`n✅ Test complete. Run ./Start.ps1 to see amber theme!" -ForegroundColor Green