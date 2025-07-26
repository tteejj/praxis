#!/usr/bin/env pwsh

# Test VisualMacroFactoryScreen initialization
param([switch]$LoadOnly)

# Load necessary components
. "$PSScriptRoot/Core/StringCache.ps1"
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Core/ServiceContainer.ps1"
. "$PSScriptRoot/Core/StringBuilderPool.ps1"

# Services needed for initialization
. "$PSScriptRoot/Services/Logger.ps1"
. "$PSScriptRoot/Services/EventBus.ps1"
. "$PSScriptRoot/Services/ThemeManager.ps1"
. "$PSScriptRoot/Services/ShortcutManager.ps1"
. "$PSScriptRoot/Services/CommandService.ps1"
. "$PSScriptRoot/Services/FunctionRegistry.ps1"
. "$PSScriptRoot/Services/MacroContextManager.ps1"

# Base classes
. "$PSScriptRoot/Base/UIElement.ps1"
. "$PSScriptRoot/Base/Container.ps1"
. "$PSScriptRoot/Base/Screen.ps1"
. "$PSScriptRoot/Base/BaseModel.ps1"

# Models
. "$PSScriptRoot/Models/BaseAction.ps1"
. "$PSScriptRoot/Models/Command.ps1"

# Actions
. "$PSScriptRoot/Actions/CustomIdeaCommandAction.ps1"
. "$PSScriptRoot/Actions/SummarizationAction.ps1"
. "$PSScriptRoot/Actions/AppendFieldAction.ps1"
. "$PSScriptRoot/Actions/ExportToExcelAction.ps1"

# Components
. "$PSScriptRoot/Components/SearchableListBox.ps1"
. "$PSScriptRoot/Components/DataGrid.ps1"

# VisualMacroFactoryScreen
. "$PSScriptRoot/Screens/VisualMacroFactoryScreen.ps1"

Write-Host "Testing VisualMacroFactoryScreen initialization..." -ForegroundColor Green

# Initialize global ServiceContainer
$global:ServiceContainer = [ServiceContainer]::new()

# Create required services
$logger = [Logger]::new()
$global:ServiceContainer.Register("Logger", $logger)

$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("EventBus", $eventBus)

$shortcutManager = [ShortcutManager]::new()
$shortcutManager.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("ShortcutManager", $shortcutManager)

$commandService = [CommandService]::new()
$global:ServiceContainer.Register("CommandService", $commandService)

try {
    Write-Host "Creating VisualMacroFactoryScreen..." -ForegroundColor Yellow
    $screen = [VisualMacroFactoryScreen]::new()
    Write-Host "✓ VisualMacroFactoryScreen created successfully" -ForegroundColor Green
    
    Write-Host "Initializing VisualMacroFactoryScreen..." -ForegroundColor Yellow
    $screen.Initialize($global:ServiceContainer)
    Write-Host "✓ VisualMacroFactoryScreen initialized successfully" -ForegroundColor Green
    
    Write-Host "Checking AvailableActions count: $($screen.AvailableActions.Count)" -ForegroundColor Cyan
    
    if ($screen.AvailableActions.Count -gt 0) {
        Write-Host "✓ Actions loaded successfully" -ForegroundColor Green
        foreach ($action in $screen.AvailableActions) {
            Write-Host "  - $($action.Name)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "✗ No actions loaded!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "✗ VisualMacroFactoryScreen failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nVisualMacroFactoryScreen test completed!" -ForegroundColor Cyan