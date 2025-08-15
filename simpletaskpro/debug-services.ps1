#!/usr/bin/env pwsh
# debug-services.ps1 - Debug service registration

Set-Location $PSScriptRoot

# Load exactly as main app does
. "$PSScriptRoot/Core/ServiceContainer-Phase4.5.ps1"
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
. "$PSScriptRoot/Core/AppThemeManager.ps1"
. "$PSScriptRoot/Core/RenderEngine.ps1"
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
. "$PSScriptRoot/Core/Bootstrapper.ps1"

Write-Host "=== SERVICE REGISTRATION DEBUG ===" -ForegroundColor Yellow

try {
    Write-Host "1. Creating Bootstrapper..." -ForegroundColor Cyan
    $app = [Bootstrapper]::Initialize($PSScriptRoot)
    
    Write-Host "2. Getting service container..." -ForegroundColor Cyan
    $container = [Bootstrapper]::GetServiceContainer()
    
    Write-Host "3. Testing direct service access..." -ForegroundColor Cyan
    try {
        $taskService = $container.GetService("SimpleTaskService")
        Write-Host "   SimpleTaskService: $($taskService.GetType().Name)" -ForegroundColor Green
    } catch {
        Write-Host "   SimpleTaskService ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "4. Listing all registered services..." -ForegroundColor Cyan
    $serviceField = $container.GetType().GetField("_services", [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance)
    if ($serviceField) {
        $services = $serviceField.GetValue($container)
        Write-Host "   Registered service keys:" -ForegroundColor Green
        foreach ($key in $services.Keys) {
            $service = $services[$key]
            Write-Host "     '$key' -> $($service.GetType().Name)" -ForegroundColor Green
        }
    } else {
        Write-Host "   Could not access _services field" -ForegroundColor Red
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "=== DEBUG COMPLETE ===" -ForegroundColor Yellow