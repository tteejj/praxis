#!/usr/bin/env pwsh
# TaskPro.ps1 - Simple, fast task manager with integrated notes editor

param(
    [switch]$Debug
)

# Set location to script directory
Set-Location $PSScriptRoot

# Store debug flag globally
$global:Debug = $Debug

# Load components (order matters!)
. "$PSScriptRoot/Core/StringCache.ps1"
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Core/TextEditor.ps1"
. "$PSScriptRoot/Models/Task.ps1"
. "$PSScriptRoot/Services/TaskService.ps1"
. "$PSScriptRoot/Screens/TaskScreen.ps1"
. "$PSScriptRoot/Core/TaskProApp.ps1"

# Set window title
$Host.UI.RawUI.WindowTitle = "TaskPro - Task Manager"

# Initialize console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::CursorVisible = $false

# Save initial console state
$initialBufferSize = $Host.UI.RawUI.BufferSize
$initialWindowSize = $Host.UI.RawUI.WindowSize

# Error handler
trap {
    [Console]::CursorVisible = $true
    Write-Host "`nFatal error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}

# Welcome message
Clear-Host
Write-Host "TaskPro - Task Manager" -ForegroundColor Cyan
Write-Host "Loading..." -ForegroundColor Gray

# Create and run application
try {
    $app = [TaskProApp]::new()
    $app.Run()
} catch {
    [Console]::CursorVisible = $true
    Write-Host "`nStartup error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}