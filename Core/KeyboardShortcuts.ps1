# KeyboardShortcuts.ps1 - Standardized keyboard shortcut system

class KeyboardShortcut {
    [System.ConsoleKey]$Key
    [System.ConsoleModifiers]$Modifiers
    [string]$Description
    [scriptblock]$Action
    [string]$Category
    [bool]$Global
    
    KeyboardShortcut() {}
    
    KeyboardShortcut([System.ConsoleKey]$key, [string]$description, [scriptblock]$action) {
        $this.Key = $key
        $this.Modifiers = [System.ConsoleModifiers]::None
        $this.Description = $description
        $this.Action = $action
        $this.Category = "General"
        $this.Global = $false
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
        
        # Convert key to readable format
        $keyName = switch ($this.Key) {
            ([System.ConsoleKey]::Enter) { "Enter" }
            ([System.ConsoleKey]::Escape) { "Esc" }
            ([System.ConsoleKey]::Spacebar) { "Space" }
            ([System.ConsoleKey]::Tab) { "Tab" }
            ([System.ConsoleKey]::Backspace) { "Backspace" }
            ([System.ConsoleKey]::Delete) { "Delete" }
            ([System.ConsoleKey]::UpArrow) { "↑" }
            ([System.ConsoleKey]::DownArrow) { "↓" }
            ([System.ConsoleKey]::LeftArrow) { "←" }
            ([System.ConsoleKey]::RightArrow) { "→" }
            ([System.ConsoleKey]::PageUp) { "PgUp" }
            ([System.ConsoleKey]::PageDown) { "PgDn" }
            ([System.ConsoleKey]::Home) { "Home" }
            ([System.ConsoleKey]::End) { "End" }
            default { $this.Key.ToString() }
        }
        
        $parts += $keyName
        return $parts -join "+"
    }
    
    [bool] Matches([System.ConsoleKeyInfo]$keyInfo) {
        return $keyInfo.Key -eq $this.Key -and $keyInfo.Modifiers -eq $this.Modifiers
    }
}

class KeyboardShortcutManager {
    hidden [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[KeyboardShortcut]]]$_shortcuts
    hidden [System.Collections.Generic.List[KeyboardShortcut]]$_globalShortcuts
    hidden [ThemeManager]$Theme
    
    KeyboardShortcutManager() {
        $this._shortcuts = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[KeyboardShortcut]]]::new()
        $this._globalShortcuts = [System.Collections.Generic.List[KeyboardShortcut]]::new()
        $this.InitializeStandardShortcuts()
    }
    
    [void] Initialize([ServiceContainer]$container) {
        $this.Theme = $container.GetService('ThemeManager')
    }
    
    [void] InitializeStandardShortcuts() {
        # Global navigation shortcuts
        $this.AddGlobalShortcut([System.ConsoleKey]::Tab, [System.ConsoleModifiers]::None, 
            "Next field", {}, "Navigation")
        $this.AddGlobalShortcut([System.ConsoleKey]::Tab, [System.ConsoleModifiers]::Shift, 
            "Previous field", {}, "Navigation")
        $this.AddGlobalShortcut([System.ConsoleKey]::F1, [System.ConsoleModifiers]::None, 
            "Show help", {}, "Help")
        $this.AddGlobalShortcut([System.ConsoleKey]::Escape, [System.ConsoleModifiers]::None, 
            "Cancel/Back", {}, "Navigation")
        
        # Standard component shortcuts
        $this.AddContextShortcut("ListBox", [System.ConsoleKey]::Enter, [System.ConsoleModifiers]::None,
            "Select item", {}, "Selection")
        $this.AddContextShortcut("ListBox", [System.ConsoleKey]::Spacebar, [System.ConsoleModifiers]::None,
            "Toggle item", {}, "Selection")
        
        $this.AddContextShortcut("TextBox", [System.ConsoleKey]::Enter, [System.ConsoleModifiers]::None,
            "Submit", {}, "Input")
        $this.AddContextShortcut("TextBox", [System.ConsoleKey]::A, [System.ConsoleModifiers]::Control,
            "Select all", {}, "Input")
        
        $this.AddContextShortcut("DataGrid", [System.ConsoleKey]::Enter, [System.ConsoleModifiers]::None,
            "Edit cell", {}, "Editing")
        $this.AddContextShortcut("DataGrid", [System.ConsoleKey]::F2, [System.ConsoleModifiers]::None,
            "Edit cell", {}, "Editing")
    }
    
    [void] AddGlobalShortcut([System.ConsoleKey]$key, [System.ConsoleModifiers]$modifiers, 
                             [string]$description, [scriptblock]$action, [string]$category) {
        $shortcut = [KeyboardShortcut]::new()
        $shortcut.Key = $key
        $shortcut.Modifiers = $modifiers
        $shortcut.Description = $description
        $shortcut.Action = $action
        $shortcut.Category = $category
        $shortcut.Global = $true
        
        $this._globalShortcuts.Add($shortcut)
    }
    
    [void] AddContextShortcut([string]$context, [System.ConsoleKey]$key, [System.ConsoleModifiers]$modifiers,
                              [string]$description, [scriptblock]$action, [string]$category) {
        $shortcut = [KeyboardShortcut]::new()
        $shortcut.Key = $key
        $shortcut.Modifiers = $modifiers
        $shortcut.Description = $description
        $shortcut.Action = $action
        $shortcut.Category = $category
        $shortcut.Global = $false
        
        if (-not $this._shortcuts.ContainsKey($context)) {
            $this._shortcuts[$context] = [System.Collections.Generic.List[KeyboardShortcut]]::new()
        }
        
        $this._shortcuts[$context].Add($shortcut)
    }
    
    [System.Collections.Generic.List[KeyboardShortcut]] GetShortcuts([string]$context) {
        $result = [System.Collections.Generic.List[KeyboardShortcut]]::new()
        
        # Add global shortcuts
        $result.AddRange($this._globalShortcuts)
        
        # Add context-specific shortcuts
        if ($context -and $this._shortcuts.ContainsKey($context)) {
            $result.AddRange($this._shortcuts[$context])
        }
        
        return $result
    }
    
    [string] RenderShortcutHelp([string]$context, [int]$maxWidth = 80) {
        $shortcuts = $this.GetShortcuts($context)
        if ($shortcuts.Count -eq 0) { return "" }
        
        # Group by category
        $categories = @{}
        foreach ($shortcut in $shortcuts) {
            if (-not $categories.ContainsKey($shortcut.Category)) {
                $categories[$shortcut.Category] = @()
            }
            $categories[$shortcut.Category] += $shortcut
        }
        
        $sb = Get-PooledStringBuilder 1024
        
        # Render categories
        $first = $true
        foreach ($category in $categories.Keys | Sort-Object) {
            if (-not $first) { $sb.AppendLine() }
            $first = $false
            
            # Category header
            if ($this.Theme) {
                $sb.Append($this.Theme.GetColor('accent'))
            }
            $sb.Append("${category}:")
            if ($this.Theme) {
                $sb.Append([VT]::Reset())
            }
            $sb.AppendLine()
            
            # Shortcuts in category
            foreach ($shortcut in $categories[$category]) {
                $keyText = $shortcut.GetDisplayText()
                $sb.Append("  ")
                
                if ($this.Theme) {
                    $sb.Append($this.Theme.GetColor('normal'))
                }
                $sb.Append($keyText.PadRight(15))
                
                if ($this.Theme) {
                    $sb.Append($this.Theme.GetColor('disabled'))
                }
                $sb.Append($shortcut.Description)
                
                if ($this.Theme) {
                    $sb.Append([VT]::Reset())
                }
                $sb.AppendLine()
            }
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    # Render minimal shortcut hints (for status bars)
    [string] RenderShortcutHints([string[]]$hints, [int]$maxWidth = 80) {
        if ($hints.Count -eq 0) { return "" }
        
        $sb = Get-PooledStringBuilder 256
        
        $first = $true
        $totalLength = 0
        
        foreach ($hint in $hints) {
            $parts = $hint -split ':'
            if ($parts.Count -ne 2) { continue }
            
            $key = $parts[0].Trim()
            $desc = $parts[1].Trim()
            
            $hintLength = $key.Length + $desc.Length + 5  # Space for formatting
            if ($totalLength + $hintLength -gt $maxWidth -and -not $first) {
                break
            }
            
            if (-not $first) {
                $sb.Append(" • ")
                $totalLength += 3
            }
            $first = $false
            
            if ($this.Theme) {
                $sb.Append($this.Theme.GetColor('accent'))
            }
            $sb.Append($key)
            if ($this.Theme) {
                $sb.Append($this.Theme.GetColor('disabled'))
            }
            $sb.Append(":$desc")
            
            $totalLength += $hintLength
        }
        
        if ($this.Theme) {
            $sb.Append([VT]::Reset())
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
}

# Extension for components to display shortcuts
class ShortcutHintBar : UIElement {
    [string[]]$Hints = @()
    hidden [KeyboardShortcutManager]$ShortcutManager
    
    [void] OnInitialize() {
        $this.ShortcutManager = $this.ServiceContainer.GetService('KeyboardShortcutManager')
        $this.Height = 1
    }
    
    [string] OnRender() {
        if (-not $this.ShortcutManager -or $this.Hints.Count -eq 0) {
            return ""
        }
        
        $sb = Get-PooledStringBuilder 256
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append($this.ShortcutManager.RenderShortcutHints($this.Hints, $this.Width))
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [void] SetContext([string]$context) {
        # Auto-generate hints from context
        $shortcuts = $this.ShortcutManager.GetShortcuts($context)
        $this.Hints = @()
        
        # Pick most important shortcuts
        $important = @("Enter", "Escape", "F1", "Tab")
        foreach ($imp in $important) {
            $shortcut = $shortcuts | Where-Object { $_.GetDisplayText() -eq $imp } | Select-Object -First 1
            if ($shortcut) {
                $this.Hints += "$($shortcut.GetDisplayText()):$($shortcut.Description)"
            }
        }
        
        $this.Invalidate()
    }
}