#!/usr/bin/env pwsh
# Test dialog focus issue

# Change to script directory
Set-Location $PSScriptRoot

# Load all required files in order
. ./Core/ServiceContainer.ps1
. ./Core/StringCache.ps1
. ./Core/StringBuilderPool.ps1
. ./Core/VT100.ps1
. ./Services/EventBus.ps1
. ./Services/ThemeManager.ps1
. ./Base/BorderStyle.ps1
. ./Base/UIElement.ps1
. ./Base/Container.ps1
. ./Base/FocusableComponent.ps1
. ./Base/Screen.ps1
. ./Base/BaseDialog.ps1
. ./Components/MinimalButton.ps1
. ./Components/MinimalTextBox.ps1
. ./Services/FocusManager.ps1
. ./Services/ProjectService.ps1  # Needed for dialog
. ./Models/Project.ps1
. ./Screens/NewProjectDialog.ps1

# Create service container
$global:ServiceContainer = [ServiceContainer]::new()

# Register services
$themeManager = [ThemeManager]::new()
$themeManager.LoadTheme("minimal")
$global:ServiceContainer.Register("ThemeManager", $themeManager)

$focusManager = [FocusManager]::new()
$focusManager.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("FocusManager", $focusManager)

$eventBus = [EventBus]::new()
$global:ServiceContainer.Register("EventBus", $eventBus)

# Create dialog
Write-Host "Creating dialog..." -ForegroundColor Yellow
$dialog = [NewProjectDialog]::new()
$dialog.Initialize($global:ServiceContainer)

# Set bounds (simulate screen size)
$dialog.SetBounds(0, 0, 120, 40)

# Activate (should focus first textbox)
Write-Host "Activating dialog..." -ForegroundColor Yellow
$dialog.OnActivated()

# Check focus
Write-Host "Checking focus status..." -ForegroundColor Yellow
$focused = $focusManager.GetFocused()
if ($focused) {
    Write-Host "Focused element: $($focused.GetType().Name)" -ForegroundColor Green
    Write-Host "Is MinimalTextBox: $($focused -is [MinimalTextBox])" -ForegroundColor Green
    Write-Host "IsFocused property: $($focused.IsFocused)" -ForegroundColor Green
} else {
    Write-Host "No element is focused!" -ForegroundColor Red
}

# Check registered focusables
Write-Host "`nRegistered focusable elements:" -ForegroundColor Yellow
$focusables = $focusManager.GetFocusableChildren($dialog)
Write-Host "Count: $($focusables.Count)" -ForegroundColor Cyan
foreach ($f in $focusables) {
    Write-Host "  - $($f.GetType().Name) (IsFocused: $($f.IsFocused))" -ForegroundColor Gray
}

# Test Tab navigation
Write-Host "`nTesting Tab navigation..." -ForegroundColor Yellow
$tabKey = [System.ConsoleKeyInfo]::new([char]9, [System.ConsoleKey]::Tab, $false, $false, $false)
$handled = $dialog.HandleInput($tabKey)
Write-Host "Tab handled: $handled" -ForegroundColor Cyan

$focused = $focusManager.GetFocused()
if ($focused) {
    Write-Host "Now focused: $($focused.GetType().Name)" -ForegroundColor Green
} else {
    Write-Host "Still no focus!" -ForegroundColor Red
}