#!/usr/bin/env pwsh
# SimpleTaskPro.ps1 - Simple task manager with subtasks and notes

param(
    [switch]$Debug
)

# Set location to script directory
Set-Location $PSScriptRoot

# Store debug flag globally
$global:Debug = $Debug

# Load components (order matters!) with detailed logging
$logFile = "$PSScriptRoot/startup-debug.log"
"=== SimpleTaskPro Startup Debug $(Get-Date) ===" | Out-File $logFile
try {
    "Loading StringCache..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Core/StringCache.ps1"
    
    "Loading VT100..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Core/VT100.ps1"
    
    "Loading UniversalBackupManager..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Core/UniversalBackupManager.ps1"
    
    "Loading GapBuffer..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Core/GapBuffer.ps1"
    
    "Loading FileBrowser..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Core/FileBrowser.ps1"
    
    "Loading FullNotesEditor..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Core/FullNotesEditor.ps1"
    
    "Loading TagEditor..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Core/TagEditor.ps1"
    
    "Loading SimpleTask model..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Models/SimpleTask.ps1"
    
    "Loading SimpleTimeEntry model..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Models/SimpleTimeEntry.ps1"
    
    "Loading AppThemeManager (centralized theme system)..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Core/AppThemeManager.ps1"
    
    "Loading FastLineBuilder (enhanced rendering)..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Core/FastLineBuilder.ps1"
    
    "Loading UnifiedRenderer (pure StringBuilder rendering)..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Core/UnifiedRenderer.ps1"
    
    "Loading ColorThemeService..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Services/ColorThemeService.ps1"
    
    "Loading SimpleTaskService..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Services/SimpleTaskService.ps1"
    
    "Loading TimeTrackingService..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Services/TimeTrackingService.ps1"
    
    "Loading ProjectSettingsDialog..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Dialogs/ProjectSettingsDialog.ps1"
    
    "Loading ProjectManagerScreen..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Screens/ProjectManagerScreen.ps1"
    
# Command library system
    "Loading Command model..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Models/Command.ps1"
    
    "Loading CommandService..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Services/CommandService.ps1"
    
    "Loading CommandLibraryScreen..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Screens/CommandLibraryScreen.ps1"
    
    "Loading TaskListScreen..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Screens/TaskListScreen.ps1"
    
    "Loading Excel models and services..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Models/ExcelFieldMapping.ps1"
    . "$PSScriptRoot/Services/ExcelMappingService.ps1"
    . "$PSScriptRoot/Services/ConfigurationService.ps1"
    . "$PSScriptRoot/Services/ExcelService.ps1"
    . "$PSScriptRoot/Services/TextExportService.ps1"
    . "$PSScriptRoot/Services/ExcelServiceContainer.ps1"
    
    "Loading BaseListScreen (core architecture)..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Base/BaseListScreen.ps1"
    
    "Loading ExcelMappingScreen..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Screens/ExcelMappingScreen.ps1"
    
    "Loading SimpleTaskProApp..." | Tee-Object $logFile -Append
    . "$PSScriptRoot/Core/SimpleTaskProApp.ps1"
    
    "All components loaded successfully!" | Tee-Object $logFile -Append
} catch {
    $errorMsg = "Error loading components: $_"
    $stackTrace = $_.ScriptStackTrace
    $errorMsg | Tee-Object $logFile -Append
    $stackTrace | Tee-Object $logFile -Append
    Write-Host $errorMsg -ForegroundColor Red
    Write-Host $stackTrace -ForegroundColor DarkGray
    Write-Host "Check startup-debug.log for details" -ForegroundColor Yellow
    exit 1
}

# Set window title
$Host.UI.RawUI.WindowTitle = "TaskPro - Task Manager"

# Initialize console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::CursorVisible = $false

# Run application
try {
    "Initializing console..." | Tee-Object $logFile -Append
    Clear-Host
    
    "Creating SimpleTaskProApp..." | Tee-Object $logFile -Append
    $app = [SimpleTaskProApp]::new()
    
    "Starting application..." | Tee-Object $logFile -Append
    $app.Run()
    
    "Application started successfully!" | Tee-Object $logFile -Append
} catch {
    [Console]::CursorVisible = $true
    $errorMsg = "Startup error: $_"
    $stackTrace = $_.ScriptStackTrace
    $errorMsg | Tee-Object $logFile -Append
    $stackTrace | Tee-Object $logFile -Append
    Write-Host "`n$errorMsg" -ForegroundColor Red
    Write-Host $stackTrace -ForegroundColor DarkGray
    Write-Host "Check startup-debug.log for details" -ForegroundColor Yellow
    exit 1
}