#!/usr/bin/env pwsh
# TestTimeService.ps1 - Simple test of TimeTrackingService functionality

# Load core components 
. "$PSScriptRoot/Core/StringCache.ps1"
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Core/UniversalBackupManager.ps1"
. "$PSScriptRoot/Models/SimpleTimeEntry.ps1"
. "$PSScriptRoot/Services/TimeTrackingService.ps1"

Write-Host "Testing TimeTrackingService..." -ForegroundColor Green
Write-Host ""

try {
    # Create TimeTrackingService
    $timeService = [TimeTrackingService]::new()
    
    Write-Host "1. TimeService created: $($timeService -ne $null)" -ForegroundColor Green
    
    $allEntries = $timeService.GetAllEntries()
    Write-Host "2. All entries count: $($allEntries.Count)" -ForegroundColor Green
    
    $currentWeekEntries = $timeService.GetCurrentWeekEntries()
    Write-Host "3. Current week entries count: $($currentWeekEntries.Count)" -ForegroundColor Green
    
    $currentFriday = $timeService.CurrentWeekFriday.ToString('yyyyMMdd')
    Write-Host "4. Current week friday: $currentFriday" -ForegroundColor Green
    
    if ($currentWeekEntries.Count -gt 0) {
        Write-Host ""
        Write-Host "Current week time entries:" -ForegroundColor Yellow
        foreach ($entry in $currentWeekEntries) {
            Write-Host "  - $($entry.ID1Display): $($entry.Description) (Week: $($entry.WeekEndingFriday), Total: $($entry.Total))" -ForegroundColor Cyan
        }
    }
    
    Write-Host ""
    Write-Host "✓ TimeTrackingService works correctly!" -ForegroundColor Green
} catch {
    Write-Host "✗ Error testing TimeTrackingService: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}