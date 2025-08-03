#!/usr/bin/env pwsh
Write-Host "VERIFYING AMBER THEME..." -ForegroundColor Yellow

. ./Start.ps1 -LoadOnly

$tm = $global:ServiceContainer.GetService("ThemeManager")
Write-Host "Current: $($tm.GetCurrentTheme())" -ForegroundColor Cyan

# Create a data grid and check its colors
$grid = [MinimalDataGrid]::new()
$grid.Initialize($global:ServiceContainer)
$grid.UpdateThemeCache()

Write-Host "`nDataGrid colors:" -ForegroundColor Yellow
Write-Host "  Header BG: $($grid._headerBg)" -ForegroundColor Cyan
Write-Host "  Row BG: $($grid._rowBg)" -ForegroundColor Cyan

# Test rendering
$rendered = $grid.OnRender()
if ($rendered -match 'surface\.background|list\.background') {
    Write-Host "`nSTILL USING THEME KEYS!" -ForegroundColor Red
}

Write-Host "`nDONE. Run ./Start.ps1" -ForegroundColor Green
