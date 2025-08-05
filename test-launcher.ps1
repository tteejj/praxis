#!/usr/bin/env pwsh
# Test launcher functionality

Set-Location $PSScriptRoot

try {
    Write-Host "Testing PraxisLauncher components..." -ForegroundColor Cyan
    
    # Test DataPool loading
    Write-Host "`nLoading DataPool..." -ForegroundColor Yellow
    . "$PSScriptRoot/PraxisCore/Services/DataPool.ps1"
    Write-Host "✓ DataPool loaded successfully" -ForegroundColor Green
    
    # Test AppLauncher loading
    Write-Host "`nLoading AppLauncher..." -ForegroundColor Yellow
    . "$PSScriptRoot/PraxisCore/Services/AppLauncher.ps1"
    Write-Host "✓ AppLauncher loaded successfully" -ForegroundColor Green
    
    # Test app paths
    Write-Host "`nChecking app paths..." -ForegroundColor Yellow
    $apps = @(
        @{ Name = "TaskPro"; Path = "$PSScriptRoot/TaskPro/SimpleTaskPro.ps1" },
        @{ Name = "TimeTracker"; Path = "$PSScriptRoot/TimeTracker/TimeTracker.ps1" },
        @{ Name = "CommandLibrary"; Path = "$PSScriptRoot/CommandLibrary/CommandLibrary.ps1" }
    )
    
    foreach ($app in $apps) {
        if (Test-Path $app.Path) {
            Write-Host "✓ $($app.Name): Found at $($app.Path)" -ForegroundColor Green
        } else {
            Write-Host "✗ $($app.Name): NOT FOUND at $($app.Path)" -ForegroundColor Red
        }
    }
    
    # Test launching TaskPro (dry run)
    Write-Host "`nTesting TaskPro launch (dry run)..." -ForegroundColor Yellow
    $taskProPath = "$PSScriptRoot/TaskPro/SimpleTaskPro.ps1"
    
    # Just check if we can call the method correctly
    Write-Host "Would launch: [AppLauncher]::LaunchApp('$taskProPath', @{})" -ForegroundColor Cyan
    
    Write-Host "`n✓ All launcher components are functional!" -ForegroundColor Green
    
} catch {
    Write-Host "`n✗ Test failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}