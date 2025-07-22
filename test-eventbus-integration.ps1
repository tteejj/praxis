#!/usr/bin/env pwsh
# Integration test for EventBus in PRAXIS

Write-Host "EventBus Integration Test" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""

# Load the framework (without running the main loop)
$script:PraxisRoot = $PSScriptRoot
$global:PraxisRoot = $PSScriptRoot
Set-Location $script:PraxisRoot

# Load all required files
$loadOrder = @(
    "Core/VT100.ps1"
    "Core/ServiceContainer.ps1"
    "Services/Logger.ps1"
    "Services/ThemeManager.ps1"
    "Base/UIElement.ps1"
    "Base/Container.ps1"
    "Base/Screen.ps1"
    "Models/Project.ps1"
    "Models/Task.ps1"
    "Services/EventBus.ps1"
    "Services/ProjectService.ps1"
    "Services/TaskService.ps1"
    "Services/ConfigurationService.ps1"
    "Components/ListBox.ps1"
    "Components/TextBox.ps1"
    "Components/Button.ps1"
    "Components/DataGrid.ps1"
    "Components/TabContainer.ps1"
    "Core/ScreenManager.ps1"
    "Screens/TextInputDialog.ps1"
    "Screens/NumberInputDialog.ps1"
    "Screens/ConfirmationDialog.ps1"
    "Screens/NewProjectDialog.ps1"
    "Screens/EditProjectDialog.ps1"
    "Screens/NewTaskDialog.ps1"
    "Screens/EditTaskDialog.ps1"
    "Screens/TestScreen.ps1"
    "Screens/ProjectsScreen.ps1"
    "Screens/TaskScreen.ps1"
    "Screens/SettingsScreen.ps1"
    "Components/CommandPalette.ps1"
    "Screens/MainScreen.ps1"
)

Write-Host "Loading framework components..." -ForegroundColor Yellow
foreach ($file in $loadOrder) {
    $path = Join-Path $script:PraxisRoot $file
    if (Test-Path $path) {
        . $path
    }
}

# Initialize services
Write-Host "Initializing services..." -ForegroundColor Yellow
$logger = [Logger]::new()
$global:Logger = $logger
$global:ServiceContainer.Register("Logger", $logger)

$themeManager = [ThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $themeManager)

$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("EventBus", $eventBus)

$projectService = [ProjectService]::new()
$global:ServiceContainer.Register("ProjectService", $projectService)

$taskService = [TaskService]::new()
$global:ServiceContainer.Register("TaskService", $taskService)

$configService = [ConfigurationService]::new()
$global:ServiceContainer.Register("ConfigurationService", $configService)

$screenManager = [ScreenManager]::new($global:ServiceContainer)
$global:ScreenManager = $screenManager
$global:ServiceContainer.Register("ScreenManager", $screenManager)

Write-Host "Services initialized successfully!" -ForegroundColor Green
Write-Host ""

# Test 1: Tab change events
Write-Host "Test 1: Tab Change Events" -ForegroundColor Cyan
Write-Host "-------------------------" -ForegroundColor DarkGray

$tabChanges = @()
$tabSubscription = $eventBus.Subscribe([EventNames]::TabChanged, {
    param($sender, $eventData)
    $script:tabChanges += $eventData
    Write-Host "  Tab changed to index: $($eventData.TabIndex)" -ForegroundColor Green
})

# Simulate CommandPalette publishing tab change
$eventBus.Publish([EventNames]::TabChanged, @{ TabIndex = 0 })
$eventBus.Publish([EventNames]::TabChanged, @{ TabIndex = 1 })

Write-Host "  Total tab changes: $($tabChanges.Count)" -ForegroundColor DarkGray
Write-Host ""

# Test 2: Project events
Write-Host "Test 2: Project Events" -ForegroundColor Cyan
Write-Host "----------------------" -ForegroundColor DarkGray

$projectEvents = @()
$projectCreatedSub = $eventBus.Subscribe([EventNames]::ProjectCreated, {
    param($sender, $eventData)
    $script:projectEvents += @{ Type = 'Created'; Data = $eventData }
    Write-Host "  Project created: $($eventData.Project.Name)" -ForegroundColor Green
})

$projectUpdatedSub = $eventBus.Subscribe([EventNames]::ProjectUpdated, {
    param($sender, $eventData)
    $script:projectEvents += @{ Type = 'Updated'; Data = $eventData }
    Write-Host "  Project updated: $($eventData.Project.Name)" -ForegroundColor Yellow
})

$projectDeletedSub = $eventBus.Subscribe([EventNames]::ProjectDeleted, {
    param($sender, $eventData)
    $script:projectEvents += @{ Type = 'Deleted'; Data = $eventData }
    Write-Host "  Project deleted: ID $($eventData.ProjectId)" -ForegroundColor Red
})

# Simulate project operations
$testProject = @{ Id = 1; Name = "Test Project"; Nickname = "TEST" }
$eventBus.Publish([EventNames]::ProjectCreated, @{ Project = $testProject })
$eventBus.Publish([EventNames]::ProjectUpdated, @{ Project = $testProject })
$eventBus.Publish([EventNames]::ProjectDeleted, @{ ProjectId = 1 })

Write-Host "  Total project events: $($projectEvents.Count)" -ForegroundColor DarkGray
Write-Host ""

# Test 3: Command execution events
Write-Host "Test 3: Command Execution Events" -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor DarkGray

$commandsExecuted = @()
$commandSub = $eventBus.Subscribe([EventNames]::CommandExecuted, {
    param($sender, $eventData)
    $script:commandsExecuted += $eventData
    Write-Host "  Command: $($eventData.Command) on $($eventData.Target)" -ForegroundColor Magenta
})

# Simulate command execution
$eventBus.Publish([EventNames]::CommandExecuted, @{ Command = 'NewTask'; Target = 'TaskScreen' })
$eventBus.Publish([EventNames]::CommandExecuted, @{ Command = 'EditProject'; Target = 'ProjectsScreen' })

Write-Host "  Total commands executed: $($commandsExecuted.Count)" -ForegroundColor DarkGray
Write-Host ""

# Test 4: Event bus info
Write-Host "Test 4: EventBus Statistics" -ForegroundColor Cyan
Write-Host "---------------------------" -ForegroundColor DarkGray

$info = $eventBus.GetEventInfo()
Write-Host "  Total handlers: $($info.TotalHandlers)" -ForegroundColor Yellow
Write-Host "  Event types:" -ForegroundColor Yellow
foreach ($eventName in $info.RegisteredEvents.Keys | Sort-Object) {
    $handlers = $info.RegisteredEvents[$eventName]
    Write-Host "    - $eventName : $($handlers.HandlerCount) handler(s)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Integration test completed successfully!" -ForegroundColor Green
Write-Host ""

# Show a sample of how screens would interact
Write-Host "Example: How screens interact with EventBus" -ForegroundColor Cyan
Write-Host "-------------------------------------------" -ForegroundColor DarkGray
Write-Host "1. CommandPalette publishes: TabChanged + CommandExecuted" -ForegroundColor White
Write-Host "2. MainScreen subscribes to: TabChanged (switches tabs)" -ForegroundColor White
Write-Host "3. ProjectsScreen subscribes to: CommandExecuted, ProjectCreated/Updated/Deleted" -ForegroundColor White
Write-Host "4. TaskScreen subscribes to: CommandExecuted, TaskCreated/Updated/Deleted" -ForegroundColor White
Write-Host ""

# Cleanup
$eventBus.UnsubscribeAll([EventNames]::TabChanged)
$eventBus.UnsubscribeAll([EventNames]::ProjectCreated)
$eventBus.UnsubscribeAll([EventNames]::ProjectUpdated)
$eventBus.UnsubscribeAll([EventNames]::ProjectDeleted)
$eventBus.UnsubscribeAll([EventNames]::CommandExecuted)

$logger.Cleanup()

Write-Host "Cleanup completed." -ForegroundColor DarkGray