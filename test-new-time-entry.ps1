#!/usr/bin/env pwsh

Write-Host "Testing new time entry functionality..." -ForegroundColor Cyan

# Rotate log
mv _Logs/praxis.log _Logs/praxis.log.old 2>$null

# Create input sequence to test the new entry flow
$inputs = @(
    "3"         # Navigate to Time Entry tab
    [char]27    # ESC to ensure clean state
    "n"         # New entry - should show options dialog
    [char]9     # Tab to focus list
    [char]13    # Enter to select first option (projects)
    [char]27    # ESC to close project selection
    [char]27    # ESC to close options
    "n"         # New entry again
    [char]9     # Tab to focus list
    [System.ConsoleKey]::DownArrow  # Down to manual entry
    [char]13    # Enter to select manual option
    [char]27    # ESC to close manual entry
    "Q"         # Quit
)

# Join inputs
$inputString = $inputs -join ''

# Run the test
$inputString | pwsh -File Start.ps1 2>&1 | Out-Null

Write-Host "`nChecking for errors..." -ForegroundColor Yellow
$errors = Get-Content _Logs/praxis.log | Select-String -Pattern "ERROR" 
if ($errors) {
    Write-Host "Errors found:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "No errors!" -ForegroundColor Green
}

Write-Host "`nChecking dialog flow..." -ForegroundColor Yellow
$pushes = Get-Content _Logs/praxis.log | Select-String -Pattern "ScreenManager.Push.*Dialog"
if ($pushes) {
    Write-Host "Dialogs opened:" -ForegroundColor Green
    $pushes | ForEach-Object { Write-Host "  $_" }
}