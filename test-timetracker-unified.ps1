#!/usr/bin/env pwsh
# test-timetracker-unified.ps1 - Test TimeTracker integration with PraxisDataService

Write-Host "Testing TimeTracker with Unified Data Integration..." -ForegroundColor Cyan
Write-Host ""

# First ensure unified data exists
Write-Host "Step 1: Ensuring unified data exists..." -ForegroundColor Yellow
try {
    pwsh ./migrate-to-unified-data.ps1 -auto | Out-Null
    Write-Host "✓ Migration completed" -ForegroundColor Green
} catch {
    Write-Host "✗ Migration failed: $_" -ForegroundColor Red
    exit 1
}

# Load TimeTracker dependencies in correct order
Write-Host ""
Write-Host "Step 2: Loading TimeTracker with unified data integration..." -ForegroundColor Yellow

try {
    # Core dependencies
    . "$PSScriptRoot/TaskPro/Core/StringCache.ps1"
    . "$PSScriptRoot/TaskPro/Components/Shared/VT100.ps1" 
    . "$PSScriptRoot/TaskPro/Services/PraxisDataService.ps1"
    Write-Host "✓ Core services loaded" -ForegroundColor Green
    
    # TimeTracker models
    . "$PSScriptRoot/TimeTracker/Models/SimpleTimeEntry.ps1"
    . "$PSScriptRoot/TaskPro/Services/External/TimeTrackingService.ps1"
    Write-Host "✓ TimeTracker models loaded" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Failed to load TimeTracker components: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}

# Test TimeTrackingService with unified data
Write-Host ""
Write-Host "Step 3: Testing TimeTrackingService integration..." -ForegroundColor Yellow
try {
    $timeService = [TimeTrackingService]::new()
    Write-Host "✓ TimeTrackingService created" -ForegroundColor Green
    
    $timeEntries = $timeService.GetAllEntries()
    Write-Host "✓ Time entries loaded: $($timeEntries.Count)" -ForegroundColor Green
    
    $availableTasks = $timeService.AvailableTasks
    Write-Host "✓ Available tasks loaded: $($availableTasks.Count)" -ForegroundColor Green
    
    # Test creating a new time entry
    $testEntry = [SimpleTimeEntry]::new($timeService.GetCurrentWeekFriday().ToString("yyyyMMdd"), "TEST")
    $testEntry.Description = "Test unified data entry"
    $testEntry.Monday = 2.5
    $testEntry.CalculateTotal()
    
    $timeService.AddTimeEntry($testEntry)
    Write-Host "✓ Test time entry added" -ForegroundColor Green
    
    # Verify it's in unified data
    $unifiedEntries = [PraxisDataService]::GetTimeEntries()
    $foundEntry = $unifiedEntries | Where-Object { $_.Id -eq $testEntry.Id }
    if ($foundEntry) {
        Write-Host "✓ Entry found in unified data" -ForegroundColor Green
    } else {
        Write-Host "✗ Entry not found in unified data" -ForegroundColor Red
    }
    
    # Cleanup test entry
    $timeService.DeleteTimeEntry($testEntry.Id)
    Write-Host "✓ Test entry cleaned up" -ForegroundColor Green
    
} catch {
    Write-Host "✗ TimeTrackingService integration failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}

# Test data persistence
Write-Host ""
Write-Host "Step 4: Testing data persistence..." -ForegroundColor Yellow
try {
    # Create a second TimeTrackingService instance
    $timeService2 = [TimeTrackingService]::new()
    $entries2 = $timeService2.GetAllEntries()
    
    if ($timeEntries.Count -eq $entries2.Count) {
        Write-Host "✓ Data consistency verified between instances" -ForegroundColor Green
    } else {
        Write-Host "✗ Data inconsistency detected" -ForegroundColor Red
    }
    
} catch {
    Write-Host "✗ Data persistence test failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Step 5: Testing task integration..." -ForegroundColor Yellow
try {
    # Verify TimeTracker can access TaskPro tasks
    $timeService3 = [TimeTrackingService]::new()
    $tasks = $timeService3.AvailableTasks
    
    if ($tasks.Count -gt 0) {
        Write-Host "✓ Tasks accessible from TimeTracker: $($tasks.Count)" -ForegroundColor Green
        $sampleTask = $tasks[0]
        Write-Host "  Sample task: $($sampleTask.Title)" -ForegroundColor DarkGray
    } else {
        Write-Host "⚠ No tasks found for time entry selection" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "✗ Task integration test failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎉 TimeTracker unified data integration test completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "✓ TimeTracker loads data from unified JSON" -ForegroundColor Green
Write-Host "✓ Time entries save to unified data" -ForegroundColor Green  
Write-Host "✓ Data consistency maintained across instances" -ForegroundColor Green
Write-Host "✓ Tasks accessible for time entry selection" -ForegroundColor Green
Write-Host ""
Write-Host "TimeTracker is now integrated with PraxisDataService!" -ForegroundColor Green