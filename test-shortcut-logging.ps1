#!/usr/bin/env pwsh
# Test to verify ShortcutManager logging issues

Write-Host "Testing ShortcutManager Logging..." -ForegroundColor Cyan

# First, let's check if Write-Host debug output is being cleared
Write-Host "[TEST] This is a test debug message" -ForegroundColor Yellow
Start-Sleep -Milliseconds 500

# Load just the necessary components
$global:PraxisRoot = (Get-Location).Path

# Load Logger first
. "./Services/Logger.ps1"
$logger = [Logger]::new()
$logger.MinimumLevel = "Debug"  # Force debug level
$global:Logger = $logger

Write-Host "Logger initialized at: $($logger.LogPath)" -ForegroundColor Green
Write-Host "Logger MinimumLevel: $($logger.MinimumLevel)" -ForegroundColor Green

# Test logger directly
$logger.Debug("TEST: Direct logger debug call")
$logger.Info("TEST: Direct logger info call")
$logger.Flush()  # Force flush

# Check if it was written
Start-Sleep -Milliseconds 100
$logContent = Get-Content $logger.LogPath -Tail 10 | Where-Object { $_ -match "TEST:" }
if ($logContent) {
    Write-Host "Logger is working. Found entries:" -ForegroundColor Green
    $logContent | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} else {
    Write-Host "Logger NOT working - no test entries found!" -ForegroundColor Red
}

# Now test ShortcutManager logging
Write-Host "`nTesting ShortcutManager with Logger..." -ForegroundColor Cyan

# Load dependencies
. "./Core/ServiceContainer.ps1"
. "./Services/EventBus.ps1"
. "./Services/ShortcutManager.ps1"

# Create service container
$container = [ServiceContainer]::new()
$container.Register("Logger", $logger)

# Create EventBus
$eventBus = [EventBus]::new()
$eventBus.Initialize($container)
$container.Register("EventBus", $eventBus)

# Create ShortcutManager
$sm = [ShortcutManager]::new()
$sm.Initialize($container)

Write-Host "ShortcutManager initialized" -ForegroundColor Green

# Test logging in PublishCommand
Write-Host "`nCalling PublishCommand directly..." -ForegroundColor Cyan
$sm.PublishCommand("TestCommand", "TestTarget")

# Flush logger
$logger.Flush()

# Check log again
Start-Sleep -Milliseconds 100
$smLogs = Get-Content $logger.LogPath -Tail 20 | Where-Object { $_ -match "ShortcutManager" }
if ($smLogs) {
    Write-Host "ShortcutManager logs found:" -ForegroundColor Green
    $smLogs | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} else {
    Write-Host "No ShortcutManager logs found!" -ForegroundColor Red
}

Write-Host "`nTest complete. Check log at: $($logger.LogPath)" -ForegroundColor Yellow