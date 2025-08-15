#!/usr/bin/env pwsh
# SimpleTaskPro.ps1 - The single, clean entry point for the application.

param([switch]$Debug)
Set-Location $PSScriptRoot
$global:Debug = $Debug

# Load EVERYTHING first, then Bootstrapper
Write-Host "DEBUG LOAD: Starting file loading..." -ForegroundColor Yellow

# STEP 1: Core utilities and Models FIRST
Write-Host "DEBUG LOAD: ServiceContainer-Phase4.5.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Core/ServiceContainer-Phase4.5.ps1"
Write-Host "DEBUG LOAD: StringCache.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Core/StringCache.ps1"
Write-Host "DEBUG LOAD: VT100.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Core/VT100.ps1"
Write-Host "DEBUG LOAD: UniversalBackupManager.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Core/UniversalBackupManager.ps1"
Write-Host "DEBUG LOAD: GapBuffer.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Core/GapBuffer.ps1"
Write-Host "DEBUG LOAD: SimpleTask.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Models/SimpleTask.ps1"
Write-Host "DEBUG LOAD: SimpleTimeEntry.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Models/SimpleTimeEntry.ps1"
Write-Host "DEBUG LOAD: Command.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Models/Command.ps1"
Write-Host "DEBUG LOAD: ExcelFieldMapping.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Models/ExcelFieldMapping.ps1"

# STEP 2: Core services that depend on Models
Write-Host "DEBUG LOAD: Logger.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Core/Logger.ps1"
Write-Host "DEBUG LOAD: EventBus.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Core/EventBus.ps1"
Write-Host "DEBUG LOAD: SimpleStateManager.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Core/SimpleStateManager.ps1"
Write-Host "DEBUG LOAD: InputProcessor.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Core/InputProcessor.ps1"
Write-Host "DEBUG LOAD: AppThemeManager.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Core/AppThemeManager.ps1"
Write-Host "DEBUG LOAD: RenderEngine.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Core/RenderEngine.ps1"
Write-Host "DEBUG LOAD: FastLineBuilder.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Core/FastLineBuilder.ps1"
Write-Host "DEBUG LOAD: SimpleTaskService.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Services/SimpleTaskService.ps1"
Write-Host "DEBUG LOAD: TimeTrackingService.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Services/TimeTrackingService.ps1"
Write-Host "DEBUG LOAD: CommandService.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Services/CommandService.ps1"
Write-Host "DEBUG LOAD: ExcelMappingService.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Services/ExcelMappingService.ps1"
Write-Host "DEBUG LOAD: KeyMappingService.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Services/KeyMappingService.ps1"
Write-Host "DEBUG LOAD: Screen.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Base/Screen.ps1"
Write-Host "DEBUG LOAD: *** LOADING ListScreen.ps1 NOW *** " -ForegroundColor Red
. "$PSScriptRoot/Base/ListScreen.ps1"
Write-Host "DEBUG LOAD: *** ListScreen.ps1 LOADED SUCCESSFULLY *** " -ForegroundColor Red
Write-Host "DEBUG LOAD: TaskListScreen.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Screens/TaskListScreen.ps1"
Write-Host "DEBUG LOAD: SimpleTaskProApp.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Core/SimpleTaskProApp.ps1"
Write-Host "DEBUG LOAD: Bootstrapper.ps1" -ForegroundColor Yellow
. "$PSScriptRoot/Core/Bootstrapper.ps1"
Write-Host "DEBUG LOAD: All files loaded successfully!" -ForegroundColor Green

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