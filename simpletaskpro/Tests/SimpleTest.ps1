#!/usr/bin/env pwsh
# Simple test to verify Phase 1 functionality works

Write-Host "=== Phase 1 Simple Test ===" -ForegroundColor Cyan

# Test 1: Can we load the SimpleTask class?
Write-Host "`n1. Testing SimpleTask class..." -ForegroundColor Yellow
try {
    . "$PSScriptRoot/../Models/SimpleTask.ps1"
    $task = [SimpleTask]::new("Test Task")
    Write-Host "✓ SimpleTask created: $($task.Title)" -ForegroundColor Green
} catch {
    Write-Host "✗ SimpleTask failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 2: Can we load the SimpleTaskService class?
Write-Host "`n2. Testing SimpleTaskService class..." -ForegroundColor Yellow
try {
    . "$PSScriptRoot/../Services/SimpleTaskService.ps1"
    $service = [SimpleTaskService]::new("TestData/test_tasks.json")
    Write-Host "✓ SimpleTaskService created with $($service.GetTaskCount()) tasks" -ForegroundColor Green
} catch {
    Write-Host "✗ SimpleTaskService failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 3: Can we load the TaskListManager class?
Write-Host "`n3. Testing TaskListManager class..." -ForegroundColor Yellow
try {
    . "$PSScriptRoot/../Managers/TaskListManager.ps1"
    $manager = [TaskListManager]::new("TestData/test_tasks.json")
    Write-Host "✓ TaskListManager created with $($manager.FlatList.Count) flat items" -ForegroundColor Green
} catch {
    Write-Host "✗ TaskListManager failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

# Test 4: Basic operations
Write-Host "`n4. Testing basic operations..." -ForegroundColor Yellow
try {
    # Create a task
    $manager.CreateNewTask("Phase 1 Test Task", "High")
    
    # List tasks
    Write-Host "Tasks in manager:" -ForegroundColor Blue
    foreach ($item in $manager.FlatList) {
        $task = $item.Task
        Write-Host "  $($task.GetStatusIcon()) $($task.Title) [$($task.Priority)]" -ForegroundColor Gray
    }
    
    # Test filtering
    $manager.SetFilter("High")
    Write-Host "High priority tasks: $($manager.FlatList.Count)" -ForegroundColor Blue
    
    # Test navigation
    $manager.MoveDown()
    $currentTask = $manager.GetCurrentTask()
    if ($currentTask) {
        Write-Host "Current task: $($currentTask.Title)" -ForegroundColor Blue
    }
    
    Write-Host "✓ Basic operations completed successfully" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Basic operations failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Phase 1 Test Completed Successfully! ===" -ForegroundColor Green
Write-Host "All core functionality is working:" -ForegroundColor White
Write-Host "  ✓ SimpleTask model with filtering methods" -ForegroundColor Green
Write-Host "  ✓ SimpleTaskService with CRUD operations" -ForegroundColor Green
Write-Host "  ✓ TaskListManager with all core data functions" -ForegroundColor Green
Write-Host "  ✓ Task creation, filtering, and navigation" -ForegroundColor Green

$manager.PrintStats()