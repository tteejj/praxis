#!/usr/bin/env pwsh

# Test the dialog system interactively
Write-Host "Testing ExcelDataFlow dialog system..." -ForegroundColor Green
Write-Host "This will show the startup dialog. Press Enter to select option 1, or Escape to exit." -ForegroundColor Yellow

# Set up the environment
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Base/SimpleDialog.ps1"
. "$PSScriptRoot/Screens/StartupSelectionDialog.ps1"

# Create and configure the dialog
$dialog = [StartupSelectionDialog]::new()

$dialog.OnSelect = {
    Write-Host "`nSelected option: $($dialog.SelectedOption)" -ForegroundColor Cyan
    Write-Host "Selected index: $($dialog.SelectedIndex)" -ForegroundColor Cyan
    Write-Host "Dialog result: $($dialog.DialogResult)" -ForegroundColor Cyan
}.GetNewClosure()

$dialog.OnCancel = {
    Write-Host "`nDialog cancelled" -ForegroundColor Yellow
}.GetNewClosure()

# Show the dialog
try {
    $dialog.Show()
    Write-Host "`nDialog completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "`nError: $_" -ForegroundColor Red
}