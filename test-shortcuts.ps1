#!/usr/bin/env pwsh
# Test script to verify keyboard shortcuts

param(
    [switch]$Debug
)

# Set location to script root
Set-Location $PSScriptRoot

# Run with debug flag
if ($Debug) {
    Write-Host "Running with debug output..." -ForegroundColor Yellow
    & ./Start.ps1 -Debug
} else {
    Write-Host "Starting PRAXIS to test shortcuts..." -ForegroundColor Green
    Write-Host "Test these shortcuts in ProjectsScreen:" -ForegroundColor Cyan
    Write-Host "  e - Edit selected project" -ForegroundColor Gray
    Write-Host "  d - Delete selected project" -ForegroundColor Gray
    Write-Host "  n - New project" -ForegroundColor Gray
    Write-Host ""
    Write-Host "And in TaskScreen:" -ForegroundColor Cyan
    Write-Host "  e - Edit selected task" -ForegroundColor Gray
    Write-Host "  d - Delete selected task" -ForegroundColor Gray
    Write-Host "  n - New task" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Press Enter to continue..."
    Read-Host
    
    & ./Start.ps1
}