#!/usr/bin/env pwsh
# debug-rendering.ps1 - Systematic debugging of rendering issues

Set-Location $PSScriptRoot

# Load components in EXACT same order as SimpleTaskPro.ps1
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
. "$PSScriptRoot/Core/RenderEngine.ps1"
. "$PSScriptRoot/Core/AppThemeManager.ps1"

Write-Host "=== SYSTEMATIC RENDERING DEBUG ===" -ForegroundColor Yellow

Write-Host "`n1. Testing AppThemeManager GetColor method (CORRECTED):" -ForegroundColor Cyan
try {
    $headerBg = [AppThemeManager]::GetBackgroundColor("Header")
    $headerFg = [AppThemeManager]::GetColor("Header")
    $footerBg = [AppThemeManager]::GetBackgroundColor("Header")
    $footerFg = [AppThemeManager]::GetColor("Header")
    
    Write-Host "HeaderBackground: '$headerBg' (length: $($headerBg.Length))" -ForegroundColor Green
    Write-Host "HeaderForeground: '$headerFg' (length: $($headerFg.Length))" -ForegroundColor Green
    Write-Host "FooterBackground: '$footerBg' (length: $($footerBg.Length))" -ForegroundColor Green
    Write-Host "FooterForeground: '$footerFg' (length: $($footerFg.Length))" -ForegroundColor Green
} catch {
    Write-Host "ERROR in GetColor: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`n2. Testing string interpolation that creates 'mm':" -ForegroundColor Cyan
try {
    $title = "Tasks"
    $width = 80
    $headerBg = "48;2;50;50;50"  # Simulate return value
    $headerFg = "38;2;200;200;200"  # Simulate return value
    
    Write-Host "Title: '$title'" -ForegroundColor Green
    Write-Host "Width: $width" -ForegroundColor Green
    
    $titleLine = " $($title)" + " " * ($width - $title.Length - 1)
    Write-Host "TitleLine length: $($titleLine.Length)" -ForegroundColor Green
    Write-Host "TitleLine: '$titleLine'" -ForegroundColor Green
    
    $escapeSequence = "`e[${headerBg}m`e[${headerFg}m$titleLine`e[0m`n"
    Write-Host "EscapeSequence: '$escapeSequence'" -ForegroundColor Green
    Write-Host "EscapeSequence length: $($escapeSequence.Length)" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR in string building: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n3. Testing Console dimensions:" -ForegroundColor Cyan
try {
    Write-Host "Console.WindowWidth: $([Console]::WindowWidth)" -ForegroundColor Green
    Write-Host "Console.WindowHeight: $([Console]::WindowHeight)" -ForegroundColor Green
} catch {
    Write-Host "ERROR getting console dimensions: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== DEBUG COMPLETE ===" -ForegroundColor Yellow