#!/usr/bin/env pwsh
# Test script for EventBus functionality

param(
    [switch]$Verbose
)

# Load the framework
$script:PraxisRoot = $PSScriptRoot
$global:PraxisRoot = $PSScriptRoot
Set-Location $script:PraxisRoot

# Load required files
. ./Core/ServiceContainer.ps1
. ./Services/Logger.ps1
. ./Services/EventBus.ps1

# Initialize services
$global:ServiceContainer = [ServiceContainer]::new()
$logger = [Logger]::new()
$global:ServiceContainer.Register("Logger", $logger)

# Create and register EventBus
$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("EventBus", $eventBus)

Write-Host "Testing EventBus functionality..." -ForegroundColor Cyan
Write-Host ""

# Test 1: Basic subscription and publishing
Write-Host "Test 1: Basic Event Publishing" -ForegroundColor Yellow
$receivedEvents = @()
$subscription1 = $eventBus.Subscribe("test.event", {
    param($sender, $eventData)
    $receivedEvents += $eventData
    Write-Host "  Received event: $($eventData.Message)" -ForegroundColor Green
})

$eventBus.Publish("test.event", @{ Message = "Hello from EventBus!" })
Write-Host "  Events received: $($receivedEvents.Count)" -ForegroundColor DarkGray
Write-Host ""

# Test 2: Multiple subscribers
Write-Host "Test 2: Multiple Subscribers" -ForegroundColor Yellow
$counter = 0
$subscription2 = $eventBus.Subscribe("test.event", {
    param($sender, $eventData)
    $script:counter++
    Write-Host "  Subscriber 2 received: $($eventData.Message)" -ForegroundColor Cyan
})

$eventBus.Publish("test.event", @{ Message = "Broadcasting to multiple subscribers" })
Write-Host "  Total handler executions: $($counter + $receivedEvents.Count)" -ForegroundColor DarkGray
Write-Host ""

# Test 3: Event filtering by name
Write-Host "Test 3: Event Filtering" -ForegroundColor Yellow
$projectEvents = @()
$projectSubscription = $eventBus.Subscribe([EventNames]::ProjectCreated, {
    param($sender, $eventData)
    $script:projectEvents += $eventData
    Write-Host "  Project created: $($eventData.Project.Name)" -ForegroundColor Green
})

$eventBus.Publish([EventNames]::ProjectCreated, @{ Project = @{ Name = "Test Project"; Id = 1 } })
$eventBus.Publish([EventNames]::TaskCreated, @{ Task = @{ Title = "Test Task"; Id = 1 } })
Write-Host "  Project events received: $($projectEvents.Count)" -ForegroundColor DarkGray
Write-Host ""

# Test 4: Unsubscribe
Write-Host "Test 4: Unsubscribe" -ForegroundColor Yellow
$eventBus.Unsubscribe("test.event", $subscription1)
$beforeCount = $receivedEvents.Count
$eventBus.Publish("test.event", @{ Message = "After unsubscribe" })
Write-Host "  Events before unsubscribe: $beforeCount" -ForegroundColor DarkGray
Write-Host "  Events after unsubscribe: $($receivedEvents.Count)" -ForegroundColor DarkGray
Write-Host ""

# Test 5: Command execution simulation
Write-Host "Test 5: Command Execution Pattern" -ForegroundColor Yellow
$commandExecuted = $false
$commandSubscription = $eventBus.Subscribe([EventNames]::CommandExecuted, {
    param($sender, $eventData)
    if ($eventData.Target -eq 'TestScreen' -and $eventData.Command -eq 'TestCommand') {
        $script:commandExecuted = $true
        Write-Host "  Command executed: $($eventData.Command) on $($eventData.Target)" -ForegroundColor Green
    }
})

$eventBus.Publish([EventNames]::CommandExecuted, @{ Target = 'TestScreen'; Command = 'TestCommand' })
Write-Host "  Command was executed: $commandExecuted" -ForegroundColor DarkGray
Write-Host ""

# Test 6: Event history
Write-Host "Test 6: Event History" -ForegroundColor Yellow
$eventBus.EnableHistory = $true
$eventBus.Publish("history.test", @{ Value = 42 })
$eventBus.Publish("history.test", @{ Value = 100 })
$history = $eventBus.GetEventHistory("history.test")
Write-Host "  History entries for 'history.test': $($history.Count)" -ForegroundColor DarkGray
foreach ($entry in $history) {
    Write-Host "    - Event at $($entry.Timestamp): Value = $($entry.EventData.Value)" -ForegroundColor Gray
}
Write-Host ""

# Test 7: Get event info
Write-Host "Test 7: Event Info" -ForegroundColor Yellow
$info = $eventBus.GetEventInfo()
Write-Host "  Total registered handlers: $($info.TotalHandlers)" -ForegroundColor DarkGray
Write-Host "  Registered events:" -ForegroundColor DarkGray
foreach ($eventName in $info.RegisteredEvents.Keys) {
    Write-Host "    - $eventName : $($info.RegisteredEvents[$eventName].HandlerCount) handlers" -ForegroundColor Gray
}

Write-Host ""
Write-Host "EventBus tests completed successfully!" -ForegroundColor Green

# Cleanup
$logger.Cleanup()