#!/usr/bin/env pwsh

# Test double buffer implementation
param(
    [switch]$Debug
)

# Load core components
. "./Core/VT100.ps1"
. "./Core/ServiceContainer.ps1"
. "./Core/StringBuilderPool.ps1"

# Load services
. "./Services/Logger.ps1"
. "./Services/ThemeManager.ps1"
. "./Services/EventBus.ps1"
. "./Services/ProjectService.ps1"
. "./Services/TaskService.ps1"
. "./Services/ConfigurationService.ps1"
. "./Services/ShortcutManager.ps1"
. "./Services/StateManager.ps1"
. "./Services/FocusManager.ps1"

# Load models
. "./Models/Project.ps1"
. "./Models/Task.ps1"

# Load base classes
. "./Base/UIElement.ps1"
. "./Base/Container.ps1"
. "./Base/Screen.ps1"

# Load components
. "./Components/Button.ps1"
. "./Components/ListBox.ps1"
. "./Components/TabContainer.ps1"
. "./Components/CommandPalette.ps1"
. "./Components/TextBox.ps1"
. "./Components/DataGrid.ps1"

# Load screens
. "./Screens/MainScreen.ps1"
. "./Screens/ProjectsScreen.ps1"
. "./Screens/TaskScreen.ps1"
. "./Screens/TestScreen.ps1"

# Load Core
. "./Core/ScreenManager.ps1"

# Initialize services
$services = [ServiceContainer]::new()

# Register services
$logger = [Logger]::new("test_double_buffer.log", $Debug)
$global:Logger = $logger
$services.RegisterService('Logger', $logger)

$eventBus = [EventBus]::new()
$services.RegisterService('EventBus', $eventBus)

$themeManager = [ThemeManager]::new()
$services.RegisterService('ThemeManager', $themeManager)

$projectService = [ProjectService]::new("./_ProjectData/projects.json")
$services.RegisterService('ProjectService', $projectService)

$taskService = [TaskService]::new("./_ProjectData/tasks.json")
$services.RegisterService('TaskService', $taskService)

$configService = [ConfigurationService]::new()
$services.RegisterService('ConfigurationService', $configService)

$shortcutManager = [ShortcutManager]::new()
$services.RegisterService('ShortcutManager', $shortcutManager)

$stateManager = [StateManager]::new()
$services.RegisterService('StateManager', $stateManager)

$focusManager = [FocusManager]::new($services)
$services.RegisterService('FocusManager', $focusManager)

Write-Host "Starting double buffer test..." -ForegroundColor Green

# Create screen manager
$screenManager = [ScreenManager]::new($services)
$global:ScreenManager = $screenManager

# Push test screen
$testScreen = [TestScreen]::new()
$screenManager.Push($testScreen)

Write-Host "Rendering with double buffer..." -ForegroundColor Yellow

# Run for a short time to test
$timer = [System.Diagnostics.Stopwatch]::StartNew()
$frameCount = 0

try {
    [Console]::CursorVisible = $false
    
    while ($timer.ElapsedMilliseconds -lt 3000) {  # Run for 3 seconds
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [System.ConsoleKey]::Escape) {
                break
            }
            $testScreen.HandleInput($key)
            $screenManager.RequestRender()
        }
        
        # Force render every frame to test performance
        $screenManager._needsRender = $true
        $screenManager.Render()
        $frameCount++
        
        Start-Sleep -Milliseconds 16  # ~60 FPS target
    }
}
finally {
    [Console]::CursorVisible = $true
    [Console]::Clear()
    
    $elapsed = $timer.ElapsedMilliseconds / 1000.0
    $fps = $frameCount / $elapsed
    
    Write-Host "`nDouble Buffer Test Results:" -ForegroundColor Cyan
    Write-Host "  Total frames: $frameCount"
    Write-Host "  Elapsed time: $($elapsed.ToString('F2'))s"
    Write-Host "  Average FPS: $($fps.ToString('F1'))"
    Write-Host "  Last FPS: $($screenManager.GetFPS().ToString('F1'))"
    
    # Get StringBuilder pool stats
    $poolStats = [StringBuilderPool]::GetStats()
    Write-Host "`nStringBuilder Pool Stats:" -ForegroundColor Cyan
    Write-Host "  Pool size: $($poolStats.PoolSize)"
    Write-Host "  Created: $($poolStats.Created)"
    Write-Host "  Reused: $($poolStats.Reused)"
    Write-Host "  Reuse rate: $($poolStats.ReuseRate)%"
}