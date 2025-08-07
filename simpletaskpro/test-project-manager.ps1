#!/usr/bin/env pwsh
# Test script for ProjectManagerScreen with settings dialog integration

# Set location to script directory
Set-Location $PSScriptRoot

# Load required components
. "$PSScriptRoot/Core/StringCache.ps1"
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Models/SimpleTask.ps1"
. "$PSScriptRoot/Services/ColorThemeService.ps1"
. "$PSScriptRoot/Services/SimpleTaskService.ps1"
. "$PSScriptRoot/Core/FileBrowser.ps1"
. "$PSScriptRoot/Dialogs/ProjectSettingsDialog.ps1"
. "$PSScriptRoot/Screens/ProjectManagerScreen.ps1"

# Create test task service and parent task
try {
    $taskService = [SimpleTaskService]::new()
    $themeService = [ColorThemeService]::new()
    
    # Create a test parent task
    $parentTask = [SimpleTask]::new()
    $parentTask.Title = "Test Project"
    $parentTask.Priority = "Medium"
    $parentTask.Id = [guid]::NewGuid()
    
    # Create project manager screen
    $projectManager = [ProjectManagerScreen]::new()
    $projectManager.SetServices($taskService, $themeService)
    $projectManager.SetParentTask($parentTask)
    $projectManager.SetBounds(0, 0, [Console]::WindowWidth, [Console]::WindowHeight)
    
    Write-Host "ProjectManagerScreen created successfully!" -ForegroundColor Green
    Write-Host "Parent task: $($parentTask.Title)" -ForegroundColor Cyan
    Write-Host "All components loaded without errors." -ForegroundColor Green
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}

Write-Host "Test completed. Press any key to exit..." -ForegroundColor White