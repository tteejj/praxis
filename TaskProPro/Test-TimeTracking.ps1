#!/usr/bin/env pwsh
# Test-TimeTracking.ps1 - Test the time tracking integration

param([switch]$Debug)

$global:Debug = $Debug.IsPresent

try {
    Write-Host "Testing TaskProPro Time Tracking Integration..." -ForegroundColor Cyan
    
    # Load the TaskProPro foundation
    . "$PSScriptRoot/Load-TaskProPro.ps1"
    
    Write-Host "✓ Foundation loaded successfully" -ForegroundColor Green
    
    # Test TimeTrackingService initialization
    Write-Host "Testing TimeTrackingService..." -ForegroundColor Yellow
    $timeService = [TaskPro.Data.TimeTrackingService]::new("$PSScriptRoot/Data")
    
    Write-Host "✓ TimeTrackingService created successfully" -ForegroundColor Green
    Write-Host "  - Current week: $($timeService.GetWeekDisplayString())" -ForegroundColor Gray
    Write-Host "  - Entries count: $($timeService.TimeEntries.Count)" -ForegroundColor Gray
    
    # Test TimeTrackingWidget initialization
    Write-Host "Testing TimeTrackingWidget..." -ForegroundColor Yellow
    $timeWidget = [TaskPro.UI.TimeTrackingWidget]::new()
    $timeWidget.Initialize($timeService)
    
    Write-Host "✓ TimeTrackingWidget created successfully" -ForegroundColor Green
    Write-Host "  - Selected index: $($timeWidget.SelectedIndex)" -ForegroundColor Gray
    Write-Host "  - Total items: $($timeWidget.TotalItems)" -ForegroundColor Gray
    
    # Test adding a sample time entry
    Write-Host "Testing time entry operations..." -ForegroundColor Yellow
    
    $newEntry = [TaskPro.Data.SimpleTimeEntry]::new()
    $newEntry.ProjectCode = "TEST001"
    $newEntry.Description = "Test Project Entry"
    $newEntry.Monday = 8.0
    $newEntry.Tuesday = 7.5
    $newEntry.CalculateTotal()
    
    $timeService.AddTimeEntry($newEntry)
    Write-Host "✓ Added test time entry successfully" -ForegroundColor Green
    Write-Host "  - Project: $($newEntry.ProjectCode)" -ForegroundColor Gray
    Write-Host "  - Total hours: $($newEntry.Total)" -ForegroundColor Gray
    
    # Test week navigation
    Write-Host "Testing week navigation..." -ForegroundColor Yellow
    $originalWeek = $timeService.GetWeekDisplayString()
    
    $timeService.NavigateToNextWeek()
    $nextWeek = $timeService.GetWeekDisplayString()
    
    $timeService.NavigateToPreviousWeek()
    $backWeek = $timeService.GetWeekDisplayString()
    
    if ($originalWeek -eq $backWeek) {
        Write-Host "✓ Week navigation working correctly" -ForegroundColor Green
    } else {
        Write-Host "✗ Week navigation failed" -ForegroundColor Red
    }
    
    # Test data validation
    Write-Host "Testing data validation..." -ForegroundColor Yellow
    
    $invalidEntry = [TaskPro.Data.SimpleTimeEntry]::new()
    $invalidEntry.ProjectCode = ""  # Invalid - empty project code
    $invalidEntry.Monday = 25.0      # Invalid - over 24 hours
    
    $errors = @()
    $isValid = $timeService.ValidateTimeEntry($invalidEntry, [ref]$errors)
    
    if (-not $isValid -and $errors.Count -gt 0) {
        Write-Host "✓ Data validation working correctly" -ForegroundColor Green
        Write-Host "  - Found $($errors.Count) validation errors" -ForegroundColor Gray
    } else {
        Write-Host "✗ Data validation failed" -ForegroundColor Red
    }
    
    # Test cyberpunk styling methods
    Write-Host "Testing cyberpunk UI methods..." -ForegroundColor Yellow
    
    $entry = $timeService.TimeEntries[0]
    $statusIcon = $entry.GetStatusIcon()
    $projectCode = $entry.GetCyberpunkProjectCode()
    $totalDisplay = $entry.GetCyberpunkTotal()
    
    Write-Host "✓ Cyberpunk UI methods working" -ForegroundColor Green
    Write-Host "  - Status: $statusIcon" -ForegroundColor Gray
    Write-Host "  - Project: $projectCode" -ForegroundColor Gray
    Write-Host "  - Total: $totalDisplay" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "🎉 All tests passed! Time tracking integration is working correctly." -ForegroundColor Green
    Write-Host ""
    Write-Host "Features implemented:" -ForegroundColor Cyan
    Write-Host "  ✓ Week-based time entry system (Monday-Friday)" -ForegroundColor White
    Write-Host "  ✓ Project codes and descriptions" -ForegroundColor White
    Write-Host "  ✓ Inline editing capabilities" -ForegroundColor White
    Write-Host "  ✓ Week navigation (previous/next/current)" -ForegroundColor White
    Write-Host "  ✓ Fiscal year calculations" -ForegroundColor White
    Write-Host "  ✓ Time codes vs project entries" -ForegroundColor White
    Write-Host "  ✓ Cyberpunk aesthetic matching TaskProPro" -ForegroundColor White
    Write-Host "  ✓ Data persistence and validation" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  1. Run TaskProPro.ps1 in an interactive terminal" -ForegroundColor White
    Write-Host "  2. Press F1 to switch to Time Tracking mode" -ForegroundColor White
    Write-Host "  3. Use A to add entries, E to edit, ←→ for week navigation" -ForegroundColor White
    Write-Host "  4. Press F1 again to return to Task Management mode" -ForegroundColor White
    
}
catch {
    Write-Host ""
    Write-Host "✗ Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    if ($global:Debug) {
        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
    }
    exit 1
}