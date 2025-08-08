#!/usr/bin/env pwsh
# SimpleTaskPro.ps1 - Simple task manager with subtasks and notes

param(
    [switch]$Debug
)

# Set location to script directory
Set-Location $PSScriptRoot

# Store debug flag globally
$global:Debug = $Debug

# Load components (order matters!)
try {
    . "$PSScriptRoot/Core/StringCache.ps1"  # Load StringCache first
    . "$PSScriptRoot/Core/VT100.ps1"        # VT100 depends on StringCache
    . "$PSScriptRoot/Core/UniversalBackupManager.ps1"  # Load backup system BEFORE everything else
    . "$PSScriptRoot/Core/GapBuffer.ps1"     # Core gap buffer implementation
    . "$PSScriptRoot/Core/FileBrowser.ps1"  # File browser must load before dialogs
    . "$PSScriptRoot/Core/FullNotesEditor.ps1"  # Full text editor with gap buffer
    . "$PSScriptRoot/Core/TagEditor.ps1"    # Tag editor for tasks
    . "$PSScriptRoot/Models/SimpleTask.ps1"
    . "$PSScriptRoot/Models/SimpleTimeEntry.ps1"  # NEW: Time entry model
    . "$PSScriptRoot/Services/ColorThemeService.ps1"
    . "$PSScriptRoot/Services/SimpleTaskService.ps1"
    . "$PSScriptRoot/Services/TimeTrackingService.ps1"  # NEW: Time tracking service
    . "$PSScriptRoot/Dialogs/ProjectSettingsDialog.ps1"
    . "$PSScriptRoot/Screens/ProjectManagerScreen.ps1"
    . "$PSScriptRoot/Screens/TaskListScreen.ps1"
    . "$PSScriptRoot/Core/SimpleTaskProApp.ps1"
} catch {
    Write-Host "Error loading components: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}

# Set window title
$Host.UI.RawUI.WindowTitle = "TaskPro - Task Manager"

# Initialize console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::CursorVisible = $false

# Run application
try {
    Clear-Host
    $app = [SimpleTaskProApp]::new()
    $app.Run()
} catch {
    [Console]::CursorVisible = $true
    Write-Host "`nStartup error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}