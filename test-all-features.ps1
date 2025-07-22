#!/usr/bin/env pwsh
# Test script for all PRAXIS features

Write-Host "PRAXIS Feature Test Guide" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tab Navigation:" -ForegroundColor Yellow
Write-Host "  - Press 1-4 to switch between tabs" -ForegroundColor White
Write-Host "  - Projects, Tasks, Dashboard, Settings" -ForegroundColor Gray
Write-Host ""
Write-Host "Task Management (Tab 2):" -ForegroundColor Yellow
Write-Host "  - n: Create new task" -ForegroundColor White
Write-Host "  - e/Enter: Edit selected task" -ForegroundColor White
Write-Host "  - d/Delete: Delete selected task" -ForegroundColor White
Write-Host "  - s: Cycle task status" -ForegroundColor White
Write-Host "  - p: Cycle task priority" -ForegroundColor White
Write-Host "  - /: Focus filter box" -ForegroundColor White
Write-Host "  - Tab: Switch between filter and list" -ForegroundColor White
Write-Host ""
Write-Host "Settings (Tab 4):" -ForegroundColor Yellow
Write-Host "  - Arrow keys to navigate categories" -ForegroundColor White
Write-Host "  - Tab to switch between category list and settings grid" -ForegroundColor White
Write-Host "  - Enter/e: Edit setting (booleans toggle)" -ForegroundColor White
Write-Host "  - r: Reset current category" -ForegroundColor White
Write-Host "  - R: Reset all settings" -ForegroundColor White
Write-Host ""
Write-Host "Global:" -ForegroundColor Yellow
Write-Host "  - /: Open command palette" -ForegroundColor White
Write-Host "  - q/Escape: Quit" -ForegroundColor White
Write-Host ""
Write-Host "Starting in 5 seconds..." -ForegroundColor Green
Start-Sleep -Seconds 5

# Run the main app
& "$PSScriptRoot/Start.ps1"