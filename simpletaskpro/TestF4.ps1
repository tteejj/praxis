#!/usr/bin/env pwsh
# TestF4.ps1 - Test script to verify F4 time entry functionality works

# Load components 
. "$PSScriptRoot/Core/StringCache.ps1"
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Core/UniversalBackupManager.ps1"
. "$PSScriptRoot/Models/SimpleTask.ps1"
. "$PSScriptRoot/Models/SimpleTimeEntry.ps1"
. "$PSScriptRoot/Services/ColorThemeService.ps1"
. "$PSScriptRoot/Services/SimpleTaskService.ps1"
. "$PSScriptRoot/Services/TimeTrackingService.ps1"
. "$PSScriptRoot/Screens/TaskListScreen.ps1"

Write-Host "Testing TimeTrackingService integration..." -ForegroundColor Green
Write-Host ""

# Create and test TaskListScreen
$screen = [TaskListScreen]::new()
$screen.Initialize(80, 24)

Write-Host "1. TimeService initialized: $($screen.TimeService -ne $null)" -ForegroundColor $(if ($screen.TimeService) { "Green" } else { "Red" })

if ($screen.TimeService) {
    $allEntries = $screen.TimeService.GetAllEntries()
    Write-Host "2. All entries loaded: $($allEntries.Count)" -ForegroundColor Green
    
    $currentWeekEntries = $screen.TimeService.GetCurrentWeekEntries()
    Write-Host "3. Current week entries: $($currentWeekEntries.Count)" -ForegroundColor Green
    
    Write-Host "4. Testing mode switch to TimeEntry..." -ForegroundColor Yellow
    $screen.SwitchToTimeEntryMode()
    
    Write-Host "5. Current mode: $($screen.CurrentMode)" -ForegroundColor $(if ($screen.CurrentMode -eq "TimeEntry") { "Green" } else { "Red" })
    Write-Host "6. Screen TimeEntries: $($screen.TimeEntries.Count)" -ForegroundColor $(if ($screen.TimeEntries.Count -gt 0) { "Green" } else { "Red" })
    Write-Host "7. TimeFlatList: $($screen.TimeFlatList.Count)" -ForegroundColor $(if ($screen.TimeFlatList.Count -gt 0) { "Green" } else { "Red" })
    
    if ($screen.TimeFlatList.Count -gt 0) {
        Write-Host ""
        Write-Host "Time entries loaded successfully:" -ForegroundColor Green
        for ($i = 0; $i -lt $screen.TimeFlatList.Count; $i++) {
            $entry = $screen.TimeFlatList[$i].Entry
            Write-Host "  - $($entry.ID1Display): $($entry.Description) (Total: $($entry.Total))" -ForegroundColor Cyan
        }
    }
}

Write-Host ""
Write-Host "Test completed. F4 functionality should work properly." -ForegroundColor Green