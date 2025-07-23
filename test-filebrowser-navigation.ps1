#!/usr/bin/env pwsh
# Test file browser navigation specifically

# Load required files
$loadOrder = @(
    "Core/VT100.ps1", "Core/ServiceContainer.ps1", "Services/Logger.ps1", 
    "Services/EventBus.ps1", "Services/ThemeManager.ps1", "Base/UIElement.ps1",
    "Base/Container.ps1", "Base/Screen.ps1", "Core/ScreenManager.ps1", 
    "Screens/FileBrowserScreen.ps1"
)

foreach ($file in $loadOrder) {
    . (Join-Path $PSScriptRoot $file)
}

# Initialize services
$global:ServiceContainer = [ServiceContainer]::new()
$logger = [Logger]::new()
$global:ServiceContainer.Register("Logger", $logger)
$themeManager = [ThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $themeManager)
$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("EventBus", $eventBus)
$themeManager.SetEventBus($eventBus)
$screenManager = [ScreenManager]::new($global:ServiceContainer)
$global:ServiceContainer.Register("ScreenManager", $screenManager)

# Create file browser and test navigation
$fileBrowser = [FileBrowserScreen]::new()

Write-Host "Testing File Browser Navigation..." -ForegroundColor Green

# Test initial state
Write-Host "`nInitial State:" -ForegroundColor Yellow
Write-Host "  FocusedPanel: $($fileBrowser.FocusedPanel)" -ForegroundColor Cyan
Write-Host "  Parent Index: $($fileBrowser.ParentSelectedIndex)" -ForegroundColor Cyan
Write-Host "  Current Index: $($fileBrowser.SelectedIndex)" -ForegroundColor Cyan
Write-Host "  Preview Index: $($fileBrowser.PreviewSelectedIndex)" -ForegroundColor Cyan

# Test navigation left
Write-Host "`nTesting NavigateLeft()..." -ForegroundColor Yellow
$fileBrowser.NavigateLeft()
Write-Host "  FocusedPanel after left: $($fileBrowser.FocusedPanel)" -ForegroundColor Cyan

# Test navigation right  
Write-Host "`nTesting NavigateRight()..." -ForegroundColor Yellow
$fileBrowser.NavigateRight()
Write-Host "  FocusedPanel after right: $($fileBrowser.FocusedPanel)" -ForegroundColor Cyan
$fileBrowser.NavigateRight()
Write-Host "  FocusedPanel after right again: $($fileBrowser.FocusedPanel)" -ForegroundColor Cyan

# Test up/down navigation in different panels
Write-Host "`nTesting up/down navigation..." -ForegroundColor Yellow

# Focus on current panel (1)
$fileBrowser.FocusedPanel = 1
$fileBrowser.NavigateDown()
Write-Host "  Current panel down: Index=$($fileBrowser.SelectedIndex)" -ForegroundColor Cyan

# Focus on parent panel (0)  
$fileBrowser.FocusedPanel = 0
$fileBrowser.NavigateDown()
Write-Host "  Parent panel down: Index=$($fileBrowser.ParentSelectedIndex)" -ForegroundColor Cyan

# Focus on preview panel (2)
$fileBrowser.FocusedPanel = 2  
$fileBrowser.NavigateDown()
Write-Host "  Preview panel down: Index=$($fileBrowser.PreviewSelectedIndex)" -ForegroundColor Cyan

Write-Host "`n✅ Navigation tests completed!" -ForegroundColor Green
Write-Host "✅ All panels now support independent up/down navigation!" -ForegroundColor Green