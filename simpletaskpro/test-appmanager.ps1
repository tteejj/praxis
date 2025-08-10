#!/usr/bin/env pwsh

# Simple test of the core application without input issues

# Load required components
. "$PSScriptRoot/Core/StringCache.ps1"
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Models/SimpleTask.ps1"
. "$PSScriptRoot/Services/SimpleTaskService.ps1"
. "$PSScriptRoot/Core/AppThemeManager.ps1"
. "$PSScriptRoot/Core/FastLineBuilder.ps1"
. "$PSScriptRoot/Core/UnifiedRenderer.ps1"
. "$PSScriptRoot/Services/ColorThemeService.ps1"
. "$PSScriptRoot/Core/UniversalBackupManager.ps1"
. "$PSScriptRoot/Load-ModalSystem.ps1"
. "$PSScriptRoot/Screens/TaskListScreen.ps1"

Write-Host "Testing TaskListScreen functionality..." -ForegroundColor Cyan

# Create screen
$screen = [TaskListScreen]::new()
$screen.Initialize([Console]::WindowWidth, [Console]::WindowHeight)

Write-Host "Screen initialized. Current selection: $($screen.SelectedIndex)" -ForegroundColor Green

# Test down arrow key
Write-Host "`nTesting down arrow..." -ForegroundColor Yellow
$downKey = [System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::DownArrow, $false, $false, $false)
$result = $screen.HandleInput($downKey)
Write-Host "Down arrow result: $result. New selection: $($screen.SelectedIndex)" -ForegroundColor $(if($result) {"Green"} else {"Red"})

# Test up arrow key
Write-Host "`nTesting up arrow..." -ForegroundColor Yellow
$upKey = [System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::UpArrow, $false, $false, $false)
$result = $screen.HandleInput($upKey)
Write-Host "Up arrow result: $result. New selection: $($screen.SelectedIndex)" -ForegroundColor $(if($result) {"Green"} else {"Red"})

# Test / key
Write-Host "`nTesting / key..." -ForegroundColor Yellow
$slashKey = [System.ConsoleKeyInfo]::new('/', [System.ConsoleKey]::Oem2, $false, $false, $false)
$result = $screen.HandleInput($slashKey)
Write-Host "Slash key result: $result" -ForegroundColor $(if($result) {"Green"} else {"Red"})

Write-Host "`nTest completed!" -ForegroundColor Cyan