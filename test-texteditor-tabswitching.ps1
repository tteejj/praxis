#!/usr/bin/env pwsh
# Test TextEditor tab switching behavior

# Load the framework
$global:PraxisRoot = $PSScriptRoot
Set-Location $global:PraxisRoot

# Load essential components for testing
. "./Core/VT100.ps1"
. "./Core/ServiceContainer.ps1"
. "./Core/StringBuilderPool.ps1"
. "./Services/Logger.ps1"
. "./Services/EventBus.ps1"
. "./Services/ThemeManager.ps1"
. "./Base/UIElement.ps1"
. "./Base/Container.ps1"
. "./Base/Screen.ps1"
. "./Components/Button.ps1"
. "./Components/TabContainer.ps1"
. "./Screens/TextEditorScreen.ps1"

# Initialize minimal services
$global:ServiceContainer = [ServiceContainer]::new()
$logger = [Logger]::new()
$global:Logger = $logger
$global:ServiceContainer.Register("Logger", $logger)

$themeManager = [ThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $themeManager)

$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("EventBus", $eventBus)

# Create test scenario
Write-Host "=== Testing TextEditor Tab Switching ===" -ForegroundColor Cyan

# Create TabContainer with TextEditor
$tabContainer = [TabContainer]::new()
$tabContainer.Initialize($global:ServiceContainer)
$tabContainer.SetBounds(0, 0, 80, 24)

# Add a dummy first tab and TextEditor as second tab
$dummyScreen = [Screen]::new()
$dummyScreen.Title = "Dummy"
$dummyScreen.Initialize($global:ServiceContainer)
$tabContainer.AddTab("Dummy", $dummyScreen)

$textEditor = [TextEditorScreen]::new()
$textEditor.Initialize($global:ServiceContainer)
$tabContainer.AddTab("Editor", $textEditor)

# Activate the TextEditor tab (index 1)
$tabContainer.ActivateTab(1)

Write-Host "Initial state:" -ForegroundColor Yellow
Write-Host "  Active tab: $($tabContainer.ActiveTabIndex + 1) ($($tabContainer.GetActiveTab().Title))"
Write-Host "  TextEditor InTextMode: $($textEditor.InTextMode)"

# Test 1: In text mode, number key should be handled by TextEditor
Write-Host "`n=== Test 1: Text mode - number key should be handled by TextEditor ===" -ForegroundColor Yellow
$key1InTextMode = [System.ConsoleKeyInfo]::new('1', [ConsoleKey]::D1, $false, $false, $false)
$handled = $tabContainer.HandleInput($key1InTextMode)
Write-Host "  Key '1' in text mode handled by TabContainer: $handled (should be True - editor handled it)"
Write-Host "  Active tab after: $($tabContainer.ActiveTabIndex + 1) (should still be 2)"

# Test 2: Switch to command mode and test number key
Write-Host "`n=== Test 2: Command mode - number key should switch tabs ===" -ForegroundColor Yellow
# Simulate Escape key to switch to command mode
$escapeKey = [System.ConsoleKeyInfo]::new([char]27, [ConsoleKey]::Escape, $false, $false, $false)
$handled = $tabContainer.HandleInput($escapeKey)
Write-Host "  Escape key handled: $handled"
Write-Host "  TextEditor InTextMode after Escape: $($textEditor.InTextMode)"

# Now test number key in command mode
$key1InCommandMode = [System.ConsoleKeyInfo]::new('1', [ConsoleKey]::D1, $false, $false, $false)
$handled = $tabContainer.HandleInput($key1InCommandMode)
Write-Host "  Key '1' in command mode handled by TabContainer: $handled (should be True - tab switching)"
Write-Host "  Active tab after: $($tabContainer.ActiveTabIndex + 1) (should be 1 - switched to Dummy tab)"

# Test 3: Switch back to tab 2 and verify
Write-Host "`n=== Test 3: Switch back to Editor tab ===" -ForegroundColor Yellow
$key2 = [System.ConsoleKeyInfo]::new('2', [ConsoleKey]::D2, $false, $false, $false)
$handled = $tabContainer.HandleInput($key2)
Write-Host "  Key '2' handled: $handled (should be True)"
Write-Host "  Active tab after: $($tabContainer.ActiveTabIndex + 1) (should be 2 - back to Editor)"
Write-Host "  TextEditor InTextMode: $($textEditor.InTextMode) (should still be False - command mode)"

# Test 4: Test letter key switches back to text mode
Write-Host "`n=== Test 4: Letter key should switch back to text mode ===" -ForegroundColor Yellow
$letterKey = [System.ConsoleKeyInfo]::new('a', [ConsoleKey]::A, $false, $false, $false)
$handled = $tabContainer.HandleInput($letterKey)
Write-Host "  Key 'a' handled: $handled (should be True - editor handled it)"
Write-Host "  TextEditor InTextMode after 'a': $($textEditor.InTextMode) (should be True - switched to text mode)"

Write-Host "`n=== Test Complete ===" -ForegroundColor Green