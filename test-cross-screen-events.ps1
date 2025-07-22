#!/usr/bin/env pwsh
# Test cross-screen event communication

Write-Host "Cross-Screen Event Communication Test" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Load the framework
$script:PraxisRoot = $PSScriptRoot
$global:PraxisRoot = $PSScriptRoot
Set-Location $script:PraxisRoot

# Load only essential files
. ./Core/ServiceContainer.ps1
. ./Services/Logger.ps1
. ./Services/EventBus.ps1

# Initialize services
$logger = [Logger]::new()
$global:ServiceContainer.Register("Logger", $logger)

$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("EventBus", $eventBus)

Write-Host "Services initialized" -ForegroundColor Green
Write-Host ""

# Simulate screens subscribing to events
Write-Host "Setting up screen event subscriptions..." -ForegroundColor Yellow

# ProjectsScreen simulation
$projectsScreenEvents = @()
$projectsSub1 = $eventBus.Subscribe([EventNames]::RefreshRequested, {
    param($sender, $eventData)
    if (-not $eventData.Target -or $eventData.Target -eq 'ProjectsScreen') {
        $script:projectsScreenEvents += "Refresh requested"
        Write-Host "  [ProjectsScreen] Refreshing project list..." -ForegroundColor Green
    }
})

$projectsSub2 = $eventBus.Subscribe([EventNames]::ConfigChanged, {
    param($sender, $eventData)
    if ($eventData.Path -like "ui.projects.*") {
        $script:projectsScreenEvents += "Config changed: $($eventData.Path)"
        Write-Host "  [ProjectsScreen] Config changed: $($eventData.Path) = $($eventData.NewValue)" -ForegroundColor Yellow
    }
})

# TaskScreen simulation
$taskScreenEvents = @()
$tasksSub1 = $eventBus.Subscribe([EventNames]::RefreshRequested, {
    param($sender, $eventData)
    if (-not $eventData.Target -or $eventData.Target -eq 'TaskScreen') {
        $script:taskScreenEvents += "Refresh requested"
        Write-Host "  [TaskScreen] Refreshing task list..." -ForegroundColor Cyan
    }
})

$tasksSub2 = $eventBus.Subscribe([EventNames]::ProjectDeleted, {
    param($sender, $eventData)
    $script:taskScreenEvents += "Project deleted: $($eventData.ProjectId)"
    Write-Host "  [TaskScreen] Removing tasks for deleted project $($eventData.ProjectId)" -ForegroundColor Red
})

# MainScreen simulation
$mainScreenEvents = @()
$mainSub = $eventBus.Subscribe([EventNames]::DataChanged, {
    param($sender, $eventData)
    $script:mainScreenEvents += "Data changed: $($eventData.Type)"
    Write-Host "  [MainScreen] Data changed notification: $($eventData.Type)" -ForegroundColor Magenta
})

Write-Host "Subscriptions set up" -ForegroundColor Green
Write-Host ""

# Test scenarios
Write-Host "Test 1: Global Refresh Request" -ForegroundColor Cyan
Write-Host "------------------------------" -ForegroundColor DarkGray
$eventBus.Publish([EventNames]::RefreshRequested, @{})
Write-Host ""

Write-Host "Test 2: Targeted Refresh Request" -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor DarkGray
$eventBus.Publish([EventNames]::RefreshRequested, @{ Target = 'TaskScreen' })
Write-Host ""

Write-Host "Test 3: Configuration Change" -ForegroundColor Cyan
Write-Host "----------------------------" -ForegroundColor DarkGray
$eventBus.Publish([EventNames]::ConfigChanged, @{
    Path = "ui.projects.showCompleted"
    OldValue = $true
    NewValue = $false
    Category = "ui.projects"
})
Write-Host ""

Write-Host "Test 4: Cascading Events (Project Deletion)" -ForegroundColor Cyan
Write-Host "-------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Deleting project triggers:" -ForegroundColor White
$eventBus.Publish([EventNames]::ProjectDeleted, @{ ProjectId = 123 })
$eventBus.Publish([EventNames]::DataChanged, @{ Type = "Projects"; Action = "Delete" })
Write-Host ""

Write-Host "Test 5: Dynamic Command Registration" -ForegroundColor Cyan
Write-Host "------------------------------------" -ForegroundColor DarkGray
$commandRegistered = $false
$cmdSub = $eventBus.Subscribe([EventNames]::CommandRegistered, {
    param($sender, $eventData)
    $script:commandRegistered = $true
    Write-Host "  [CommandPalette] New command registered: $($eventData.Name)" -ForegroundColor Green
})

# Simulate a screen registering a command
[CommandRegistration]::RegisterCommand(
    "refresh all",
    "Refresh all screens",
    {
        Write-Host "    Executing: Refresh all screens" -ForegroundColor Yellow
        $eventBus = $global:ServiceContainer.GetService('EventBus')
        $eventBus.Publish([EventNames]::RefreshRequested, @{})
    }
)
Write-Host ""

# Summary
Write-Host "Event Summary" -ForegroundColor Cyan
Write-Host "-------------" -ForegroundColor DarkGray
Write-Host "  ProjectsScreen received: $($projectsScreenEvents.Count) events" -ForegroundColor Gray
Write-Host "  TaskScreen received: $($taskScreenEvents.Count) events" -ForegroundColor Gray
Write-Host "  MainScreen received: $($mainScreenEvents.Count) events" -ForegroundColor Gray
Write-Host "  Command registered: $commandRegistered" -ForegroundColor Gray
Write-Host ""

# Show event bus statistics
$info = $eventBus.GetEventInfo()
Write-Host "EventBus Statistics" -ForegroundColor Cyan
Write-Host "-------------------" -ForegroundColor DarkGray
Write-Host "  Total handlers: $($info.TotalHandlers)" -ForegroundColor Yellow
Write-Host "  Active event types: $($info.RegisteredEvents.Count)" -ForegroundColor Yellow
Write-Host ""

Write-Host "Cross-screen communication test completed!" -ForegroundColor Green

# Cleanup
$logger.Cleanup()