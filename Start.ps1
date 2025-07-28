#!/usr/bin/env pwsh
# PRAXIS - Performance-focused TUI Framework
# Entry point and bootstrapper

param(
    [switch]$Debug,
    [switch]$Performance,
    [string]$Theme = "default",
    [switch]$LoadOnly
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
    "Core/StringCache.ps1"
    "Core/VT100.ps1"
    "Core/ServiceContainer.ps1"
    "Core/StringBuilderPool.ps1"
    "Core/GapBuffer.ps1"
    "Core/DocumentBuffer.ps1"
    "Core/GapBufferDocumentBuffer.ps1"
    "Core/EditorCommands.ps1"
    
    # Services (needed by base classes)
    "Services/Logger.ps1"
    "Services/EventBus.ps1"
    "Services/ConfigurationService.ps1"
    "Services/ThemeManager.ps1"
    "Services/ThemeSystem.ps1"
    "Utils/ThemeBuilder.ps1"
    "Themes/ThemeSynthwave.ps1"
    
    # Base classes
    "Base/UIElement.ps1"
    "Base/Container.ps1"
    "Base/FocusableComponent.ps1"
    
    # Core UI systems (needed by components and screens)
    "Core/BorderStyle.ps1"
    "Core/KeyboardShortcuts.ps1"
    "Core/AnimationHelper.ps1"
    "Core/SpacingSystem.ps1"
    
    # HelpOverlay (after BorderStyle)
    "Screens/HelpOverlay.ps1"
    
    "Base/Screen.ps1"
    "Base/BaseModel.ps1"
    
    # Services that depend on base classes
    "Services/FocusManager.ps1"
    "Services/ShortcutManager.ps1"
    
    # Models
    "Models/Project.ps1"
    "Models/Task.ps1"
    "Models/Subtask.ps1"
    "Models/TimeEntry.ps1"
    "Models/TimeCode.ps1"
    "Models/Command.ps1"
    "Models/BaseAction.ps1"
    
    # Actions (after BaseAction)
    "Actions/CustomIdeaCommandAction.ps1"
    "Actions/SummarizationAction.ps1"
    "Actions/AppendFieldAction.ps1"
    "Actions/ExportToExcelAction.ps1"
    
    # Services
    "Services/ToastService.ps1"
    "Services/ProjectService.ps1"
    "Services/TaskService.ps1"
    "Services/SubtaskService.ps1"
    "Services/TimeTrackingService.ps1"
    "Services/CommandService.ps1"
    "Services/StateManager.ps1"
    "Services/FunctionRegistry.ps1"
    "Services/MacroContextManager.ps1"
    "Services/MacroService.ps1"
    "Services/BackupService.ps1"
    "Services/FileOperationService.ps1"
    
    # Components
    "Components/ListBox.ps1"
    "Components/TextBox.ps1"
    "Components/Button.ps1"
    "Components/MinimalButton.ps1"
    "Components/GradientButton.ps1"
    # "Components/GradientContainer.ps1"
    "Components/MinimalListBox.ps1"
    "Components/MinimalTextBox.ps1"
    "Components/MinimalDataGrid.ps1"
    "Components/MinimalStatusBar.ps1"
    "Components/MinimalModal.ps1"
    "Components/MinimalContextMenu.ps1"
    "Components/DataGrid.ps1"
    "Components/ProgressBar.ps1"
    "Components/FastFileTree.ps1"
    "Components/RangerFileTree.ps1"
    "Components/SearchableListBox.ps1"
    "Components/MultiSelectListBox.ps1"
    "Components/TabContainer.ps1"
    "Components/MinimalTabContainer.ps1"
    
    # Layout Components (NEW!)
    "Components/HorizontalSplit.ps1"
    "Components/VerticalSplit.ps1"
    "Components/GridPanel.ps1"
    "Components/DockPanel.ps1"
    
    # BaseDialog (after components are loaded)
    "Base/BaseDialog.ps1"
    
    # Dialogs (must be loaded before screens that use them)
    "Screens/FilePickerDialog.ps1",
    "Screens/TextInputDialog.ps1",
    "Screens/NumberInputDialog.ps1",
    "Screens/ConfirmationDialog.ps1",
    "Screens/NewProjectDialog.ps1",
    "Screens/EditProjectDialog.ps1",
    "Screens/NewTaskDialog.ps1",
    "Screens/EditTaskDialog.ps1",
    "Screens/SubtaskDialog.ps1",
    "Screens/TimeEntryDialog.ps1",
    "Screens/QuickTimeEntryDialog.ps1",
    "Screens/CommandEditDialog.ps1",
    "Screens/FindReplaceDialog.ps1",
    "Screens/FieldPickerDialog.ps1",
    "Screens/ScriptPreviewDialog.ps1",
    "Screens/ActionPropertiesDialog.ps1",
    "Screens/EventBusMonitor.ps1",
    "Screens/SelectionDialog.ps1",
    "Screens/ThemeEditorDialog.ps1",
    
    # Screens (after dialogs they depend on)
    "Screens/TestScreen.ps1",
    "Screens/ProjectDetailScreen.ps1",
    "Screens/ProjectsScreen.ps1",
    "Screens/TaskScreen.ps1",
    "Screens/DashboardScreen.ps1",
    "Screens/SettingsScreen.ps1",
    "Screens/FileBrowserScreen.ps1",
    "Screens/TextEditorScreenNew.ps1",
    "Screens/TimeEntryScreen.ps1",
    "Screens/CommandLibraryScreen.ps1",
    "Screens/VisualMacroFactoryScreen.ps1",
    "Screens/MinimalShowcaseScreen.ps1",
    "Screens/LayoutExamplesScreen.ps1",
    "Screens/KeyboardHelpOverlay.ps1",
    
    # Core systems (after KeyboardHelpOverlay)
    "Core/ScreenManager.ps1",
    
    # CommandPalette (after screens it references)
    "Components/CommandPalette.ps1",
    
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

# Theme manager - Use enhanced version with semantic colors
$themeManager = [EnhancedThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $themeManager)

# EventBus (after Logger and ThemeManager, before other services)
$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("EventBus", $eventBus)

# ShortcutManager
$shortcutManager = [ShortcutManager]::new()
$shortcutManager.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("ShortcutManager", $shortcutManager)
if ($Debug) {
    Write-Host "  EventBus initialized" -ForegroundColor DarkGray
}

# Connect ThemeManager to EventBus
$themeManager.SetEventBus($eventBus)

# NOW initialize synthwave themes - ThemeManager is registered and ready!
[ThemeSynthwave]::CreateSynthwave84()
[ThemeSynthwave]::CreateSynthwaveOutrun()

if ($global:Logger) {
    $allThemes = $themeManager.GetThemeNames()
    $global:Logger.Info("Start.ps1: Registered themes: $($allThemes -join ', ')")
}

# Subscribe to configuration changes
$eventBus.Subscribe([EventNames]::ConfigChanged, {
    param($sender, $eventData)
    
    # Handle theme changes
    if ($eventData.Path -eq "Theme.CurrentTheme") {
        $themeManager = $global:ServiceContainer.GetService("ThemeManager")
        if ($themeManager -and $eventData.NewValue) {
            # Theme change is already handled in SettingsScreen.ShowThemeSelectionDialog
            # This is just for any additional handling needed
        }
    }
    
    # Handle UI settings changes
    elseif ($eventData.Path -match "^UI\.") {
        # Force screen refresh for UI changes
        if ($global:ScreenManager) {
            $global:ScreenManager.Invalidate()
        }
    }
    
    # Log all config changes for debugging
    if ($global:Logger) {
        $global:Logger.Debug("Config changed: $($eventData.Path) = $($eventData.NewValue)")
    }
})

# FocusManager - Fast O(1) focus management
$focusManager = [FocusManager]::new()
$focusManager.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("FocusManager", $focusManager)
if ($Debug) {
    Write-Host "  FocusManager initialized" -ForegroundColor DarkGray
}

# KeyboardShortcutManager - Standardized keyboard shortcuts
$keyboardShortcutManager = [KeyboardShortcutManager]::new()
$keyboardShortcutManager.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("KeyboardShortcutManager", $keyboardShortcutManager)
if ($Debug) {
    Write-Host "  KeyboardShortcutManager initialized" -ForegroundColor DarkGray
}

# Configuration service - Needed by AnimationManager and other services
$configService = [ConfigurationService]::new()
$global:ServiceContainer.Register("ConfigurationService", $configService)
if ($Debug) {
    Write-Host "  ConfigurationService initialized" -ForegroundColor DarkGray
}

# AnimationManager - Smooth animations
$animationManager = [AnimationManager]::new()
$animationManager.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("AnimationManager", $animationManager)
if ($Debug) {
    Write-Host "  AnimationManager initialized" -ForegroundColor DarkGray
}

# ToastService - Notification system
$toastService = [ToastService]::new()
$toastService.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("ToastService", $toastService)
if ($Debug) {
    Write-Host "  ToastService initialized" -ForegroundColor DarkGray
}

# Project service
$projectService = [ProjectService]::new()
$global:ServiceContainer.Register("ProjectService", $projectService)

# Task service
$taskService = [TaskService]::new()
$global:ServiceContainer.Register("TaskService", $taskService)

# Subtask service
$subtaskService = [SubtaskService]::new()
$global:ServiceContainer.Register("SubtaskService", $subtaskService)
# Time tracking service
$timeTrackingService = [TimeTrackingService]::new()
$global:ServiceContainer.Register("TimeTrackingService", $timeTrackingService)

# Command service
$commandService = [CommandService]::new()
$global:ServiceContainer.Register("CommandService", $commandService)

# Macro service
$macroService = [MacroService]::new()
$global:ServiceContainer.Register("MacroService", $macroService)

# Backup service
$backupService = [BackupService]::new()
$global:ServiceContainer.Register("BackupService", $backupService)

# File operation service
$fileOperationService = [FileOperationService]::new()
$fileOperationService.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("FileOperationService", $fileOperationService)

# Synthwave themes already initialized after EventBus setup

# Apply theme from configuration
$currentTheme = $configService.Get("Theme.CurrentTheme", "matrix")
if ($themeManager._themes.ContainsKey($currentTheme)) {
    $themeManager.SetTheme($currentTheme)
} else {
    # Fallback to matrix theme if configured theme doesn't exist
    $themeManager.SetTheme("matrix")
}

# Update available themes in config to include synthwave
$availableThemes = @($themeManager.GetThemeNames())
$configService.Set("Theme.AvailableThemes", $availableThemes)

# State manager - high-performance centralized state
$stateManager = [StateManager]::new()
$stateManager.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("StateManager", $stateManager)

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

# Exit early if LoadOnly is requested
if ($LoadOnly) {
    Write-Host "Framework loaded successfully (LoadOnly mode)" -ForegroundColor Green
    return
}

Write-Host "Starting PRAXIS..." -ForegroundColor Green
Write-Host "  • Press 1-8 to switch tabs" -ForegroundColor DarkGray
Write-Host "  • Press Ctrl+Tab to cycle tabs" -ForegroundColor DarkGray
Write-Host "  • Press / or : for command palette" -ForegroundColor DarkGray
Write-Host "  • In Settings: Press T for quick theme selection" -ForegroundColor DarkGray
Write-Host "  • Press Ctrl+Q to quit" -ForegroundColor DarkGray
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
    $stateManager = $global:ServiceContainer.GetService("StateManager")
    if ($stateManager) {
        $stateManager.Cleanup()
    }
    $global:Logger.Cleanup()
    $global:ServiceContainer.Cleanup()
    Write-Host "`nPRAXIS terminated." -ForegroundColor Cyan
}