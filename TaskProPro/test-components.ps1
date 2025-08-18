#!/usr/bin/env pwsh
# test-components.ps1 - Test TaskListWidget decomposed components

param([switch]$Debug)
$global:Debug = $Debug.IsPresent

Write-Host "Testing TaskProPro decomposed components..." -ForegroundColor Cyan

try {
    # Load DLL
    $dllPath = "$PSScriptRoot/TaskPro.dll"
    if (-not (Test-Path $dllPath)) {
        Write-Host "Building TaskPro.dll..." -ForegroundColor Yellow
        & "$PSScriptRoot/Build-TaskProDll.ps1"
    }
    
    Add-Type -Path $dllPath
    Write-Host "✓ DLL loaded successfully" -ForegroundColor Green
    
    # Test component creation
    Write-Host "Testing component creation..." -ForegroundColor Cyan
    
    # TaskManager
    $dataFile = "$PSScriptRoot/Data/tasks.json"
    $taskManager = [TaskPro.Data.TaskManager]::new($dataFile)
    Write-Host "✓ TaskManager created" -ForegroundColor Green
    
    # ScreenBuffer
    $screen = [TaskPro.Core.ScreenBuffer]::new(100, 30)
    Write-Host "✓ ScreenBuffer created" -ForegroundColor Green
    
    # StatusBar
    $statusBar = [TaskPro.UI.StatusBar]::new()
    Write-Host "✓ StatusBar created" -ForegroundColor Green
    
    # TaskListWidget - This is where the issue likely is
    $taskListWidget = [TaskPro.UI.TaskListWidget]::new()
    Write-Host "✓ TaskListWidget created" -ForegroundColor Green
    
    # Configure dependencies
    $taskListWidget.TaskManager = $taskManager
    $taskListWidget.StatusBar = $statusBar
    Write-Host "✓ Dependencies set" -ForegroundColor Green
    
    # Test UpdateDependencies method
    $taskListWidget.UpdateDependencies()
    Write-Host "✓ UpdateDependencies called" -ForegroundColor Green
    
    # Test RefreshTaskList method
    $taskListWidget.RefreshTaskList()
    Write-Host "✓ RefreshTaskList called" -ForegroundColor Green
    
    # Test filter creation
    $currentFilter = [TaskPro.Data.FilterCriteria]::new()
    $taskListWidget.CurrentFilter = $currentFilter
    Write-Host "✓ Filter configured" -ForegroundColor Green
    
    # Test render method with wider screen to see full layout
    $screen = [TaskPro.Core.ScreenBuffer]::new(120, 30)
    $rect = [TaskPro.Core.Rectangle]::new(0, 0, 120, 30)
    $screen.BeginFrame()
    $taskListWidget.Render($screen, $rect)
    $screen.EndFrame()
    Write-Host "✓ Render method called successfully" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "All component tests passed! TaskProPro should work correctly." -ForegroundColor Green
    
} catch {
    Write-Host ""
    Write-Host "✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($global:Debug) {
        Write-Host "Stack Trace:" -ForegroundColor Yellow
        Write-Host $_.Exception.ToString() -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "This indicates the issue preventing TaskProPro startup." -ForegroundColor Red
    exit 1
}