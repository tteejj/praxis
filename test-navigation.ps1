#!/usr/bin/env pwsh
# Test script to debug navigation issues in TaskScreen

# Set up logging
$global:Logger = @{
    Debug = { param($msg) Write-Host "[DEBUG] $msg" -ForegroundColor Cyan }
    Info = { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Green }
    Error = { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
}

# Load the praxis framework
. "$PSScriptRoot/Start.ps1" -NoStart

# Create a simple test app that goes directly to TaskScreen
try {
    # Initialize services
    $global:ServiceContainer = [ServiceContainer]::new()
    
    # Register theme manager
    $themeManager = [ThemeManager]::new()
    $global:ServiceContainer.Register("ThemeManager", $themeManager)
    
    # Register logger
    $logger = [Logger]::new("$PSScriptRoot/_Logs/test-navigation.log")
    $global:ServiceContainer.Register("Logger", $logger)
    $global:Logger = $logger
    
    # Create screen manager
    $global:ScreenManager = [ScreenManager]::new($global:ServiceContainer)
    
    # Create and push TaskScreen directly
    $taskScreen = [TaskScreen]::new()
    $taskScreen.Initialize($global:ServiceContainer)
    
    Write-Host "Starting navigation test. Press Tab to switch between filter and list." -ForegroundColor Yellow
    Write-Host "Press 'q' to quit." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    
    # Push the screen and run
    $global:ScreenManager.Push($taskScreen)
    $global:ScreenManager.Run()
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
} finally {
    # Clean up
    [Console]::CursorVisible = $true
    Clear-Host
}