#!/usr/bin/env pwsh
# debug-task-data.ps1 - Debug task data flow

param([switch]$Debug)
$global:Debug = $Debug.IsPresent

Write-Host "Debugging TaskProPro data flow..." -ForegroundColor Cyan

try {
    # Load DLL
    $dllPath = "$PSScriptRoot/TaskPro.dll"
    Add-Type -Path $dllPath
    Write-Host "✓ DLL loaded" -ForegroundColor Green
    
    # Create TaskManager
    $dataFile = "$PSScriptRoot/Data/tasks.json"
    $taskManager = [TaskPro.Data.TaskManager]::new($dataFile)
    Write-Host "✓ TaskManager created" -ForegroundColor Green
    
    # Check task data
    $allTasks = $taskManager.GetAllTasks()
    Write-Host "Task count: $($allTasks.Count)" -ForegroundColor Yellow
    
    foreach ($task in $allTasks) {
        Write-Host "Task ID: $($task.Id)" -ForegroundColor Cyan
        Write-Host "  Title: '$($task.Title)'" -ForegroundColor White
        Write-Host "  Priority: $($task.Priority)" -ForegroundColor Yellow
        Write-Host "  ID1: '$($task.ID1)'" -ForegroundColor Gray
        Write-Host "  ID2: '$($task.ID2)'" -ForegroundColor Gray
        Write-Host "  Tags: $($task.Tags -join ',')" -ForegroundColor Green
        Write-Host "  Completed: $($task.Completed)" -ForegroundColor Magenta
        Write-Host "  GetCyberpunkPriority(): '$($task.GetCyberpunkPriority())'" -ForegroundColor Cyan
        Write-Host "  GetCyberpunkDate(): '$($task.GetCyberpunkDate())'" -ForegroundColor Cyan
        Write-Host ""
    }
    
    # Test BuildFlatList
    Write-Host "Testing BuildFlatList..." -ForegroundColor Yellow
    $flatList = $taskManager.BuildFlatList($allTasks, $false)
    Write-Host "Flat list count: $($flatList.Count)" -ForegroundColor Yellow
    
    foreach ($item in $flatList) {
        Write-Host "TaskListItem:" -ForegroundColor Cyan
        Write-Host "  Task.Title: '$($item.Task.Title)'" -ForegroundColor White
        Write-Host "  Task.Priority: $($item.Task.Priority)" -ForegroundColor Yellow
        Write-Host "  Task.Tags: $($item.Task.Tags -join ',')" -ForegroundColor Green
        Write-Host ""
    }
    
    # Test column manager formatting
    Write-Host "Testing TaskListColumnManager..." -ForegroundColor Yellow
    $columnManager = [TaskPro.UI.TaskListColumnManager]::new()
    $columnManager.CalculateLayout(100)
    
    Write-Host "Header row: '$($columnManager.GetHeaderRow())'" -ForegroundColor Green
    Write-Host "Separator: '$($columnManager.GetSeparatorRow())'" -ForegroundColor Green
    
    foreach ($task in $allTasks) {
        $formattedRow = $columnManager.FormatTaskRow($task)
        Write-Host "Formatted row: '$formattedRow'" -ForegroundColor White
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.Exception.ToString() -ForegroundColor Red
}