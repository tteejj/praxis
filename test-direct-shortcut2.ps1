#!/usr/bin/env pwsh
# Direct test of shortcut functionality - complete

Write-Host "`nDirect Shortcut Test" -ForegroundColor Cyan

# Clear log
if (Test-Path "_Logs/praxis.log") {
    Clear-Content "_Logs/praxis.log"
}

# Load ALL required files in correct order
. ./Core/VT100.ps1
. ./Services/Logger.ps1
. ./Core/ServiceContainer.ps1
. ./Services/EventBus.ps1  # EventBus must be loaded before ShortcutManager
. ./Services/ShortcutManager.ps1

# Create logger and container
$global:Logger = [Logger]::new()
$global:ServiceContainer = [ServiceContainer]::new()
$global:ServiceContainer.Register("Logger", $global:Logger)

# Create EventBus
$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("EventBus", $eventBus)

# Create and initialize ShortcutManager
$sm = [ShortcutManager]::new()
$sm.Initialize($global:ServiceContainer)

Write-Host "ShortcutManager created with $($sm.Shortcuts.Count) default shortcuts" -ForegroundColor Green

# List default shortcuts first
Write-Host "`nDefault shortcuts:" -ForegroundColor Cyan
foreach ($s in $sm.Shortcuts) {
    $key = if ($s.KeyChar -ne [char]0) { "Char='$($s.KeyChar)'" } else { "Key=$($s.Key)" }
    Write-Host "  $($s.Id): $key Screen=$($s.ScreenType) Scope=$($s.Scope)" -ForegroundColor Gray
}

# Register a test shortcut
Write-Host "`nRegistering test shortcut for 'e' key..." -ForegroundColor Yellow
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

Write-Host "Total shortcuts after registration: $($sm.Shortcuts.Count)" -ForegroundColor Green

# Test key press
Write-Host "`nTesting key press 'e' on ProjectsScreen..." -ForegroundColor Yellow
$keyE = [System.ConsoleKeyInfo]::new('e', [System.ConsoleKey]::E, $false, $false, $false)

# Check matches manually
Write-Host "`nChecking matches for 'e' key:" -ForegroundColor Cyan
foreach ($s in $sm.Shortcuts) {
    if ($s.KeyChar -eq 'e' -or $s.KeyChar -eq 'E') {
        $matches = $s.Matches($keyE)
        Write-Host "  $($s.Id): KeyChar='$($s.KeyChar)' Matches=$matches" -ForegroundColor $(if ($matches) { 'Green' } else { 'Red' })
    }
}

$handled = $sm.HandleKeyPress($keyE, "ProjectsScreen", "")
Write-Host "`nHandled: $handled" -ForegroundColor $(if ($handled) { 'Green' } else { 'Red' })

# Check log
if (Test-Path "_Logs/praxis.log") {
    Write-Host "`nRecent log entries:" -ForegroundColor Cyan
    Get-Content "_Logs/praxis.log" -Tail 20 | ForEach-Object {
        if ($_ -match "ERROR") {
            Write-Host $_ -ForegroundColor Red
        } elseif ($_ -match "DEBUG") {
            Write-Host $_ -ForegroundColor Gray
        } else {
            Write-Host $_ -ForegroundColor White
        }
    }
}