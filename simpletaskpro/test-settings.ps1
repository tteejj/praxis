#!/usr/bin/env pwsh
# Test script for ProjectSettingsDialog with integrated browser

# Set location to script directory
Set-Location $PSScriptRoot

# Load required components
. "$PSScriptRoot/Core/StringCache.ps1"  # Load StringCache first
. "$PSScriptRoot/Core/VT100.ps1"        # VT100 depends on StringCache
. "$PSScriptRoot/Models/SimpleTask.ps1"
. "$PSScriptRoot/Core/FileBrowser.ps1"
. "$PSScriptRoot/Dialogs/ProjectSettingsDialog.ps1"

# Create test task
$testTask = [SimpleTask]::new()
$testTask.Title = "Test Project with Browser Integration"
$testTask.Priority = "Medium"

# Create and show dialog
try {
    $dialog = [ProjectSettingsDialog]::new()
    $result = $dialog.Show($testTask)
    
    Write-Host "Dialog result: $result" -ForegroundColor Cyan
    if ($result) {
        Write-Host "Updated task settings:" -ForegroundColor Green
        Write-Host "Project Folder: $($testTask.ProjectFolderPath)" -ForegroundColor Yellow
        Write-Host "T2020 File: $($testTask.T2020CallLogFile)" -ForegroundColor Yellow
        Write-Host "Export File: $($testTask.ExportDataFile)" -ForegroundColor Yellow
        Write-Host "Action Log: $($testTask.ActionLogName)" -ForegroundColor Yellow
        Write-Host "ID1: $($testTask.ID1)" -ForegroundColor Yellow
        Write-Host "ID2: $($testTask.ID2)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}

Write-Host "Test completed. Press any key to exit..." -ForegroundColor White
[Console]::ReadKey($true) | Out-Null