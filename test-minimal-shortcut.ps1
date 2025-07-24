#!/usr/bin/env pwsh
# Minimal test to verify shortcut system

Write-Host "Loading PRAXIS components..." -ForegroundColor Cyan

# Load required files
. ./Core/VT100.ps1
. ./Core/ServiceContainer.ps1  
. ./Services/Logger.ps1
. ./Services/EventBus.ps1
. ./Services/ShortcutManager.ps1

# Create services
$global:ServiceContainer = [ServiceContainer]::new()
$global:Logger = [Logger]::new()
$global:ServiceContainer.Register("Logger", $global:Logger)

$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("EventBus", $eventBus)

# Create ShortcutManager
$sm = [ShortcutManager]::new()
$sm.Initialize($global:ServiceContainer)

Write-Host "`nInitial shortcuts: $($sm.Shortcuts.Count)" -ForegroundColor Green

# Register a test shortcut
$sm.RegisterShortcut(@{
    Id = "test.edit"
    Name = "Edit" 
    Description = "Test edit"
    KeyChar = 'e'
    Scope = [ShortcutScope]::Screen
    ScreenType = "ProjectsScreen"
    Priority = 50
    Action = { Write-Host "EDIT ACTION EXECUTED!" -ForegroundColor Green -BackgroundColor DarkGreen }
})

Write-Host "After registration: $($sm.Shortcuts.Count) shortcuts" -ForegroundColor Green

# List all shortcuts
Write-Host "`nAll shortcuts:" -ForegroundColor Cyan
foreach ($s in $sm.Shortcuts) {
    $keyStr = if ($s.KeyChar -ne [char]0) { "Char='$($s.KeyChar)'" } else { "Key=$($s.Key)" }
    Write-Host "  $($s.Id): $keyStr Screen=$($s.ScreenType) Scope=$($s.Scope)" -ForegroundColor Gray
}

# Test key press
Write-Host "`nTesting 'e' key on ProjectsScreen..." -ForegroundColor Yellow
$keyE = [System.ConsoleKeyInfo]::new('e', [System.ConsoleKey]::E, $false, $false, $false)
$handled = $sm.HandleKeyPress($keyE, "ProjectsScreen", "")

Write-Host "`nResult: Handled = $handled" -ForegroundColor $(if ($handled) { 'Green' } else { 'Red' })

# Now test unregister/re-register
Write-Host "`nTesting unregister/re-register cycle..." -ForegroundColor Yellow
$sm.UnregisterShortcut("test.edit")
Write-Host "After unregister: $($sm.Shortcuts.Count) shortcuts" -ForegroundColor Gray

# Re-register
$sm.RegisterShortcut(@{
    Id = "test.edit"
    Name = "Edit"
    Description = "Test edit" 
    KeyChar = 'e'
    Scope = [ShortcutScope]::Screen
    ScreenType = "ProjectsScreen"
    Priority = 50
    Action = { Write-Host "EDIT ACTION EXECUTED AGAIN!" -ForegroundColor Green -BackgroundColor DarkGreen }
})

Write-Host "After re-register: $($sm.Shortcuts.Count) shortcuts" -ForegroundColor Gray

# Test again
Write-Host "`nTesting 'e' key again..." -ForegroundColor Yellow
$handled = $sm.HandleKeyPress($keyE, "ProjectsScreen", "")
Write-Host "Result: Handled = $handled" -ForegroundColor $(if ($handled) { 'Green' } else { 'Red' })