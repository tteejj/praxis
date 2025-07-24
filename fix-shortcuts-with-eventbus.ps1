#!/usr/bin/env pwsh
# Fix shortcuts by using EventBus like CommandPalette does

Write-Host "Fixing shortcuts to use EventBus approach..." -ForegroundColor Cyan

# Create a new simple shortcut handler that publishes events
$shortcutHandler = @'
# SimpleShortcutHandler.ps1 - Direct keyboard shortcuts via EventBus

class SimpleShortcutHandler {
    hidden [EventBus]$EventBus
    hidden [Logger]$Logger
    
    [void] Initialize([ServiceContainer]$container) {
        $this.EventBus = $container.GetService('EventBus')
        $this.Logger = $container.GetService('Logger')
    }
    
    [bool] HandleKeyPress([System.ConsoleKeyInfo]$keyInfo, [string]$currentScreen) {
        # Only handle character keys when no modifiers are pressed
        if ($keyInfo.Modifiers -ne [System.ConsoleModifiers]::None) {
            return $false
        }
        
        $char = [char]::ToLower($keyInfo.KeyChar)
        
        # Handle shortcuts based on current screen
        switch ($currentScreen) {
            "ProjectsScreen" {
                switch ($char) {
                    'n' {
                        $this.PublishCommand('NewProject', 'ProjectsScreen')
                        return $true
                    }
                    'e' {
                        $this.PublishCommand('EditProject', 'ProjectsScreen')
                        return $true
                    }
                    'd' {
                        $this.PublishCommand('DeleteProject', 'ProjectsScreen')
                        return $true
                    }
                    'r' {
                        $this.PublishCommand('RefreshProjects', 'ProjectsScreen')
                        return $true
                    }
                    'v' {
                        $this.PublishCommand('ViewProject', 'ProjectsScreen')
                        return $true
                    }
                }
            }
            "TaskScreen" {
                switch ($char) {
                    'n' {
                        $this.PublishCommand('NewTask', 'TaskScreen')
                        return $true
                    }
                    'e' {
                        $this.PublishCommand('EditTask', 'TaskScreen')
                        return $true
                    }
                    'd' {
                        $this.PublishCommand('DeleteTask', 'TaskScreen')
                        return $true
                    }
                    'r' {
                        $this.PublishCommand('RefreshTasks', 'TaskScreen')
                        return $true
                    }
                }
            }
        }
        
        return $false
    }
    
    hidden [void] PublishCommand([string]$command, [string]$target) {
        if ($this.Logger) {
            $this.Logger.Debug("SimpleShortcutHandler: Publishing command $command for $target")
        }
        
        if ($this.EventBus) {
            $this.EventBus.Publish([EventNames]::CommandExecuted, @{
                Command = $command
                Target = $target
            })
        }
    }
}
'@

# Save the new handler
$shortcutHandler | Set-Content "Services/SimpleShortcutHandler.ps1" -Force
Write-Host "Created SimpleShortcutHandler.ps1" -ForegroundColor Green

# Update Start.ps1 to load it
$startContent = Get-Content "Start.ps1" -Raw
$startContent = $startContent -replace '("Services/ShortcutManager.ps1")', @'
"Services/ShortcutManager.ps1",
    "Services/SimpleShortcutHandler.ps1"
'@
$startContent | Set-Content "Start.ps1" -Force

# Add initialization after ShortcutManager
$startContent = Get-Content "Start.ps1" -Raw
$startContent = $startContent -replace '(\$shortcutManager\.Initialize\(\$global:ServiceContainer\)\s*\$global:ServiceContainer\.Register\("ShortcutManager", \$shortcutManager\))', @'
$1

# SimpleShortcutHandler (uses EventBus like CommandPalette)
$simpleHandler = [SimpleShortcutHandler]::new()
$simpleHandler.Initialize($global:ServiceContainer)
$global:ServiceContainer.Register("SimpleShortcutHandler", $simpleHandler)
'@
$startContent | Set-Content "Start.ps1" -Force

# Update ScreenManager to use SimpleShortcutHandler
$smContent = Get-Content "Core/ScreenManager.ps1" -Raw

# Add the simple handler
$smContent = $smContent -replace '(hidden \[ShortcutManager\]\$_shortcutManager)', @'
$1
    hidden [SimpleShortcutHandler]$_simpleHandler
'@

# Initialize it
$smContent = $smContent -replace '(\$this\._shortcutManager = \$services\.GetService\(''ShortcutManager''\))', @'
$1
        $this._simpleHandler = $services.GetService('SimpleShortcutHandler')
'@

# Use it for character shortcuts
$smContent = $smContent -replace '(# 1\. Check ShortcutManager for global shortcuts first)', @'
# 1. Check for simple character shortcuts first (like CommandPalette)
                        if ($this._simpleHandler -and $key.KeyChar -ne [char]0) {
                            $currentScreenType = if ($this._activeScreen) { $this._activeScreen.GetType().Name } else { "" }
                            
                            if ($this._simpleHandler.HandleKeyPress($key, $currentScreenType)) {
                                $handled = $true
                                if ($global:Logger) {
                                    $global:Logger.Debug("Key handled by SimpleShortcutHandler")
                                }
                            }
                        }
                        
                        # 2. Check ShortcutManager for global shortcuts
'@

# Fix the numbering
$smContent = $smContent -replace '# 2\. Command Palette override', '# 3. Command Palette override'
$smContent = $smContent -replace '# 3\. Fallback to hardcoded', '# 4. Fallback to hardcoded'
$smContent = $smContent -replace '# 4\. Tab navigation', '# 5. Tab navigation'
$smContent = $smContent -replace '# 5\. If not handled', '# 6. If not handled'

$smContent | Set-Content "Core/ScreenManager.ps1" -Force

Write-Host "`nDone! Shortcuts now work exactly like CommandPalette:" -ForegroundColor Green
Write-Host "- They publish EventBus events" -ForegroundColor Gray
Write-Host "- Screens already listen for these events" -ForegroundColor Gray
Write-Host "- No complex ShortcutManager registration needed" -ForegroundColor Gray
Write-Host "`nTest with: pwsh -File Start.ps1" -ForegroundColor Yellow