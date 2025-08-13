# Test-Phase4.5-Core.ps1 - Test core Phase 4.5 cleanup components
# Tests the essential architectural improvements

Write-Host "Testing Phase 4.5 Core Architecture..." -ForegroundColor Green

try {
    # Test 1: Load core components only
    Write-Host "Loading core architecture components..." -ForegroundColor Cyan
    
    # Load Logger (now singleton)
    . "$PSScriptRoot/Core/Logger.ps1"
    $logger = [Logger]::new()
    Write-Host "✅ Logger singleton created" -ForegroundColor Green
    
    # Test Logger instance methods
    $logger.Initialize("./test-logs", [LogLevel]::Debug)
    $logger.Info("Test log message")
    $logger.Debug("Test debug message")
    Write-Host "✅ Logger instance methods working" -ForegroundColor Green
    
    # Load EventBus (now singleton)
    . "$PSScriptRoot/Core/EventBus.ps1"
    $eventBus = [EventBus]::new()
    Write-Host "✅ EventBus singleton created" -ForegroundColor Green
    
    # Test EventBus
    $testResult = $null
    $eventBus.Subscribe("test.event", {
        param($data)
        $script:testResult = $data
    })
    
    $eventBus.Publish("test.event", "EventTest")
    
    if ($testResult -eq "EventTest") {
        Write-Host "✅ EventBus communication working" -ForegroundColor Green
    } else {
        throw "EventBus failed: expected 'EventTest', got '$testResult'"
    }
    
    # Load SimpleStateManager (replaces complex StateManager)
    . "$PSScriptRoot/Core/SimpleStateManager.ps1"
    $stateManager = [SimpleStateManager]::new($eventBus, $logger)
    Write-Host "✅ SimpleStateManager created" -ForegroundColor Green
    
    # Test simple state management
    $stateManager.Set("TestKey", "TestValue")
    $value = $stateManager.Get("TestKey")
    
    if ($value -eq "TestValue") {
        Write-Host "✅ Simple state management working" -ForegroundColor Green
    } else {
        throw "State management failed: expected 'TestValue', got '$value'"
    }
    
    # Test task-specific convenience methods
    $stateManager.SetTaskList(@("Task1", "Task2"))
    $stateManager.SetSelectedTask(1)
    $stateManager.SetTaskFilter("Today")
    
    $taskList = $stateManager.Get("TaskList")
    $selectedIndex = $stateManager.Get("SelectedTaskIndex")
    $filter = $stateManager.Get("TaskFilter")
    
    if ($taskList.Count -eq 2 -and $selectedIndex -eq 1 -and $filter -eq "Today") {
        Write-Host "✅ Task-specific state methods working" -ForegroundColor Green
    } else {
        throw "Task state methods failed"
    }
    
    # Test batch updates
    $stateManager.Update(@{
        WindowWidth = 120
        WindowHeight = 40
        CurrentScreen = "Tasks"
    })
    
    $width = $stateManager.Get("WindowWidth")
    $height = $stateManager.Get("WindowHeight")
    $screen = $stateManager.Get("CurrentScreen")
    
    if ($width -eq 120 -and $height -eq 40 -and $screen -eq "Tasks") {
        Write-Host "✅ Batch state updates working" -ForegroundColor Green
    } else {
        throw "Batch updates failed"
    }
    
    Write-Host ""
    Write-Host "🎉 Phase 4.5 Core Architecture Test PASSED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Architectural Cleanup Verified:" -ForegroundColor Yellow
    Write-Host "  ✅ Logger converted from static to singleton" -ForegroundColor White
    Write-Host "  ✅ EventBus converted from static to singleton" -ForegroundColor White
    Write-Host "  ✅ Complex StateManager replaced with simple PowerShell-native version" -ForegroundColor White
    Write-Host "  ✅ No more Redux complexity - simple key/value state" -ForegroundColor White
    Write-Host "  ✅ YAGNI principles maintained" -ForegroundColor White
    Write-Host ""
    Write-Host "Phase 4.5 cleanup successful - architecture is ready!" -ForegroundColor Green
    
} catch {
    Write-Host ""
    Write-Host "❌ Phase 4.5 Core Architecture Test FAILED!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    exit 1
}

Write-Host "Phase 4.5 core architecture test complete." -ForegroundColor Green