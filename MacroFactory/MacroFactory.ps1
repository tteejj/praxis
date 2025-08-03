#!/usr/bin/env pwsh
# MacroFactory.ps1 - Standalone Visual Macro Factory for IDEA automation

param(
    [switch]$Debug
)

# Set location to script directory
Set-Location $PSScriptRoot

# Store debug flag globally
$global:Debug = $Debug

# Set window title
$Host.UI.RawUI.WindowTitle = "MacroFactory - Visual IDEA Macro Builder"

# Initialize console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::CursorVisible = $false

# Load core components
Write-Host "Loading MacroFactory..." -ForegroundColor Cyan

try {
    # Core
    . "$PSScriptRoot/Core/VT100.ps1"
    . "$PSScriptRoot/Core/Logger.ps1"
    
    # Enable debug if requested
    if ($Debug) {
        $global:Logger.EnableDebug = $true
    }
    
    # Models
    . "$PSScriptRoot/Models/BaseAction.ps1"
    . "$PSScriptRoot/Models/SampleActions.ps1"
    
    # Services
    . "$PSScriptRoot/Services/MacroContextManager.ps1"
    . "$PSScriptRoot/Services/MacroService.ps1"
    
    # Components
    . "$PSScriptRoot/Components/SimpleList.ps1"
    . "$PSScriptRoot/Components/SimpleGrid.ps1"
    . "$PSScriptRoot/Components/SimpleDialog.ps1"
    
    # Screens
    . "$PSScriptRoot/Screens/MacroFactoryScreen.ps1"
    
} catch {
    Write-Host "`nFailed to load components: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}

# Error handler
trap {
    [Console]::CursorVisible = $true
    Write-Host "`nFatal error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}

# Welcome message
Clear-Host
Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║                    MACROFACTORY v1.0                          ║
║              Visual IDEA Macro Builder                        ║
║                                                                ║
║  Build powerful IDEA automation macros visually!              ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host "`nPress any key to start..." -ForegroundColor Gray
[Console]::ReadKey($true) | Out-Null

# Create and run application
try {
    $app = [MacroFactoryScreen]::new()
    $app.Run()
} catch {
    [Console]::CursorVisible = $true
    Write-Host "`nApplication error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}

# Cleanup
[Console]::CursorVisible = $true
Write-Host "`nThank you for using MacroFactory!" -ForegroundColor Green