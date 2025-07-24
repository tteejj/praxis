#!/usr/bin/env pwsh
# Test to verify tab state vs what's displayed

# Load minimal framework
$global:PraxisRoot = $PSScriptRoot
Set-Location $global:PraxisRoot

# Load essential components
. "./Core/VT100.ps1"
. "./Core/ServiceContainer.ps1"
. "./Services/Logger.ps1"
. "./Services/ThemeManager.ps1"
. "./Services/EventBus.ps1"
. "./Base/UIElement.ps1"
. "./Base/Container.ps1"
. "./Base/Screen.ps1"
. "./Components/Button.ps1"
. "./Components/TabContainer.ps1"
. "./Screens/ProjectsScreen.ps1"
. "./Screens/TextEditorScreen.ps1"

# Initialize services
$global:ServiceContainer = [ServiceContainer]::new()
$logger = [Logger]::new()
$global:Logger = $logger
$global:ServiceContainer.Register("Logger", $logger)

$themeManager = [ThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $themeManager)

$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("EventBus", $eventBus)

Write-Host "=== Testing Tab State vs Display ===" -ForegroundColor Cyan

# Create TabContainer with 2 tabs
$tabContainer = [TabContainer]::new()
$tabContainer.Initialize($global:ServiceContainer)

$projectsScreen = [ProjectsScreen]::new()
$projectsScreen.Initialize($global:ServiceContainer)
$tabContainer.AddTab("Projects", $projectsScreen)

$textEditorScreen = [TextEditorScreen]::new()
$textEditorScreen.Initialize($global:ServiceContainer)
$tabContainer.AddTab("Editor", $textEditorScreen)

Write-Host "Initial state:" -ForegroundColor Yellow
Write-Host "  TabContainer.ActiveTabIndex: $($tabContainer.ActiveTabIndex)"
Write-Host "  Active tab title: $($tabContainer.GetActiveTab().Title)"
Write-Host "  Active tab content type: $($tabContainer.GetActiveTab().Content.GetType().Name)"

# Switch to Editor tab (index 1)
Write-Host "`nSwitching to Editor tab..." -ForegroundColor Yellow
$tabContainer.ActivateTab(1)

Write-Host "After switching to Editor:" -ForegroundColor Yellow
Write-Host "  TabContainer.ActiveTabIndex: $($tabContainer.ActiveTabIndex)"
Write-Host "  Active tab title: $($tabContainer.GetActiveTab().Title)"
Write-Host "  Active tab content type: $($tabContainer.GetActiveTab().Content.GetType().Name)"

# Now simulate the "1" key press issue
Write-Host "`nSimulating '1' key press..." -ForegroundColor Yellow
$key1 = [System.ConsoleKeyInfo]::new('1', [ConsoleKey]::D1, $false, $false, $false)

# First put TextEditor in command mode
$escapeKey = [System.ConsoleKeyInfo]::new([char]27, [ConsoleKey]::Escape, $false, $false, $false)
$handled = $tabContainer.HandleInput($escapeKey)
Write-Host "  Escape handled: $handled"
Write-Host "  TextEditor InTextMode: $($textEditorScreen.InTextMode)"

# Now try the "1" key
$handled = $tabContainer.HandleInput($key1)
Write-Host "  Key '1' handled: $handled"

Write-Host "`nAfter '1' key press:" -ForegroundColor Yellow
Write-Host "  TabContainer.ActiveTabIndex: $($tabContainer.ActiveTabIndex) (should be 0)"
Write-Host "  Active tab title: $($tabContainer.GetActiveTab().Title) (should be Projects)"
Write-Host "  Active tab content type: $($tabContainer.GetActiveTab().Content.GetType().Name) (should be ProjectsScreen)"

# Check children
Write-Host "`nTabContainer children:" -ForegroundColor Yellow
Write-Host "  Children.Count: $($tabContainer.Children.Count)"
for ($i = 0; $i -lt $tabContainer.Children.Count; $i++) {
    $child = $tabContainer.Children[$i]
    Write-Host "  Child $i`: $($child.GetType().Name)"
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Green