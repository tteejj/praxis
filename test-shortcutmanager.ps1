#!/usr/bin/env pwsh
# Test ShortcutManager functionality

param(
    [switch]$Debug
)

# Set debug mode FIRST before anything else
if ($Debug) {
    $global:PraxisDebug = $true
    Write-Host "Debug mode enabled" -ForegroundColor Green
}

# Set up paths
$script:PraxisRoot = $PSScriptRoot
$global:PraxisRoot = $PSScriptRoot
Set-Location $script:PraxisRoot

# Load required files
. ./Core/ServiceContainer.ps1
. ./Services/Logger.ps1
. ./Services/EventBus.ps1
. ./Services/ShortcutManager.ps1

# Create services
$container = [ServiceContainer]::new()

# Create logger and verify debug mode
$logger = [Logger]::new()
$container.Register("Logger", $logger)
Write-Host "Logger MinimumLevel: $($logger.MinimumLevel)" -ForegroundColor Cyan

# Create EventBus
$eventBus = [EventBus]::new()
$eventBus.Initialize($container)
$container.Register("EventBus", $eventBus)

# Subscribe to CommandExecuted events
$eventBus.Subscribe([EventNames]::CommandExecuted, {
    param($data)
    Write-Host "Event received! Command: $($data.Command), Target: $($data.Target)" -ForegroundColor Yellow
})

# Create ShortcutManager
$shortcutManager = [ShortcutManager]::new()
$shortcutManager.Initialize($container)

Write-Host "`nTesting ShortcutManager:" -ForegroundColor Cyan

# Test 1: ProjectsScreen shortcut
Write-Host "`nTest 1: ProjectsScreen 'n' key" -ForegroundColor Green
$keyInfo = [System.ConsoleKeyInfo]::new('n', [System.ConsoleKey]::N, $false, $false, $false)
$result = $shortcutManager.HandleKeyPress($keyInfo, "ProjectsScreen", "")
Write-Host "Result: $result (should be True)" -ForegroundColor $(if ($result) { "Green" } else { "Red" })

# Test 2: TaskScreen shortcut
Write-Host "`nTest 2: TaskScreen 'e' key" -ForegroundColor Green
$keyInfo = [System.ConsoleKeyInfo]::new('e', [System.ConsoleKey]::E, $false, $false, $false)
$result = $shortcutManager.HandleKeyPress($keyInfo, "TaskScreen", "")
Write-Host "Result: $result (should be True)" -ForegroundColor $(if ($result) { "Green" } else { "Red" })

# Test 3: Invalid shortcut
Write-Host "`nTest 3: Invalid 'z' key on ProjectsScreen" -ForegroundColor Green
$keyInfo = [System.ConsoleKeyInfo]::new('z', [System.ConsoleKey]::Z, $false, $false, $false)
$result = $shortcutManager.HandleKeyPress($keyInfo, "ProjectsScreen", "")
Write-Host "Result: $result (should be False)" -ForegroundColor $(if (-not $result) { "Green" } else { "Red" })

# Test 4: CommandPalette context (should be ignored)
Write-Host "`nTest 4: Key press while CommandPalette is open" -ForegroundColor Green
$keyInfo = [System.ConsoleKeyInfo]::new('n', [System.ConsoleKey]::N, $false, $false, $false)
$result = $shortcutManager.HandleKeyPress($keyInfo, "ProjectsScreen", "CommandPalette")
Write-Host "Result: $result (should be False)" -ForegroundColor $(if (-not $result) { "Green" } else { "Red" })

# Flush logger
$logger.Flush()

Write-Host "`nCheck the log file at: $($logger.LogPath)" -ForegroundColor Cyan
Write-Host "Last 10 lines:" -ForegroundColor Cyan
Get-Content $logger.LogPath -Tail 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }