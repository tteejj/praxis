# KeySettingsDialog.ps1 - User-configurable key mappings settings dialog
# Provides a full-screen interface for users to customize keyboard shortcuts

class KeySettingsDialog {
    [KeyMappingService]$KeyService
    [hashtable]$Categories
    [string[]]$CategoryOrder
    [int]$SelectedCategory = 0
    [int]$SelectedAction = 0
    [int]$Width
    [int]$Height
    [bool]$IsEditingKey = $false
    [string]$EditingAction = ""
    [bool]$HasChanges = $false
    
    KeySettingsDialog() {
        $this.KeyService = [KeyMappingService]::new()
        $this.Categories = $this.KeyService.GetMappingsByCategory()
        $this.CategoryOrder = @("Navigation", "Task Management", "Filters", "Time Entry", "List Navigation", "Editing", "Theme & Settings")
    }
    
    [bool] Show([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
        [Console]::CursorVisible = $false
        
        try {
            while ($true) {
                # Render the dialog
                Write-Host -NoNewline $this.Render()
                
                # Handle input
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    $result = $this.HandleInput($key)
                    
                    if ($result -eq "save") {
                        if ($this.HasChanges) {
                            $this.KeyService.SaveMappings()
                        }
                        return $true
                    } elseif ($result -eq "cancel") {
                        return $false
                    }
                }
                
                Start-Sleep -Milliseconds 50
            }
        } finally {
            [Console]::CursorVisible = $true
        }
        
        return $false  # PowerShell requires this
    }
    
    [string] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($this.IsEditingKey) {
            return $this.HandleKeyEditInput($key)
        }
        
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) {
                return "cancel"
            }
            ([System.ConsoleKey]::Enter) {
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    return "save"
                } else {
                    $this.StartEditingSelectedKey()
                }
            }
            ([System.ConsoleKey]::S) {
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    return "save"
                }
            }
            ([System.ConsoleKey]::LeftArrow) {
                if ($this.SelectedCategory -gt 0) {
                    $this.SelectedCategory--
                    $this.SelectedAction = 0
                }
            }
            ([System.ConsoleKey]::RightArrow) {
                if ($this.SelectedCategory -lt ($this.CategoryOrder.Count - 1)) {
                    $this.SelectedCategory++
                    $this.SelectedAction = 0
                }
            }
            ([System.ConsoleKey]::UpArrow) {
                if ($this.SelectedAction -gt 0) {
                    $this.SelectedAction--
                }
            }
            ([System.ConsoleKey]::DownArrow) {
                $categoryName = $this.CategoryOrder[$this.SelectedCategory]
                $actionsInCategory = $this.Categories[$categoryName]
                if ($this.SelectedAction -lt ($actionsInCategory.Count - 1)) {
                    $this.SelectedAction++
                }
            }
            ([System.ConsoleKey]::R) {
                # Reset to defaults
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    $this.KeyService.ResetToDefaults()
                    $this.HasChanges = $true
                }
            }
        }
        
        return "continue"
    }
    
    [string] HandleKeyEditInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) {
                $this.IsEditingKey = $false
                $this.EditingAction = ""
                return "continue"
            }
            default {
                # Capture the new key mapping
                $keyName = $key.Key.ToString()
                $modifiersName = if ($key.Modifiers -eq [System.ConsoleModifiers]::None) { "None" } else { $key.Modifiers.ToString() }
                
                # Validate the mapping (check for conflicts)
                if ($this.KeyService.ValidateMapping($this.EditingAction, $keyName, $modifiersName)) {
                    $mapping = $this.KeyService.GetMapping($this.EditingAction)
                    $this.KeyService.SetMapping($this.EditingAction, $keyName, $modifiersName, $mapping.Description)
                    $this.HasChanges = $true
                }
                
                $this.IsEditingKey = $false
                $this.EditingAction = ""
                return "continue"
            }
        }
        
        return "continue"  # PowerShell requires this
    }
    
    [void] StartEditingSelectedKey() {
        $categoryName = $this.CategoryOrder[$this.SelectedCategory]
        $actionsInCategory = $this.Categories[$categoryName]
        if ($this.SelectedAction -lt $actionsInCategory.Count) {
            $this.EditingAction = $actionsInCategory[$this.SelectedAction]
            $this.IsEditingKey = $true
        }
    }
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Clear screen
        [void]$sb.Append([VT]::Clear())
        [void]$sb.Append([VT]::MoveTo(0, 0))
        
        # Header
        [void]$sb.Append([AppThemeManager]::GetColor("Header"))
        [void]$sb.Append("KEYBOARD SETTINGS".PadRight($this.Width))
        [void]$sb.Append([VT]::Reset())
        
        # Instructions
        [void]$sb.Append([VT]::MoveTo(0, 2))
        [void]$sb.Append([AppThemeManager]::GetColor("Text"))
        [void]$sb.Append("Use ← → to switch categories, ↑ ↓ to navigate actions")
        [void]$sb.Append([VT]::MoveTo(0, 3))
        [void]$sb.Append("Press Enter to edit a key mapping, Ctrl+S to save, Escape to cancel")
        [void]$sb.Append([VT]::MoveTo(0, 4))
        [void]$sb.Append("Ctrl+R to reset all keys to defaults")
        [void]$sb.Append([VT]::Reset())
        
        # Render categories as tabs
        [void]$sb.Append([VT]::MoveTo(0, 6))
        for ($i = 0; $i -lt $this.CategoryOrder.Count; $i++) {
            $categoryName = $this.CategoryOrder[$i]
            if ($i -eq $this.SelectedCategory) {
                [void]$sb.Append([AppThemeManager]::GetColor("Selection"))
                [void]$sb.Append("[$categoryName] ")
            } else {
                [void]$sb.Append([AppThemeManager]::GetColor("Text"))
                [void]$sb.Append(" $categoryName  ")
            }
        }
        [void]$sb.Append([VT]::Reset())
        
        # Render current category actions
        $startRow = 8
        $categoryName = $this.CategoryOrder[$this.SelectedCategory]
        $actionsInCategory = $this.Categories[$categoryName]
        
        [void]$sb.Append([VT]::MoveTo(0, $startRow))
        [void]$sb.Append([AppThemeManager]::GetColor("Header"))
        [void]$sb.Append("Action".PadRight(30))
        [void]$sb.Append("Key".PadRight(20))
        [void]$sb.Append("Description")
        [void]$sb.Append([VT]::Reset())
        
        for ($i = 0; $i -lt $actionsInCategory.Count; $i++) {
            $actionName = $actionsInCategory[$i]
            $mapping = $this.KeyService.GetMapping($actionName)
            $row = $startRow + 2 + $i
            
            [void]$sb.Append([VT]::MoveTo(0, $row))
            
            if ($i -eq $this.SelectedAction) {
                if ($this.IsEditingKey -and $this.EditingAction -eq $actionName) {
                    [void]$sb.Append([AppThemeManager]::GetColor("EditHighlight"))
                    [void]$sb.Append("► $actionName".PadRight(30))
                    [void]$sb.Append("PRESS NEW KEY...".PadRight(20))
                } else {
                    [void]$sb.Append([AppThemeManager]::GetColor("Selection"))
                    [void]$sb.Append("► $actionName".PadRight(30))
                    $keyDisplay = if ($mapping.Modifiers -eq "None") { $mapping.Key } else { "$($mapping.Modifiers)+$($mapping.Key)" }
                    [void]$sb.Append($keyDisplay.PadRight(20))
                }
            } else {
                [void]$sb.Append([AppThemeManager]::GetColor("Text"))
                [void]$sb.Append("  $actionName".PadRight(30))
                $keyDisplay = if ($mapping.Modifiers -eq "None") { $mapping.Key } else { "$($mapping.Modifiers)+$($mapping.Key)" }
                [void]$sb.Append($keyDisplay.PadRight(20))
            }
            
            if ($mapping) {
                [void]$sb.Append($mapping.Description)
            }
            [void]$sb.Append([VT]::Reset())
        }
        
        # Status line
        $statusRow = $this.Height - 2
        [void]$sb.Append([VT]::MoveTo(0, $statusRow))
        [void]$sb.Append([AppThemeManager]::GetColor("Header"))
        if ($this.HasChanges) {
            [void]$sb.Append("UNSAVED CHANGES - Press Ctrl+S to save".PadRight($this.Width))
        } else {
            [void]$sb.Append("No changes".PadRight($this.Width))
        }
        [void]$sb.Append([VT]::Reset())
        
        return $sb.ToString()
    }
}