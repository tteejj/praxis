#!/usr/bin/env pwsh

# Minimal test to find where startup freezes

Write-Host "Starting minimal test..." -ForegroundColor Cyan

# Test basic loading first
Write-Host "1. Loading core VT100..." -ForegroundColor Yellow
. "./Core/VT100.ps1"
Write-Host "  VT100 loaded OK" -ForegroundColor Green

Write-Host "2. Loading ServiceContainer..." -ForegroundColor Yellow  
. "./Core/ServiceContainer.ps1"
Write-Host "  ServiceContainer loaded OK" -ForegroundColor Green

Write-Host "3. Loading Logger..." -ForegroundColor Yellow
. "./Services/Logger.ps1"
Write-Host "  Logger loaded OK" -ForegroundColor Green

Write-Host "4. Loading EventBus..." -ForegroundColor Yellow
. "./Services/EventBus.ps1"
Write-Host "  EventBus loaded OK" -ForegroundColor Green

Write-Host "5. Loading ThemeManager..." -ForegroundColor Yellow
. "./Services/ThemeManager.ps1"
Write-Host "  ThemeManager loaded OK" -ForegroundColor Green

Write-Host "6. Creating service container..." -ForegroundColor Yellow
$global:ServiceContainer = [ServiceContainer]::new()
Write-Host "  Service container created OK" -ForegroundColor Green

Write-Host "7. Creating Logger..." -ForegroundColor Yellow
$logger = [Logger]::new()
$global:Logger = $logger
$global:ServiceContainer.Register("Logger", $logger)
Write-Host "  Logger created and registered OK" -ForegroundColor Green

Write-Host "8. Creating EventBus..." -ForegroundColor Yellow
$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("EventBus", $eventBus)
Write-Host "  EventBus created and registered OK" -ForegroundColor Green

Write-Host "9. First event subscription test..." -ForegroundColor Yellow
$handlerId = $eventBus.Subscribe("test.event", {
    param($sender, $eventData)
    Write-Host "Test event received!" -ForegroundColor Magenta
})
Write-Host "  Event subscription created: $handlerId" -ForegroundColor Green

Write-Host "10. All tests completed successfully!" -ForegroundColor Green
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")