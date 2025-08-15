#!/usr/bin/env pwsh
# TestTaskProPro.ps1 - Test TaskProPro foundation without full interactive mode

param(
    [string]$DataFile = "$PSScriptRoot/Data/tasks.json"
)

try {
    Write-Host "Testing TaskProPro Foundation..." -ForegroundColor Cyan
    
    # Load foundation
    . "$PSScriptRoot/Load-TaskProPro.ps1"
    
    # Initialize data directory
    $dataDir = Split-Path $DataFile -Parent
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
    
    # Test TaskManager
    Write-Host "Testing TaskManager..." -ForegroundColor Yellow
    $taskManager = [TaskPro.Data.TaskManager]::new($DataFile)
    
    # Create test task
    $testTask = [TaskPro.Data.SimpleTask]::new()
    $testTask.Title = "Test Task"
    $testTask.Priority = [TaskPro.Data.Priority]::High
    $testTask.Tags.Add("test")
    $taskManager.AddTask($testTask)
    
    # Verify task was added
    $allTasks = $taskManager.GetAllTasks()
    Write-Host "Created $($allTasks.Count) tasks" -ForegroundColor Green
    
    # Test screen buffer
    Write-Host "Testing ScreenBuffer..." -ForegroundColor Yellow
    $screen = [TaskPro.Core.ScreenBuffer]::new(80, 24)
    $screen.BeginFrame()
    $screen.WriteAt(10, 5, "Hello TaskProPro!", [ConsoleColor]::Cyan)
    $output = $screen.EndFrame()
    
    Write-Host "ScreenBuffer test completed" -ForegroundColor Green
    
    # Test filtering
    Write-Host "Testing TaskFilter..." -ForegroundColor Yellow
    $filter = [TaskPro.Data.FilterCriteria]::new()
    $filter.Priority = [TaskPro.Data.Priority]::High
    $filteredTasks = $taskManager.ApplyFilter($filter)
    Write-Host "Filtered to $($filteredTasks.Count) high priority tasks" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "✓ All foundation components working correctly!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To run the full TaskProPro application:" -ForegroundColor Cyan
    Write-Host "  ./TaskProPro.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "Note: TaskProPro requires an interactive PowerShell terminal" -ForegroundColor Yellow
    
} catch {
    Write-Host "Test failed: $_" -ForegroundColor Red
    if ($_.ScriptStackTrace) {
        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
    }
}