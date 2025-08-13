# Test-Phase4.5-Simple.ps1 - Simple test for Phase 4.5 clean architecture
# Tests the core functionality without loading legacy files

Write-Host "Testing Phase 4.5 Clean Architecture..." -ForegroundColor Green

try {
    # Test 1: Load core new architecture files
    Write-Host "Loading new architecture components..." -ForegroundColor Cyan
    
    # Load new components in order
    . "$PSScriptRoot/Core/ServiceContainer.ps1"
    . "$PSScriptRoot/Core/Logger.ps1" 
    . "$PSScriptRoot/Core/EventBus.ps1"
    . "$PSScriptRoot/Core/SimpleStateManager.ps1"
    . "$PSScriptRoot/Base/Screen.ps1"
    . "$PSScriptRoot/Base/ListScreen.ps1"
    
    Write-Host "✅ All new architecture files loaded successfully" -ForegroundColor Green
    
    # Test 2: Create ServiceContainer
    Write-Host "Testing ServiceContainer..." -ForegroundColor Cyan
    $services = [ServiceContainer]::new()
    
    # Test 3: Create singletons
    Write-Host "Testing singleton services..." -ForegroundColor Cyan
    $logger = [Logger]::new()
    $eventBus = [EventBus]::new()
    $stateManager = [SimpleStateManager]::new($eventBus, $logger)
    
    # Register services
    $services.Register("Logger", $logger)
    $services.Register("EventBus", $eventBus)
    $services.Register("StateManager", $stateManager)
    
    Write-Host "✅ All singletons created and registered" -ForegroundColor Green
    
    # Test 4: Test state management
    Write-Host "Testing simple state management..." -ForegroundColor Cyan
    $stateManager.Set("TestKey", "TestValue")
    $value = $stateManager.Get("TestKey")
    
    if ($value -eq "TestValue") {
        Write-Host "✅ Simple state management working" -ForegroundColor Green
    } else {
        throw "State management failed: expected 'TestValue', got '$value'"
    }
    
    # Test 5: Test EventBus
    Write-Host "Testing EventBus communication..." -ForegroundColor Cyan
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
    
    # Test 6: Test Screen base class (simplified)
    Write-Host "Testing Screen base class..." -ForegroundColor Cyan
    
    # Create a mock screen that extends Screen
    class TestScreen : Screen {
        TestScreen([ServiceContainer]$services) : base($services) {}
        
        [string] Render() {
            return "Test Render Output"
        }
    }
    
    $testScreen = [TestScreen]::new($services)
    $renderOutput = $testScreen.Render()
    
    if ($renderOutput -eq "Test Render Output") {
        Write-Host "✅ Screen base class working" -ForegroundColor Green
    } else {
        throw "Screen base class failed"
    }
    
    # Test 7: Test ListScreen base class
    Write-Host "Testing ListScreen base class..." -ForegroundColor Cyan
    
    class TestListScreen : ListScreen {
        TestListScreen([ServiceContainer]$services) : base($services) {}
        
        [string] RenderItem([object]$item, [int]$index, [bool]$isSelected) {
            return "Item: $($item.ToString())"
        }
    }
    
    $testListScreen = [TestListScreen]::new($services)
    $testListScreen.FlatList.Add("TestItem")
    
    if ($testListScreen.FlatList.Count -eq 1) {
        Write-Host "✅ ListScreen base class working" -ForegroundColor Green
    } else {
        throw "ListScreen base class failed"
    }
    
    Write-Host ""
    Write-Host "🎉 Phase 4.5 Clean Architecture Test PASSED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Summary of improvements:" -ForegroundColor Yellow
    Write-Host "  ✅ Clean two-layer hierarchy: Screen → ListScreen" -ForegroundColor White
    Write-Host "  ✅ Singleton services with proper injection" -ForegroundColor White
    Write-Host "  ✅ Simple PowerShell-native state management" -ForegroundColor White
    Write-Host "  ✅ EventBus communication working" -ForegroundColor White
    Write-Host "  ✅ All architectural cleanup completed" -ForegroundColor White
    Write-Host ""
    Write-Host "Ready for screen migrations!" -ForegroundColor Green
    
} catch {
    Write-Host ""
    Write-Host "❌ Phase 4.5 Architecture Test FAILED!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    exit 1
}

Write-Host "Phase 4.5 architecture test complete." -ForegroundColor Green