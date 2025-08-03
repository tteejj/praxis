#!/usr/bin/env pwsh

# Test the new simplified dialog system
Write-Host "Testing new SimpleDialog system..." -ForegroundColor Green

# Test just the StartupSelectionDialog
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Base/SimpleDialog.ps1"
. "$PSScriptRoot/Screens/StartupSelectionDialog.ps1"

$dialog = [StartupSelectionDialog]::new()
$dialog.OnSelect = {
    Write-Host "Selected: $($dialog.SelectedOption)" -ForegroundColor Cyan
}.GetNewClosure()

$dialog.OnCancel = {
    Write-Host "Cancelled" -ForegroundColor Yellow
}.GetNewClosure()

Write-Host "Showing dialog..." -ForegroundColor Yellow
$dialog.Show()

Write-Host "Dialog completed. Result: $($dialog.DialogResult)" -ForegroundColor Green