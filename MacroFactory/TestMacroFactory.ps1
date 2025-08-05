#!/usr/bin/env pwsh
# TestMacroFactory.ps1 - Minimal test of MacroFactory

param(
    [switch]$Debug
)

# Set location to script directory
Set-Location $PSScriptRoot

# Set window title
$Host.UI.RawUI.WindowTitle = "TestMacroFactory"

# Initialize console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::CursorVisible = $false

Write-Host "Loading minimal test..." -ForegroundColor Cyan

try {
    # Load core components
    . "$PSScriptRoot/Core/VT100.ps1"
    . "$PSScriptRoot/Core/Logger.ps1"
    
    # Load complete Praxis architecture 
    $praxisRoot = Split-Path $PSScriptRoot -Parent
    
    # Core infrastructure
    . "$praxisRoot/Core/StringBuilderPool.ps1"
    . "$praxisRoot/Core/StringCache.ps1"
    . "$praxisRoot/Core/VT100.ps1" 
    . "$praxisRoot/Core/ServiceContainer.ps1"
    . "$praxisRoot/Services/EventBus.ps1"
    . "$praxisRoot/Core/ThemeValidator.ps1"
    . "$praxisRoot/Services/ThemeManager.ps1"
    
    # Base classes hierarchy
    . "$praxisRoot/Base/UIElement.ps1"
    . "$praxisRoot/Base/Container.ps1" 
    . "$praxisRoot/Base/FocusableComponent.ps1"
    . "$praxisRoot/Base/Screen.ps1"
    
    Write-Host "Praxis loaded successfully" -ForegroundColor Green
    
} catch {
    Write-Host "Failed to load: $_" -ForegroundColor Red
    exit 1
}

# Simple test screen
class TestMacroFactoryScreen : Screen {
    [int]$FocusedPane = 0
    
    TestMacroFactoryScreen() : base() {
        $this.Title = "Test MacroFactory"
    }
    
    [string] OnRender() {
        $sb = [System.Text.StringBuilder]::new()
        
        $sb.Append("┌──────────────────┬─────────────────────┬──────────────────┐`n")
        $sb.Append("│📚 Component Library│🔧 Macro Sequence   │🎯 Context        │`n")
        $sb.Append("├──────────────────┼─────────────────────┼──────────────────┤`n")
        $sb.Append("│⚙️ Action 1       │No actions yet       │No variables      │`n")
        $sb.Append("│📊 Action 2       │                     │                  │`n")
        $sb.Append("│📤 Action 3       │                     │                  │`n")
        $sb.Append("└──────────────────┴─────────────────────┴──────────────────┘`n")
        $sb.Append("Tab:Switch | Enter:Add | Q:Quit`n")
        
        return $sb.ToString()
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        switch ($key.KeyChar) {
            'q' { return $false }
            't' {
                $this.FocusedPane = ($this.FocusedPane + 1) % 3
                return $true
            }
        }
        return $false
    }
}

Write-Host "Creating test screen..." -ForegroundColor Gray

# Initialize service container
$global:ServiceContainer = [ServiceContainer]::new()
$global:ServiceContainer.Register("EventBus", [EventBus]::new())

try {
    $app = [TestMacroFactoryScreen]::new()
    $app.Initialize($global:ServiceContainer)
    $app.SetBounds(0, 0, [Console]::WindowWidth, [Console]::WindowHeight)
    
    Write-Host "Test screen created successfully" -ForegroundColor Green
    
    # Simple run loop
    [Console]::CursorVisible = $false
    $running = $true
    
    while ($running) {
        Clear-Host
        $content = $app.OnRender()
        Write-Host -NoNewline $content
        
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            
            if ($key.KeyChar -eq 'q' -or $key.Key -eq [System.ConsoleKey]::Escape) {
                $running = $false
            } else {
                $app.HandleScreenInput($key)
            }
        }
        
        Start-Sleep -Milliseconds 100
    }
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}

[Console]::CursorVisible = $true
Write-Host "Test completed" -ForegroundColor Green