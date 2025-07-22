#!/usr/bin/env pwsh
# PRAXIS - Performance-focused TUI Framework
# Entry point and bootstrapper

param(
    [switch]$Debug,
    [switch]$Performance,
    [string]$Theme = "default"
)

# Enable debug output if requested
if ($Debug) {
    $global:PraxisDebug = $true
}

# Ensure we're in the right directory
$script:PraxisRoot = $PSScriptRoot
$global:PraxisRoot = $PSScriptRoot
Set-Location $script:PraxisRoot

# Ensure data directory exists
$dataDir = Join-Path $script:PraxisRoot "_ProjectData"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

# Load order is critical for class inheritance
$loadOrder = @(
    # Core modules first
    "Core/VT100.ps1"
    "Core/ServiceContainer.ps1"
    
    # Services (needed by base classes)
    "Services/Logger.ps1"
    "Services/EventBus.ps1"
    "Services/ThemeManager.ps1"
    
    # Base classes
    "Base/UIElement.ps1"
    "Base/Container.ps1"
    "Base/Screen.ps1"
    
    # Models
    "Models/Project.ps1"
    "Models/Task.ps1"
    
    # Services
    "Services/ProjectService.ps1"
    "Services/TaskService.ps1"
    "Services/ConfigurationService.ps1"
    
    # Components
    "Components/ListBox.ps1"
    "Components/TextBox.ps1"
    "Components/Button.ps1"
    "Components/DataGrid.ps1"
    "Components/TabContainer.ps1"
    
    # Core systems
    "Core/ScreenManager.ps1"
    
    # Dialogs (must be loaded before screens that use them)
    "Screens/TextInputDialog.ps1",
    "Screens/NumberInputDialog.ps1",
    "Screens/ConfirmationDialog.ps1",
    "Screens/NewProjectDialog.ps1",
    "Screens/EditProjectDialog.ps1",
    "Screens/NewTaskDialog.ps1",
    "Screens/EditTaskDialog.ps1",
    "Screens/EventBusMonitor.ps1",
    
    # Screens (after dialogs they depend on)
    "Screens/TestScreen.ps1",
    "Screens/ProjectsScreen.ps1",
    "Screens/TaskScreen.ps1",
    "Screens/SettingsScreen.ps1",
    
    # CommandPalette (after screens it references)
    "Components/CommandPalette.ps1"
    
    # Main screen
    "Screens/MainScreen.ps1"
)

# Load all modules
Write-Host "Loading PRAXIS framework..." -ForegroundColor Cyan
foreach ($file in $loadOrder) {
    $path = Join-Path $script:PraxisRoot $file
    if (Test-Path $path) {
        try {
            . $path
            if ($Debug) {
                Write-Host "  ✓ $file" -ForegroundColor Green
            }
        } catch {
            Write-Host "  ✗ $file - $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  ✗ $file - File not found" -ForegroundColor Red
        exit 1
    }
}

# Initialize services
Write-Host "Initializing services..." -ForegroundColor Cyan

# Logger (first so other services can use it)
$logger = [Logger]::new()
$global:Logger = $logger
$global:ServiceContainer.Register("Logger", $logger)
if ($Debug) {
    Write-Host "  Logger created at: $($logger.LogPath)" -ForegroundColor DarkGray
}

# Theme manager
$themeManager = [ThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $themeManager)

# EventBus (after Logger and ThemeManager, before other services)
$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("EventBus", $eventBus)
if ($Debug) {
    Write-Host "  EventBus initialized" -ForegroundColor DarkGray
}

# Connect ThemeManager to EventBus
$themeManager.SetEventBus($eventBus)

# Project service
$projectService = [ProjectService]::new()
$global:ServiceContainer.Register("ProjectService", $projectService)

# Task service
$taskService = [TaskService]::new()
$global:ServiceContainer.Register("TaskService", $taskService)

# Configuration service
$configService = [ConfigurationService]::new()
$global:ServiceContainer.Register("ConfigurationService", $configService)

# Screen manager
$screenManager = [ScreenManager]::new($global:ServiceContainer)
$global:ScreenManager = $screenManager
$global:ServiceContainer.Register("ScreenManager", $screenManager)

# Create main screen with tabs
Write-Host "Creating main interface..." -ForegroundColor Cyan

# Create and run main screen
if ($Debug) { Write-Host "  Creating MainScreen..." -ForegroundColor DarkGray }
$mainScreen = [MainScreen]::new()

if ($Debug) { Write-Host "  Pushing to ScreenManager..." -ForegroundColor DarkGray }
$screenManager.Push($mainScreen)

if ($Debug) { Write-Host "  Main screen initialized" -ForegroundColor DarkGray }

Write-Host "Starting PRAXIS..." -ForegroundColor Green
Write-Host "  • Press 1-3 to switch tabs" -ForegroundColor DarkGray
Write-Host "  • Press Ctrl+Tab to cycle tabs" -ForegroundColor DarkGray
Write-Host "  • Press / or : for command palette" -ForegroundColor DarkGray
Write-Host "  • Press Q or Escape to quit" -ForegroundColor DarkGray
Write-Host ""

# Run the application
try {
    $global:Logger.Info("Starting PRAXIS main loop")
    $screenManager.Run()
} catch {
    if ($global:Logger) {
        if ($_.Exception) {
            $global:Logger.LogException($_.Exception, "Fatal error in main loop")
        } else {
            $global:Logger.Error("Fatal error in main loop: $_")
        }
    }
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    if ($global:Logger) {
        Write-Host "`nCheck log file at: $($global:Logger.LogPath)" -ForegroundColor Yellow
    }
} finally {
    # Cleanup
    $global:Logger.Info("Shutting down PRAXIS")
    $global:Logger.Cleanup()
    $global:ServiceContainer.Cleanup()
    Write-Host "`nPRAXIS terminated." -ForegroundColor Cyan
}