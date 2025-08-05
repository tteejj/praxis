#!/usr/bin/env pwsh
# test-f2-appmanager.ps1 - Test AppManager loading directly

Write-Host "Testing AppManager CommandLibrary loading..." -ForegroundColor Cyan

try {
    # Load required dependencies in the same order as SimpleTaskPro
    . "./TaskPro/Core/StringCache.ps1"  # Load StringCache first
    . "./TaskPro/Components/Shared/VT100.ps1"
    . "./TaskPro/Services/PraxisDataService.ps1"
    . "./TaskPro/Services/AppManager.ps1"
    
    # Initialize AppManager
    $basePath = Join-Path (Get-Location) "TaskPro"
    [AppManager]::Initialize($basePath)
    
    Write-Host "AppManager initialized successfully" -ForegroundColor Green
    
    # Test getting CommandLibrary screen (this is what F2 does)
    Write-Host "Attempting to get CommandLibrary screen..." -ForegroundColor Yellow
    
    $screen = [AppManager]::GetScreen("CommandLibrary")
    
    if ($screen -ne $null) {
        Write-Host "✓ CommandLibrary screen loaded successfully!" -ForegroundColor Green
        Write-Host "Screen type: $($screen.GetType().Name)" -ForegroundColor DarkGray
    } else {
        Write-Host "✗ Failed to load CommandLibrary screen" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Exception type: $($_.Exception.GetType().FullName)" -ForegroundColor DarkGray
    Write-Host "Stack trace:" -ForegroundColor DarkGray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}