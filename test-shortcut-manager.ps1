#!/usr/bin/env pwsh
# test-shortcut-manager.ps1 - Test the ShortcutManager service

param(
    [switch]$Debug
)

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $scriptDir

try {
    # Source the main startup script to load all classes
    . ./Start.ps1 -Debug:$Debug -NoLaunch
    
    Write-Host "`n=== Testing ShortcutManager ===" -ForegroundColor Cyan
    
    # Get the ShortcutManager
    $shortcutManager = $global:ServiceContainer.GetService('ShortcutManager')
    
    if (-not $shortcutManager) {
        Write-Host "ShortcutManager not found!" -ForegroundColor Red
        return
    }
    
    Write-Host "ShortcutManager loaded successfully" -ForegroundColor Green
    
    # Test 1: Register a screen-specific shortcut
    Write-Host "`n--- Test 1: Register screen-specific shortcut ---" -ForegroundColor Yellow
    $shortcutManager.RegisterShortcut(@{
        Id = "projects.new"
        Name = "New Project"
        Description = "Create a new project"
        KeyChar = 'n'
        Scope = [ShortcutScope]::Screen
        ScreenType = "ProjectsScreen"
        Priority = 50
        Action = {
            Write-Host "New Project shortcut triggered!" -ForegroundColor Green
        }
    })
    Write-Host "Registered 'n' key for ProjectsScreen" -ForegroundColor Green
    
    # Test 2: Register a context-specific shortcut
    Write-Host "`n--- Test 2: Register context-specific shortcut ---" -ForegroundColor Yellow
    $shortcutManager.RegisterShortcut(@{
        Id = "dialog.confirm"
        Name = "Confirm"
        Description = "Confirm dialog action"
        KeyChar = 'y'
        Scope = [ShortcutScope]::Context
        Context = "Dialog"
        Priority = 60
        Action = {
            Write-Host "Dialog confirmed!" -ForegroundColor Green
        }
    })
    Write-Host "Registered 'y' key for Dialog context" -ForegroundColor Green
    
    # Test 3: Display all registered shortcuts
    Write-Host "`n--- Test 3: Display all shortcuts ---" -ForegroundColor Yellow
    $allShortcuts = $shortcutManager.GetAllShortcuts()
    foreach ($shortcut in $allShortcuts) {
        Write-Host "  $($shortcut.GetDisplayText()) - $($shortcut.Name) [$($shortcut.Scope)]"
    }
    
    # Test 4: Test key matching
    Write-Host "`n--- Test 4: Test key matching ---" -ForegroundColor Yellow
    $testKey = [System.ConsoleKeyInfo]::new('n', [System.ConsoleKey]::N, $false, $false, $false)
    
    Write-Host "Testing 'n' key in ProjectsScreen context:"
    $handled = $shortcutManager.HandleKeyPress($testKey, "ProjectsScreen", "")
    Write-Host "  Handled: $handled" -ForegroundColor $(if ($handled) { "Green" } else { "Red" })
    
    Write-Host "Testing 'n' key in TaskScreen context:"
    $handled = $shortcutManager.HandleKeyPress($testKey, "TaskScreen", "")
    Write-Host "  Handled: $handled" -ForegroundColor $(if ($handled) { "Green" } else { "Red" })
    
    # Test 5: Test shortcut help
    Write-Host "`n--- Test 5: Shortcut help ---" -ForegroundColor Yellow
    Write-Host "Global shortcuts:"
    Write-Host $shortcutManager.GetShortcutHelp([ShortcutScope]::Global)
    
    # Test 6: Create a demo screen that uses ShortcutManager
    Write-Host "`n--- Test 6: Demo screen with shortcuts ---" -ForegroundColor Yellow
    
    class DemoScreen : Screen {
        DemoScreen() : base() {
            $this.Title = "Demo Screen with Shortcuts"
        }
        
        [void] OnInitialize() {
            # Register screen-specific shortcuts
            $shortcutManager = $this.ServiceContainer.GetService('ShortcutManager')
            if ($shortcutManager) {
                # Register F1 for help
                $shortcutManager.RegisterShortcut(@{
                    Id = "demo.help"
                    Name = "Show Help"
                    Description = "Display help information"
                    Key = [System.ConsoleKey]::F1
                    Scope = [ShortcutScope]::Screen
                    ScreenType = "DemoScreen"
                    Priority = 50
                    Action = {
                        Write-Host "`nHelp: This is a demo screen showing ShortcutManager integration" -ForegroundColor Cyan
                    }
                })
                
                # Register 'a' for action
                $shortcutManager.RegisterShortcut(@{
                    Id = "demo.action"
                    Name = "Demo Action"
                    Description = "Perform a demo action"
                    KeyChar = 'a'
                    Scope = [ShortcutScope]::Screen
                    ScreenType = "DemoScreen"
                    Priority = 50
                    Action = {
                        Write-Host "`nDemo action executed!" -ForegroundColor Green
                    }
                })
            }
        }
        
        [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
            # Screen-specific shortcuts are now handled by ShortcutManager in ScreenManager
            # This method only needs to handle special cases
            
            if ($key.Key -eq [System.ConsoleKey]::Escape) {
                $this.Active = $false
                return $true
            }
            
            return $false
        }
        
        [string] OnRender() {
            $sb = [System.Text.StringBuilder]::new()
            
            $sb.AppendLine()
            $sb.AppendLine("  Demo Screen - ShortcutManager Integration")
            $sb.AppendLine()
            $sb.AppendLine("  Available shortcuts:")
            $sb.AppendLine("    F1     - Show Help")
            $sb.AppendLine("    a      - Demo Action")
            $sb.AppendLine("    Ctrl+Q - Quit")
            $sb.AppendLine("    Esc    - Exit this screen")
            $sb.AppendLine()
            $sb.AppendLine("  Try pressing the shortcuts!")
            
            return $sb.ToString()
        }
    }
    
    # Run the demo screen
    Write-Host "Starting demo screen..." -ForegroundColor Green
    Write-Host "Press any key to continue..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    # Create and run the demo
    $demoScreen = [DemoScreen]::new()
    $screenManager = [ScreenManager]::new($global:ServiceContainer)
    $global:ScreenManager = $screenManager
    $screenManager.Push($demoScreen)
    $screenManager.Run()
    
    Write-Host "`nDemo completed!" -ForegroundColor Green
    
} finally {
    Pop-Location
}