#!/usr/bin/env pwsh
# Simple test to see if EventNames is available

# Load EventBus first
. ./Services/EventBus.ps1

# Check if EventNames is available
Write-Host "EventNames type: $([EventNames])" -ForegroundColor Cyan
Write-Host "CommandExecuted value: $([EventNames]::CommandExecuted)" -ForegroundColor Green

# Now test the ShortcutManager
. ./Core/ServiceContainer.ps1
. ./Services/Logger.ps1
. ./Services/ShortcutManager.ps1

# Quick test
$global:PraxisDebug = $true
$container = [ServiceContainer]::new()
$logger = [Logger]::new()
$container.Register("Logger", $logger)

$eventBus = [EventBus]::new()
$eventBus.Initialize($container)
$container.Register("EventBus", $eventBus)

$shortcutManager = [ShortcutManager]::new()
$shortcutManager.Initialize($container)

Write-Host "`nShortcutManager initialized" -ForegroundColor Green
Write-Host "EventBus: $($shortcutManager.EventBus)" -ForegroundColor Cyan
Write-Host "Logger: $($shortcutManager.Logger)" -ForegroundColor Cyan