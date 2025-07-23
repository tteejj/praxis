# ShortcutManager.ps1 - Context-aware key binding system
# Adapted from AxiomPhoenix KeybindingService with PRAXIS performance optimizations

class ShortcutManager {
    hidden [System.Collections.Generic.Stack[hashtable]]$_contextStack
    hidden [hashtable]$_globalBindings
    
    ShortcutManager() {
        $this._contextStack = [System.Collections.Generic.Stack[hashtable]]::new()
        $this._globalBindings = @{}
        $this._InitializeDefaults()
    }
    
    hidden [void] _InitializeDefaults() {
        # Universal shortcuts (always available)
        $this._globalBindings["CTRL+Q"] = { 
            try { $global:ScreenManager.GetActiveScreen().Active = $false } catch { }
        }
        $this._globalBindings["/"] = { 
            try { 
                $mainScreen = $global:ScreenManager.GetActiveScreen()
                $mainScreen.CommandPalette.Show()
            } catch { }
        }
        $this._globalBindings[":"] = { 
            try { 
                $mainScreen = $global:ScreenManager.GetActiveScreen()
                $mainScreen.CommandPalette.Show()
            } catch { }
        }
        
        # Tab navigation - handled by FocusManager
        $this._globalBindings["TAB"] = { 
            try {
                $focusManager = $global:ServiceContainer.GetService("FocusManager")
                $focusManager.FocusNext()
            } catch { }
        }
        $this._globalBindings["SHIFT+TAB"] = { 
            try {
                $focusManager = $global:ServiceContainer.GetService("FocusManager")
                $focusManager.FocusPrevious()
            } catch { }
        }
    }
    
    # Context management for screens/dialogs
    [void] PushContext([hashtable]$bindings) {
        $this._contextStack.Push($bindings)
    }
    
    [void] PopContext() {
        if ($this._contextStack.Count -gt 0) { $this._contextStack.Pop() | Out-Null }
    }
    
    # Global shortcut registration
    [void] RegisterGlobal([string]$keyPattern, [scriptblock]$action) {
        $this._globalBindings[$keyPattern.ToUpper()] = $action
    }
    
    # Fast input processing (performance critical)
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        $keyString = $this._GetKeyString($keyInfo)
        
        if ($global:Logger) {
            $global:Logger.Debug("ShortcutManager.HandleInput: Processing key '$keyString'")
        }
        
        # Priority 1: Current context (screen/dialog)
        if ($this._contextStack.Count -gt 0) {
            $context = $this._contextStack.Peek()
            if ($context.ContainsKey($keyString)) {
                if ($global:Logger) {
                    $global:Logger.Debug("ShortcutManager: Executing context shortcut: $keyString")
                }
                try {
                    & $context[$keyString]
                    return $true
                } catch {
                    if ($global:Logger) {
                        $global:Logger.LogException($_, "Error executing shortcut: $keyString")
                    }
                    return $false
                }
            }
        }
        
        # Priority 2: Global bindings
        if ($this._globalBindings.ContainsKey($keyString)) {
            if ($global:Logger) {
                $global:Logger.Debug("ShortcutManager: Executing global shortcut: $keyString")
            }
            try {
                & $this._globalBindings[$keyString]
                return $true
            } catch {
                if ($global:Logger) {
                    $global:Logger.LogException($_, "Error executing global shortcut: $keyString")
                }
                return $false
            }
        }
        
        if ($global:Logger) {
            $global:Logger.Debug("ShortcutManager: No binding found for: $keyString")
        }
        return $false
    }
    
    # Optimized key string generation (cached patterns for speed)
    hidden [string] _GetKeyString([System.ConsoleKeyInfo]$keyInfo) {
        $parts = [System.Collections.Generic.List[string]]::new()
        
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Control) { $parts.Add("CTRL") }
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Alt) { $parts.Add("ALT") }
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift) { $parts.Add("SHIFT") }
        
        # Fast key mapping (performance optimized)
        $keyName = switch ($keyInfo.Key) {
            ([System.ConsoleKey]::Tab) { "TAB" }
            ([System.ConsoleKey]::Enter) { "ENTER" }
            ([System.ConsoleKey]::Escape) { "ESCAPE" }
            ([System.ConsoleKey]::Delete) { "DELETE" }
            ([System.ConsoleKey]::F5) { "F5" }
            ([System.ConsoleKey]::UpArrow) { "UP" }
            ([System.ConsoleKey]::DownArrow) { "DOWN" }
            ([System.ConsoleKey]::LeftArrow) { "LEFT" }
            ([System.ConsoleKey]::RightArrow) { "RIGHT" }
            ([System.ConsoleKey]::Spacebar) { "SPACE" }
            default { 
                # For printable characters (including symbols), use the character itself
                if ($keyInfo.KeyChar -and [char]::IsControl($keyInfo.KeyChar) -eq $false) {
                    # Don't uppercase symbols like / and :
                    if ([char]::IsLetter($keyInfo.KeyChar)) {
                        $keyInfo.KeyChar.ToString().ToUpper()
                    } else {
                        $keyInfo.KeyChar.ToString()
                    }
                } else {
                    $keyInfo.Key.ToString().ToUpper()
                }
            }
        }
        
        $parts.Add($keyName)
        return ($parts -join '+')
    }
    
    # Debug helper
    [string] GetCurrentContext() {
        if ($this._contextStack.Count -eq 0) { return "Global only" }
        
        $context = $this._contextStack.Peek()
        $keys = $context.Keys -join ", "
        return "Context keys: $keys"
    }
}