#!/usr/bin/env pwsh
# Direct test of shortcut functionality

Write-Host "`nDirect Shortcut Test" -ForegroundColor Cyan

# Clear log
if (Test-Path "_Logs/praxis.log") {
    Clear-Content "_Logs/praxis.log"
}

# Load required files
. ./Core/VT100.ps1
. ./Services/Logger.ps1
. ./Core/ServiceContainer.ps1
. ./Services/ShortcutManager.ps1

# Create logger and container
$global:Logger = [Logger]::new()
$global:ServiceContainer = [ServiceContainer]::new()
$global:ServiceContainer.Register("Logger", $global:Logger)

# Create and initialize ShortcutManager
$sm = [ShortcutManager]::new()
$sm.Initialize($global:ServiceContainer)

Write-Host "ShortcutManager created with $($sm.Shortcuts.Count) default shortcuts" -ForegroundColor Green

# Register a test shortcut
$sm.RegisterShortcut(@{
    Id = "test.edit"
    Name = "Edit"
    Description = "Edit test"
    KeyChar = 'e'
    Scope = [ShortcutScope]::Screen
    ScreenType = "ProjectsScreen"
    Priority = 50
    Action = { Write-Host "EDIT ACTION EXECUTED!" -ForegroundColor Green }
})

Write-Host "Registered test shortcut. Total shortcuts: $($sm.Shortcuts.Count)" -ForegroundColor Yellow

# List all shortcuts
Write-Host "`nAll shortcuts:" -ForegroundColor Cyan
foreach ($s in $sm.Shortcuts) {
    $key = if ($s.KeyChar -ne [char]0) { "Char='$($s.KeyChar)'" } else { "Key=$($s.Key)" }
    Write-Host "  $($s.Id): $key Screen=$($s.ScreenType) Scope=$($s.Scope)" -ForegroundColor Gray
}

# Test key press
Write-Host "`nTesting key press 'e' on ProjectsScreen..." -ForegroundColor Yellow
$keyE = [System.ConsoleKeyInfo]::new('e', [System.ConsoleKey]::E, $false, $false, $false)
$handled = $sm.HandleKeyPress($keyE, "ProjectsScreen", "")
Write-Host "Handled: $handled" -ForegroundColor $(if ($handled) { 'Green' } else { 'Red' })

Write-Host "`nCheck _Logs/praxis.log for debug output" -ForegroundColor Cyan