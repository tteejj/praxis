#!/usr/bin/env pwsh
# Test-TimeTrackingIntegration.ps1 - Quick integration verification

Write-Host "Testing TaskProPro Time Tracking Integration..." -ForegroundColor Cyan

try {
    # Test C# compilation by loading the main app components
    . "$PSScriptRoot/Load-TaskProPro.ps1"
    
    Write-Host "✓ All C# components compiled successfully" -ForegroundColor Green
    
    # Test basic service initialization
    $timeService = [TaskPro.Data.TimeTrackingService]::new("$PSScriptRoot/Data")
    Write-Host "✓ TimeTrackingService initialized successfully" -ForegroundColor Green
    
    # Test widget initialization  
    $timeWidget = [TaskPro.UI.TimeTrackingWidget]::new()
    $timeWidget.Initialize($timeService)
    Write-Host "✓ TimeTrackingWidget initialized successfully" -ForegroundColor Green
    
    # Test basic functionality
    $entries = $timeService.GetCurrentWeekEntries()
    Write-Host "✓ Current week entries: $($entries.Count)" -ForegroundColor Green
    
    $weekDisplay = $timeService.GetWeekDisplayString()
    Write-Host "✓ Week display: $weekDisplay" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "🎉 Time Tracking Integration Test PASSED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Ready to use:" -ForegroundColor Cyan
    Write-Host "  1. Run ./TaskProPro.ps1 in an interactive terminal" -ForegroundColor White
    Write-Host "  2. Press F1 to switch to Time Tracking mode" -ForegroundColor White
    Write-Host "  3. Use E=Edit, A=Add, D=Delete, ←→=Week navigation" -ForegroundColor White
    Write-Host "  4. Press F1 again to return to Task Management" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host "✗ Integration test failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.InnerException) {
        Write-Host "Inner: $($_.Exception.InnerException.Message)" -ForegroundColor Yellow
    }
    exit 1
}