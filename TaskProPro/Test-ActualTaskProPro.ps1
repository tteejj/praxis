#!/usr/bin/env pwsh
# Test TaskProPro with bypassed interactive check

param(
    [string]$DataFile = "$PSScriptRoot/Data/tasks.json",
    [switch]$Debug
)

# Set debug mode
$global:Debug = $Debug.IsPresent

# BYPASS interactive check
$hasInteractiveConsole = $true

try {
    # Load professional TUI foundation
    . "$PSScriptRoot/Load-TaskProPro.ps1"
    
    Write-Host "Starting TaskProPro..." -ForegroundColor Cyan
    
    # Initialize data directory
    $dataDir = Split-Path $DataFile -Parent
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
    
    # Initialize components with error handling
    try {
        $taskManager = [TaskPro.Data.TaskManager]::new($DataFile)
        Write-Host "TaskManager loaded successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "FAILED to create TaskManager: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "This means C# classes are NOT loaded - fallback UI would activate" -ForegroundColor Yellow
        exit 1
    }
    
    try {
        $screen = [TaskPro.Core.ScreenBuffer]::new(80, 24)
        $taskListWidget = [TaskPro.UI.TaskListWidget]::new()
        Write-Host "Enhanced UI components loaded successfully!" -ForegroundColor Green
        Write-Host "TaskProPro is using the ENHANCED system, not fallback" -ForegroundColor Cyan
    }
    catch {
        Write-Host "FAILED to create UI components: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "This is where fallback UI would activate" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "SUCCESS: Enhanced TaskProPro loaded completely!" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR in main: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}