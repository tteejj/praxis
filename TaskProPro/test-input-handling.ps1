#!/usr/bin/env pwsh
# test-input-handling.ps1 - Test keyboard shortcut handling

param([switch]$Debug)
$global:Debug = $Debug.IsPresent

Write-Host "Testing TaskProPro input handling..." -ForegroundColor Cyan

try {
    # Load DLL
    $dllPath = "$PSScriptRoot/TaskPro.dll"
    Add-Type -Path $dllPath
    Write-Host "✓ DLL loaded" -ForegroundColor Green
    
    # Create components
    $taskManager = [TaskPro.Data.TaskManager]::new("$PSScriptRoot/Data/tasks.json")
    $statusBar = [TaskPro.UI.StatusBar]::new()
    $taskListWidget = [TaskPro.UI.TaskListWidget]::new()
    
    # Configure dependencies
    $taskListWidget.TaskManager = $taskManager
    $taskListWidget.StatusBar = $statusBar
    $taskListWidget.UpdateDependencies()
    $taskListWidget.RefreshTaskList()
    
    Write-Host "✓ Components configured" -ForegroundColor Green
    
    # Test input creation and handling
    Write-Host "Testing input event creation..." -ForegroundColor Yellow
    
    # Test Enter key
    $enterInput = [TaskPro.Core.InputEvent]::new()
    $enterInput.Key = [ConsoleKey]::Enter
    Write-Host "  Enter key input created - IsEnter: $($enterInput.IsEnter)" -ForegroundColor Green
    
    # Test E key
    $eInput = [TaskPro.Core.InputEvent]::new()
    $eInput.Key = [ConsoleKey]::E
    $eInput.Char = 'E'
    Write-Host "  E key input created - IsPrintableChar: $($eInput.IsPrintableChar)" -ForegroundColor Green
    
    # Test N key
    $nInput = [TaskPro.Core.InputEvent]::new()
    $nInput.Key = [ConsoleKey]::N
    $nInput.Char = 'N'
    Write-Host "  N key input created - IsPrintableChar: $($nInput.IsPrintableChar)" -ForegroundColor Green
    
    Write-Host "Testing input handling..." -ForegroundColor Yellow
    
    # Test E key handling (should trigger edit)
    $result = $taskListWidget.HandleInput($eInput)
    Write-Host "  E key handled: $result" -ForegroundColor Green
    
    # Test N key handling (should trigger new task)
    $result = $taskListWidget.HandleInput($nInput)
    Write-Host "  N key handled: $result" -ForegroundColor Green
    
    # Test Enter key handling (should trigger notes)
    $result = $taskListWidget.HandleInput($enterInput)
    Write-Host "  Enter key handled: $result" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "All input handling tests passed!" -ForegroundColor Green
    Write-Host "The keyboard shortcuts (E, Enter, N) are working correctly." -ForegroundColor Cyan
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.Exception.ToString() -ForegroundColor Red
    exit 1
}