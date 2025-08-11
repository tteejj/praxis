#!/usr/bin/env pwsh

# Test CommandLibraryScreen quickly
Write-Host "Testing CommandLibraryScreen..." -ForegroundColor Green

# Load required classes
. "$PSScriptRoot/Core/StringCache.ps1"
. "$PSScriptRoot/Core/VT.ps1" 
. "$PSScriptRoot/Core/AppThemeManager.ps1"
. "$PSScriptRoot/Models/Command.ps1"
. "$PSScriptRoot/Services/CommandService.ps1" 
. "$PSScriptRoot/Screens/CommandLibraryScreen.ps1"

try {
    # Create and initialize
    $commandScreen = [CommandLibraryScreen]::new()
    $commandScreen.Initialize(120, 30)
    
    Write-Host "CommandLibraryScreen created successfully!" -ForegroundColor Green
    Write-Host "Commands loaded: $($commandScreen.FlatList.Count)" -ForegroundColor Cyan
    
    # Test rendering
    $output = $commandScreen.Render()
    Write-Host "Render completed successfully! Output length: $($output.Length)" -ForegroundColor Green
    
    # Test column widths
    Write-Host "Column widths: Title=$($commandScreen.COLUMN_TITLE), Command=$($commandScreen.COLUMN_COMMAND), Desc=$($commandScreen.COLUMN_DESC)" -ForegroundColor Yellow
    
    # Test editing mode
    Write-Host "Testing editing mode..." -ForegroundColor Green
    $commandScreen.StartNewCommand()
    Write-Host "Editing mode started: EditingIndex=$($commandScreen.EditingIndex), Field=$($commandScreen.EditingField)" -ForegroundColor Cyan
    
    $output2 = $commandScreen.Render()
    Write-Host "Editing render completed! Output length: $($output2.Length)" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
}