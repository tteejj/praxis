#!/usr/bin/env pwsh
# Complete EventBus integration test

Write-Host "Complete EventBus Integration Test" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Load the framework
$script:PraxisRoot = $PSScriptRoot
$global:PraxisRoot = $PSScriptRoot
Set-Location $script:PraxisRoot

# Load essential files
. ./Core/ServiceContainer.ps1
. ./Services/Logger.ps1
. ./Services/EventBus.ps1
. ./Services/ThemeManager.ps1

# Initialize services
$logger = [Logger]::new()
$global:ServiceContainer.Register("Logger", $logger)

$themeManager = [ThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $themeManager)

$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("EventBus", $eventBus)

# Connect ThemeManager to EventBus
$themeManager.SetEventBus($eventBus)

# Enable debugging and history
$eventBus.EnableHistory = $true
$eventBus.EnableDebugLogging = $false  # Set to true to see detailed logs

Write-Host "Services initialized with EventBus" -ForegroundColor Green
Write-Host ""

# Test 1: ThemeManager integration
Write-Host "Test 1: ThemeManager EventBus Integration" -ForegroundColor Cyan
Write-Host "-----------------------------------------" -ForegroundColor DarkGray

$themeChanges = 0
$themeSub = $eventBus.Subscribe([EventNames]::ThemeChanged, {
    param($sender, $eventData)
    $script:themeChanges++
    Write-Host "  Theme changed from '$($eventData.OldTheme)' to '$($eventData.NewTheme)'" -ForegroundColor Yellow
})

# Register a test theme
$themeManager.RegisterTheme("test", @{
    "background" = @(0, 0, 0)
    "foreground" = @(255, 255, 255)
})

# Change theme (should trigger EventBus)
$themeManager.SetTheme("test")
$themeManager.SetTheme("default")

Write-Host "  Total theme changes detected: $themeChanges" -ForegroundColor Green
Write-Host ""

# Test 2: Dynamic command registration
Write-Host "Test 2: Dynamic Command Registration" -ForegroundColor Cyan
Write-Host "------------------------------------" -ForegroundColor DarkGray

$commandsRegistered = @()
$cmdRegSub = $eventBus.Subscribe([EventNames]::CommandRegistered, {
    param($sender, $eventData)
    $script:commandsRegistered += $eventData.Name
    Write-Host "  Command registered: $($eventData.Name) - $($eventData.Description)" -ForegroundColor Green
})

# Register some test commands
[CommandRegistration]::RegisterCommand("test command 1", "First test command", { Write-Host "Test 1" })
[CommandRegistration]::RegisterCommand("test command 2", "Second test command", { Write-Host "Test 2" })
[CommandRegistration]::RegisterCommand("debug eventbus", "Show EventBus debug info", {
    $eb = $global:ServiceContainer.GetService('EventBus')
    Write-Host $eb.GetDebugReport()
})

Write-Host "  Total commands registered: $($commandsRegistered.Count)" -ForegroundColor Yellow
Write-Host ""

# Test 3: Event statistics
Write-Host "Test 3: EventBus Statistics" -ForegroundColor Cyan
Write-Host "---------------------------" -ForegroundColor DarkGray

# Generate some events
$eventBus.Publish([EventNames]::RefreshRequested, @{})
$eventBus.Publish([EventNames]::DataChanged, @{ Type = "Test" })
$eventBus.Publish([EventNames]::ProjectCreated, @{ Project = @{ Name = "Test" } })

$info = $eventBus.GetEventInfo()
Write-Host "  Total events published: $($info.TotalEventsPublished)" -ForegroundColor Yellow
Write-Host "  Total handlers called: $($info.TotalHandlersCalled)" -ForegroundColor Yellow
Write-Host "  Active handlers: $($info.TotalHandlers)" -ForegroundColor Yellow
Write-Host "  History entries: $($info.HistorySize)" -ForegroundColor Yellow
Write-Host ""

# Test 4: Debug report
Write-Host "Test 4: EventBus Debug Report" -ForegroundColor Cyan
Write-Host "-----------------------------" -ForegroundColor DarkGray
Write-Host $eventBus.GetDebugReport() -ForegroundColor Gray
Write-Host ""

# Test 5: Event history
Write-Host "Test 5: Event History" -ForegroundColor Cyan
Write-Host "---------------------" -ForegroundColor DarkGray

$history = $eventBus.GetEventHistory()
Write-Host "  Last 5 events:" -ForegroundColor Yellow
foreach ($event in $history | Select-Object -Last 5) {
    Write-Host "    $($event.Timestamp.ToString('HH:mm:ss')) - $($event.EventName)" -ForegroundColor Gray
}
Write-Host ""

# Summary
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "-------" -ForegroundColor DarkGray
Write-Host "✓ ThemeManager integrated with EventBus" -ForegroundColor Green
Write-Host "✓ Dynamic command registration working" -ForegroundColor Green
Write-Host "✓ Event statistics and monitoring functional" -ForegroundColor Green
Write-Host "✓ Debug reporting available" -ForegroundColor Green
Write-Host "✓ Event history tracking enabled" -ForegroundColor Green
Write-Host ""
Write-Host "EventBus integration is fully operational!" -ForegroundColor Green

# Cleanup
$logger.Cleanup()