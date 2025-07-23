# ShortcutManager.ps1 - Centralized keyboard shortcut management service

enum ShortcutScope {
    Global      # Available everywhere
    Screen      # Available in specific screen types
    Context     # Available in specific contexts (e.g., when dialog is open)
}

class ShortcutDefinition {
    [string]$Id
    [string]$Name
    [string]$Description
    [System.ConsoleKey]$Key
    [System.ConsoleModifiers]$Modifiers
    [char]$KeyChar
    [ShortcutScope]$Scope
    [string]$ScreenType  # For Screen scope
    [string]$Context     # For Context scope
    [scriptblock]$Action
    [bool]$Enabled = $true
    [int]$Priority = 0   # Higher priority shortcuts are checked first
    
    ShortcutDefinition() {}
    
    [bool] Matches([System.ConsoleKeyInfo]$keyInfo) {
        # Check if this shortcut matches the pressed key
        if ($this.Key -ne [System.ConsoleKey]::None) {
            if ($keyInfo.Key -ne $this.Key) {
                return $false
            }
            if ($this.Modifiers -ne [System.ConsoleModifiers]::None) {
                if (($keyInfo.Modifiers -band $this.Modifiers) -ne $this.Modifiers) {
                    return $false
                }
            }
            return $true
        }
        elseif ($this.KeyChar -ne [char]0) {
            # Character-based shortcut
            return $keyInfo.KeyChar -eq $this.KeyChar
        }
        return $false
    }
    
    [string] GetDisplayText() {
        $parts = @()
        
        if ($this.Modifiers -band [System.ConsoleModifiers]::Control) {
            $parts += "Ctrl"
        }
        if ($this.Modifiers -band [System.ConsoleModifiers]::Alt) {
            $parts += "Alt"
        }
        if ($this.Modifiers -band [System.ConsoleModifiers]::Shift) {
            $parts += "Shift"
        }
        
        if ($this.Key -ne [System.ConsoleKey]::None) {
            $parts += $this.Key.ToString()
        }
        elseif ($this.KeyChar -ne [char]0) {
            $parts += $this.KeyChar.ToString()
        }
        
        return $parts -join "+"
    }
}

class ShortcutManager {
    hidden [System.Collections.Generic.List[ShortcutDefinition]]$Shortcuts
    hidden [Logger]$Logger
    hidden [EventBus]$EventBus
    
    ShortcutManager() {
        $this.Shortcuts = [System.Collections.Generic.List[ShortcutDefinition]]::new()
    }
    
    [void] Initialize([ServiceContainer]$container) {
        $this.Logger = $container.GetService('Logger')
        $this.EventBus = $container.GetService('EventBus')
        
        # Register default global shortcuts
        $this.RegisterDefaultShortcuts()
    }
    
    [void] RegisterDefaultShortcuts() {
        # Global shortcuts
        $this.RegisterShortcut(@{
            Id = "global.quit"
            Name = "Quit Application"
            Description = "Exit the application"
            Key = [System.ConsoleKey]::Q
            Modifiers = [System.ConsoleModifiers]::Control
            Scope = [ShortcutScope]::Global
            Priority = 100
            Action = {
                if ($global:ScreenManager) {
                    $global:ScreenManager.RequestExit()
                }
            }
        })
        
        $this.RegisterShortcut(@{
            Id = "global.command_palette"
            Name = "Command Palette"
            Description = "Open the command palette"
            KeyChar = ':'
            Scope = [ShortcutScope]::Global
            Priority = 90
            Action = {
                if ($global:ScreenManager) {
                    $global:ScreenManager.ShowCommandPalette()
                }
            }
        })
        
        $this.RegisterShortcut(@{
            Id = "global.command_palette_alt"
            Name = "Command Palette (Alt)"
            Description = "Open the command palette"
            KeyChar = '/'
            Scope = [ShortcutScope]::Global
            Priority = 90
            Action = {
                if ($global:ScreenManager) {
                    $global:ScreenManager.ShowCommandPalette()
                }
            }
        })
    }
    
    [void] RegisterShortcut([hashtable]$definition) {
        $shortcut = [ShortcutDefinition]::new()
        
        # Map hashtable properties to object
        foreach ($key in $definition.Keys) {
            if ($null -ne $shortcut.PSObject.Properties[$key]) {
                $shortcut.$key = $definition[$key]
            }
        }
        
        # Validate required properties
        if ([string]::IsNullOrEmpty($shortcut.Id)) {
            throw "Shortcut ID is required"
        }
        if (-not $shortcut.Action) {
            throw "Shortcut action is required"
        }
        
        # Remove existing shortcut with same ID
        $this.UnregisterShortcut($shortcut.Id)
        
        # Add new shortcut
        $this.Shortcuts.Add($shortcut)
        
        # Sort by priority (descending)
        $this.Shortcuts.Sort({ param($a, $b) $b.Priority.CompareTo($a.Priority) })
        
        if ($this.Logger) {
            $this.Logger.Debug("Registered shortcut: $($shortcut.Id) - $($shortcut.GetDisplayText())")
        }
    }
    
    [void] UnregisterShortcut([string]$id) {
        $existing = $this.Shortcuts | Where-Object { $_.Id -eq $id }
        if ($existing) {
            $this.Shortcuts.Remove($existing) | Out-Null
        }
    }
    
    [bool] HandleKeyPress([System.ConsoleKeyInfo]$keyInfo, [string]$currentScreen, [string]$currentContext) {
        # Find matching shortcuts
        $candidates = $this.Shortcuts | Where-Object {
            $_.Enabled -and $_.Matches($keyInfo)
        }
        
        # Filter by scope
        $applicable = @()
        foreach ($shortcut in $candidates) {
            switch ($shortcut.Scope) {
                ([ShortcutScope]::Global) {
                    $applicable += $shortcut
                }
                ([ShortcutScope]::Screen) {
                    if ($shortcut.ScreenType -eq $currentScreen -or 
                        [string]::IsNullOrEmpty($shortcut.ScreenType)) {
                        $applicable += $shortcut
                    }
                }
                ([ShortcutScope]::Context) {
                    if ($shortcut.Context -eq $currentContext -or
                        [string]::IsNullOrEmpty($shortcut.Context)) {
                        $applicable += $shortcut
                    }
                }
            }
        }
        
        # Execute the highest priority applicable shortcut
        if ($applicable.Count -gt 0) {
            $shortcut = $applicable[0]  # Already sorted by priority
            
            if ($this.Logger) {
                $this.Logger.Debug("Executing shortcut: $($shortcut.Id)")
            }
            
            # Publish event before execution
            if ($this.EventBus) {
                $this.EventBus.Publish('shortcut.executing', @{
                    ShortcutId = $shortcut.Id
                    Key = $keyInfo
                })
            }
            
            try {
                # Execute the action
                & $shortcut.Action
                
                # Publish success event
                if ($this.EventBus) {
                    $this.EventBus.Publish('shortcut.executed', @{
                        ShortcutId = $shortcut.Id
                        Key = $keyInfo
                    })
                }
                
                return $true
            }
            catch {
                if ($this.Logger) {
                    $this.Logger.Error("Error executing shortcut $($shortcut.Id): $_")
                }
                return $false
            }
        }
        
        return $false
    }
    
    [ShortcutDefinition[]] GetShortcuts([ShortcutScope]$scope, [string]$screenType) {
        return $this.Shortcuts | Where-Object {
            $_.Scope -eq $scope -and
            ($_.ScreenType -eq $screenType -or [string]::IsNullOrEmpty($_.ScreenType))
        }
    }
    
    [ShortcutDefinition[]] GetAllShortcuts() {
        return $this.Shortcuts
    }
    
    [hashtable] GetShortcutMap() {
        # Returns a hashtable for easy display in UI
        $map = @{}
        
        foreach ($shortcut in $this.Shortcuts) {
            $key = $shortcut.GetDisplayText()
            if (-not $map.ContainsKey($key)) {
                $map[$key] = @()
            }
            $map[$key] += @{
                Name = $shortcut.Name
                Description = $shortcut.Description
                Scope = $shortcut.Scope
                ScreenType = $shortcut.ScreenType
            }
        }
        
        return $map
    }
    
    [void] EnableShortcut([string]$id) {
        $shortcut = $this.Shortcuts | Where-Object { $_.Id -eq $id }
        if ($shortcut) {
            $shortcut.Enabled = $true
        }
    }
    
    [void] DisableShortcut([string]$id) {
        $shortcut = $this.Shortcuts | Where-Object { $_.Id -eq $id }
        if ($shortcut) {
            $shortcut.Enabled = $false
        }
    }
    
    [string] GetShortcutHelp([ShortcutScope]$scope = [ShortcutScope]::Global, [string]$screenType = "") {
        $sb = [System.Text.StringBuilder]::new()
        $shortcutList = $this.GetShortcuts($scope, $screenType)
        
        if ($shortcutList.Count -gt 0) {
            $grouped = $shortcutList | Group-Object { $_.GetDisplayText() }
            
            foreach ($group in $grouped | Sort-Object Name) {
                $sb.AppendLine("$($group.Name):")
                foreach ($shortcut in $group.Group) {
                    $sb.AppendLine("  - $($shortcut.Name): $($shortcut.Description)")
                }
            }
        }
        
        return $sb.ToString()
    }
}