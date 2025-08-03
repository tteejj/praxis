#!/usr/bin/env pwsh
# Test script for ProjectsScreen with new UnifiedDataGrid

param(
    [switch]$Debug
)

try {
    # Set location to script directory
    Set-Location $PSScriptRoot
    
    # Load the application
    . ./Start.ps1
    
    # Navigate to Projects screen
    $screenManager = $global:ServiceContainer.GetService('ScreenManager')
    if ($screenManager) {
        $currentScreen = $screenManager.GetCurrent()
        
        # Simulate pressing 'p' to go to projects screen
        $pKey = [System.ConsoleKeyInfo]::new('p', [System.ConsoleKey]::P, $false, $false, $false)
        $currentScreen.HandleInput($pKey)
        
        Write-Host "`nProjectsScreen loaded with UnifiedDataGrid" -ForegroundColor Green
        Write-Host "Use arrow keys to navigate, 'n' for new project, 'e' to edit, 'q' to quit" -ForegroundColor Cyan
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    Read-Host "Press Enter to exit"
}