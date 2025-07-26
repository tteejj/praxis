#!/usr/bin/env pwsh

# Debug VisualMacroFactoryScreen initialization using the proper load order from Start.ps1
param([switch]$LoadOnly)

# Load order from Start.ps1
$loadOrder = @(
    "Core/StringCache.ps1"
    "Core/VT100.ps1"
    "Core/ServiceContainer.ps1"
    "Core/StringBuilderPool.ps1"
    "Services/Logger.ps1"
    "Services/EventBus.ps1"
    "Services/ThemeManager.ps1"
    "Base/UIElement.ps1"
    "Base/Container.ps1"
    "Base/Screen.ps1"
    "Base/BaseModel.ps1"
    "Services/ShortcutManager.ps1"
    "Models/Command.ps1"
    "Models/BaseAction.ps1"
    "Actions/CustomIdeaCommandAction.ps1"
    "Actions/SummarizationAction.ps1"
    "Actions/AppendFieldAction.ps1"
    "Actions/ExportToExcelAction.ps1"
    "Services/CommandService.ps1"
    "Services/FunctionRegistry.ps1"
    "Services/MacroContextManager.ps1"
    "Components/ListBox.ps1"
    "Components/SearchableListBox.ps1"
    "Components/DataGrid.ps1"
    "Screens/VisualMacroFactoryScreen.ps1"
)

Write-Host "Loading components for VisualMacroFactoryScreen test..." -ForegroundColor Cyan

foreach ($file in $loadOrder) {
    $path = Join-Path $PSScriptRoot $file
    if (Test-Path $path) {
        try {
            . $path
            Write-Host "  ✓ $file" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ $file - $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  ✗ $file - File not found" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`nInitializing services..." -ForegroundColor Cyan

# Set global variables that services need
$global:PraxisRoot = $PSScriptRoot

# Initialize global ServiceContainer
$global:ServiceContainer = [ServiceContainer]::new()

# Create services in proper order
$logger = [Logger]::new()
$global:ServiceContainer.Register("Logger", $logger)

$themeManager = [ThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $themeManager)

$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("EventBus", $eventBus)

$shortcutManager = [ShortcutManager]::new()
$shortcutManager.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("ShortcutManager", $shortcutManager)

$commandService = [CommandService]::new()
$global:ServiceContainer.Register("CommandService", $commandService)

Write-Host "`nTesting VisualMacroFactoryScreen..." -ForegroundColor Green

try {
    Write-Host "Creating VisualMacroFactoryScreen..." -ForegroundColor Yellow
    $screen = [VisualMacroFactoryScreen]::new()
    Write-Host "✓ Constructor completed" -ForegroundColor Green
    
    Write-Host "Available Actions before init: $($screen.AvailableActions.Count)" -ForegroundColor Cyan
    
    Write-Host "Calling Initialize..." -ForegroundColor Yellow
    $screen.Initialize($global:ServiceContainer)
    Write-Host "✓ Initialize completed" -ForegroundColor Green
    
    Write-Host "Available Actions after init: $($screen.AvailableActions.Count)" -ForegroundColor Cyan
    
    if ($screen.AvailableActions.Count -gt 0) {
        Write-Host "✓ Actions loaded successfully:" -ForegroundColor Green
        foreach ($action in $screen.AvailableActions) {
            Write-Host "  - $($action.Name) [$($action.GetType().Name)]" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "✗ No actions loaded - investigating LoadAvailableActions..." -ForegroundColor Red
        
        # Test action creation manually
        Write-Host "Testing manual action creation:" -ForegroundColor Yellow
        try {
            $testAction = [SummarizationAction]::new()
            Write-Host "  ✓ SummarizationAction: $($testAction.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ SummarizationAction failed: $_" -ForegroundColor Red
        }
    }
    
    # Check if shortcuts were registered
    Write-Host "Checking shortcut registration..." -ForegroundColor Yellow
    $shortcuts = $shortcutManager.GetShortcuts([ShortcutScope]::Screen, "VisualMacroFactoryScreen")
    Write-Host "Registered shortcuts: $($shortcuts.Count)" -ForegroundColor Cyan
    foreach ($shortcut in $shortcuts) {
        Write-Host "  - $($shortcut.Id): $($shortcut.GetDisplayText())" -ForegroundColor DarkGray
    }
    
} catch {
    Write-Host "✗ Test failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Cyan