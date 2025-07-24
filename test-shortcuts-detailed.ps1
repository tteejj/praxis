#!/usr/bin/env pwsh
# Test shortcut registration and matching in detail

Write-Host "`nDetailed Shortcut Testing" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

# Load PRAXIS components
. ./Core/ServiceContainer.ps1
. ./Services/Logger.ps1
. ./Services/ShortcutManager.ps1

# Create services
$logger = [Logger]::new('test-shortcuts-detailed.log')
$container = [ServiceContainer]::new()
$container.RegisterService('Logger', $logger)

# Create and initialize ShortcutManager
$sm = [ShortcutManager]::new()
$sm.Initialize($container)

Write-Host "`nShortcutManager initialized with $($sm.Shortcuts.Count) shortcuts" -ForegroundColor Green

# Register a test shortcut
Write-Host "`nRegistering test shortcut for 'e' key..." -ForegroundColor Yellow
$sm.RegisterShortcut(@{
    Id = "test.edit"
    Name = "Test Edit"
    Description = "Test edit action"
    KeyChar = 'e'
    Scope = [ShortcutScope]::Screen
    ScreenType = "ProjectsScreen"
    Priority = 50
    Action = { Write-Host "EDIT ACTION EXECUTED!" -ForegroundColor Green }
})

Write-Host "Total shortcuts after registration: $($sm.Shortcuts.Count)" -ForegroundColor Green

# List all shortcuts
Write-Host "`nAll registered shortcuts:" -ForegroundColor Yellow
foreach ($shortcut in $sm.Shortcuts) {
    $key = if ($shortcut.KeyChar -ne [char]0) { "Char='$($shortcut.KeyChar)'" } else { "Key=$($shortcut.Key)" }
    Write-Host "  $($shortcut.Id): $key, Screen=$($shortcut.ScreenType), Scope=$($shortcut.Scope)" -ForegroundColor Gray
}

# Test key matching
Write-Host "`nTesting key matching..." -ForegroundColor Yellow

# Create test key for 'e'
$testKey = [System.ConsoleKeyInfo]::new('e', [System.ConsoleKey]::E, $false, $false, $false)
Write-Host "Test key: Char='$($testKey.KeyChar)' Key=$($testKey.Key)" -ForegroundColor Gray

# Test each shortcut's Matches method
Write-Host "`nTesting Matches() for each shortcut:" -ForegroundColor Yellow
foreach ($shortcut in $sm.Shortcuts) {
    $matches = $shortcut.Matches($testKey)
    $key = if ($shortcut.KeyChar -ne [char]0) { "Char='$($shortcut.KeyChar)'" } else { "Key=$($shortcut.Key)" }
    Write-Host "  $($shortcut.Id) ($key): Matches = $matches" -ForegroundColor $(if ($matches) { 'Green' } else { 'Red' })
}

# Test HandleKeyPress
Write-Host "`nTesting HandleKeyPress..." -ForegroundColor Yellow
Write-Host "Current screen: ProjectsScreen" -ForegroundColor Gray
Write-Host "Current context: (empty)" -ForegroundColor Gray

$handled = $sm.HandleKeyPress($testKey, "ProjectsScreen", "")
Write-Host "Result: Handled = $handled" -ForegroundColor $(if ($handled) { 'Green' } else { 'Red' })

# Test with wrong screen
Write-Host "`nTesting with wrong screen (TaskScreen)..." -ForegroundColor Yellow
$handled = $sm.HandleKeyPress($testKey, "TaskScreen", "")
Write-Host "Result: Handled = $handled" -ForegroundColor $(if ($handled) { 'Green' } else { 'Red' })

# Test case sensitivity
Write-Host "`nTesting case sensitivity..." -ForegroundColor Yellow
$testKeyUpper = [System.ConsoleKeyInfo]::new('E', [System.ConsoleKey]::E, $true, $false, $false)
Write-Host "Test key (uppercase): Char='$($testKeyUpper.KeyChar)' Key=$($testKeyUpper.Key)" -ForegroundColor Gray
$handled = $sm.HandleKeyPress($testKeyUpper, "ProjectsScreen", "")
Write-Host "Result: Handled = $handled" -ForegroundColor $(if ($handled) { 'Green' } else { 'Red' })

Write-Host "`nCheck test-shortcuts-detailed.log for detailed debug output" -ForegroundColor Cyan