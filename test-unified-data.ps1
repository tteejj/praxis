#!/usr/bin/env pwsh
# test-unified-data.ps1 - Test unified data structure

Write-Host "Testing Unified Data Structure..." -ForegroundColor Cyan
Write-Host ""

try {
    . "$PSScriptRoot/TaskPro/Services/PraxisDataService.ps1"
    Write-Host "✓ PraxisDataService loaded" -ForegroundColor Green
    
    [PraxisDataService]::Initialize("$PSScriptRoot/TaskPro/_ProjectData")
    Write-Host "✓ PraxisDataService initialized" -ForegroundColor Green
    
    $data = [PraxisDataService]::GetData()
    
    Write-Host ""
    Write-Host "Unified Data Test Results:" -ForegroundColor Yellow
    Write-Host "  Projects: $($data.projects.Count)" -ForegroundColor $(if ($data.projects.Count -gt 0) { "Green" } else { "Yellow" })
    Write-Host "  Tasks: $($data.tasks.Count)" -ForegroundColor $(if ($data.tasks.Count -gt 0) { "Green" } else { "Yellow" })
    Write-Host "  Time Entries: $($data.timeEntries.Count)" -ForegroundColor $(if ($data.timeEntries.Count -gt 0) { "Green" } else { "Yellow" })
    Write-Host "  Commands: $($data.commands.Count)" -ForegroundColor $(if ($data.commands.Count -gt 0) { "Green" } else { "Yellow" })
    Write-Host "  Metadata Version: $($data.metadata.version)" -ForegroundColor Green
    Write-Host "  Migration Date: $($data.metadata.migrationDate)" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "App States:" -ForegroundColor Yellow
    Write-Host "  TaskPro: $(if ($data.appStates.taskpro) { 'Available' } else { 'Missing' })" -ForegroundColor $(if ($data.appStates.taskpro) { "Green" } else { "Red" })
    Write-Host "  TimeTracker: $(if ($data.appStates.timetracker) { 'Available' } else { 'Missing' })" -ForegroundColor $(if ($data.appStates.timetracker) { "Green" } else { "Red" })
    Write-Host "  CommandLibrary: $(if ($data.appStates.commandlibrary) { 'Available' } else { 'Missing' })" -ForegroundColor $(if ($data.appStates.commandlibrary) { "Green" } else { "Red" })
    
    Write-Host ""
    Write-Host "Sample Data Preview:" -ForegroundColor Yellow
    if ($data.tasks.Count -gt 0) {
        Write-Host "  First Task: $($data.tasks[0].Title)" -ForegroundColor White
    }
    if ($data.commands.Count -gt 0) {
        Write-Host "  First Command: $($data.commands[0].Title)" -ForegroundColor White
    }
    if ($data.timeEntries.Count -gt 0) {
        Write-Host "  First Time Entry: $($data.timeEntries[0].ProjectCode) - $($data.timeEntries[0].Description)" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "✓ Unified data loads successfully!" -ForegroundColor Green
    
    # Test convenience methods
    Write-Host ""
    Write-Host "Testing convenience methods..." -ForegroundColor Yellow
    $projects = [PraxisDataService]::GetProjects()
    $tasks = [PraxisDataService]::GetTasks()
    $commands = [PraxisDataService]::GetCommands()
    $timeEntries = [PraxisDataService]::GetTimeEntries()
    
    Write-Host "  GetProjects(): $($projects.Count) items" -ForegroundColor Green
    Write-Host "  GetTasks(): $($tasks.Count) items" -ForegroundColor Green
    Write-Host "  GetCommands(): $($commands.Count) items" -ForegroundColor Green
    Write-Host "  GetTimeEntries(): $($timeEntries.Count) items" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "✓ All tests passed! Unified data system is working." -ForegroundColor Green
    
} catch {
    Write-Host "✗ Failed to load unified data: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}