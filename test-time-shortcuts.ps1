#!/usr/bin/env pwsh

Write-Host "Testing Time Entry shortcuts..." -ForegroundColor Cyan

# Create input sequence
$inputs = @(
    "3"      # Navigate to Time Entry tab
    [char]27 # ESC to ensure no dialog is open
    "n"      # New entry
    [char]27 # ESC to close
    "q"      # Quick entry
    [char]27 # ESC to close
    "e"      # Edit entry
    [char]27 # ESC to close
    "Q"      # Quit
)

# Join inputs with small delays
$inputString = $inputs -join ''

# Run the test
$inputString | pwsh -File Start.ps1 2>&1 | Out-Null

Write-Host "`nChecking log for errors..." -ForegroundColor Yellow
$errors = Get-Content _Logs/praxis.log -ErrorAction SilentlyContinue | Select-String -Pattern "ERROR"
if ($errors) {
    Write-Host "Found errors:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "No errors found!" -ForegroundColor Green
}

Write-Host "`nChecking shortcut executions..." -ForegroundColor Yellow
Get-Content _Logs/praxis.log -ErrorAction SilentlyContinue | Select-String -Pattern "Executing shortcut: time\." | ForEach-Object {
    Write-Host "✓ $_" -ForegroundColor Green
}