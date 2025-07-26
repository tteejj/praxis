#!/usr/bin/env pwsh

# Test SearchableListBox with actual actions to isolate the issue
param([switch]$LoadOnly)

# Load minimal components needed for test
. "$PSScriptRoot/Core/StringCache.ps1"
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Core/ServiceContainer.ps1"
. "$PSScriptRoot/Services/Logger.ps1"
. "$PSScriptRoot/Services/EventBus.ps1"
. "$PSScriptRoot/Services/ThemeManager.ps1"
. "$PSScriptRoot/Base/UIElement.ps1"
. "$PSScriptRoot/Base/Container.ps1"
. "$PSScriptRoot/Models/BaseAction.ps1"
. "$PSScriptRoot/Actions/SummarizationAction.ps1"
. "$PSScriptRoot/Components/ListBox.ps1"
. "$PSScriptRoot/Components/SearchableListBox.ps1"

Write-Host "Testing SearchableListBox with actions..." -ForegroundColor Green

# Set up minimal services
$global:PraxisRoot = $PSScriptRoot
$global:ServiceContainer = [ServiceContainer]::new()

$logger = [Logger]::new()
$global:ServiceContainer.Register("Logger", $logger)

$themeManager = [ThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $themeManager)

$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("EventBus", $eventBus)

try {
    Write-Host "Creating actions..." -ForegroundColor Yellow
    $actions = @()
    $actions += [SummarizationAction]::new()
    Write-Host "✓ Created $($actions.Count) actions" -ForegroundColor Green
    
    Write-Host "Testing action GetDisplayText..." -ForegroundColor Yellow
    foreach ($action in $actions) {
        $displayText = $action.GetDisplayText()
        Write-Host "  Action: $displayText" -ForegroundColor Cyan
    }
    
    Write-Host "Creating SearchableListBox..." -ForegroundColor Yellow
    $listBox = [SearchableListBox]::new()
    $listBox.Title = "Test Actions"
    
    # Set up item renderer
    $listBox.ItemRenderer = {
        param($action)
        if (-not $action) { return "" }
        return $action.GetDisplayText()
    }
    
    Write-Host "Initializing SearchableListBox..." -ForegroundColor Yellow
    $listBox.Initialize($global:ServiceContainer)
    
    Write-Host "Setting items on SearchableListBox..." -ForegroundColor Yellow
    $listBox.SetItems($actions)
    
    Write-Host "SearchableListBox state:" -ForegroundColor Cyan
    Write-Host "  Items.Count: $($listBox.Items.Count)" -ForegroundColor DarkGray
    Write-Host "  _filteredItems.Count: $($listBox._filteredItems.Count)" -ForegroundColor DarkGray
    Write-Host "  SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor DarkGray
    
    if ($listBox.Items.Count -gt 0) {
        Write-Host "✓ Items loaded successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ No items in SearchableListBox!" -ForegroundColor Red
    }
    
    if ($listBox._filteredItems.Count -gt 0) {
        Write-Host "✓ Filtered items available" -ForegroundColor Green
    } else {
        Write-Host "✗ No filtered items!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "✗ Test failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Cyan