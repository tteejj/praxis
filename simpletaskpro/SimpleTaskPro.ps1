#!/usr/bin/env pwsh
# SimpleTaskPro.ps1 - The single, clean entry point for the application.

param([switch]$Debug)
Set-Location $PSScriptRoot
$global:Debug = $Debug

# Load core dependencies in correct order  
. "$PSScriptRoot/Core/ServiceContainer-Phase4.5.ps1"

# Load ALL application components in dependency order
. "$PSScriptRoot/Core/StringCache.ps1"
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Core/UniversalBackupManager.ps1"
. "$PSScriptRoot/Core/GapBuffer.ps1"
. "$PSScriptRoot/Models/SimpleTask.ps1"
. "$PSScriptRoot/Models/SimpleTimeEntry.ps1"
. "$PSScriptRoot/Models/Command.ps1"
. "$PSScriptRoot/Models/ExcelFieldMapping.ps1"
. "$PSScriptRoot/Core/Logger.ps1"
. "$PSScriptRoot/Core/EventBus.ps1"
. "$PSScriptRoot/Core/SimpleStateManager.ps1"
. "$PSScriptRoot/Core/InputProcessor.ps1"
. "$PSScriptRoot/Core/RenderEngine.ps1"
. "$PSScriptRoot/Core/AppThemeManager.ps1"
. "$PSScriptRoot/Core/FastLineBuilder.ps1"
. "$PSScriptRoot/Services/SimpleTaskService.ps1"
. "$PSScriptRoot/Services/TimeTrackingService.ps1"
. "$PSScriptRoot/Services/CommandService.ps1"
. "$PSScriptRoot/Services/ExcelMappingService.ps1"
. "$PSScriptRoot/Services/KeyMappingService.ps1"
. "$PSScriptRoot/Base/Screen.ps1"
. "$PSScriptRoot/Base/ListScreen.ps1"
. "$PSScriptRoot/Screens/TaskListScreen.ps1"
. "$PSScriptRoot/Core/SimpleTaskProApp.ps1"

# Load the Bootstrapper (after all dependencies are loaded)
. "$PSScriptRoot/Core/Bootstrapper.ps1"

try {
    # Initialize the entire application through the single, reliable Bootstrapper.
    $app = [Bootstrapper]::Initialize($PSScriptRoot)
    
    # Run the application launcher, which will hand off control to the first screen.
    $app.Run()

} catch {
    [Console]::CursorVisible = $true
    Write-Host "`nCRITICAL STARTUP FAILURE. See logs for details." -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    try { [Bootstrapper]::EmergencyCleanup() } catch {}
    exit 1
} finally {
    try { [Bootstrapper]::Cleanup() } catch {}
    Write-Host "`nSimpleTaskPro has exited." -ForegroundColor Green
}