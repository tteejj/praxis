# Core/InputProcessor.ps1 - Translates physical key presses into logical commands
# Handles chords, special keys, and dispatches actions via EventBus

class InputProcessor {
    # Key mapping and command registry
    hidden [hashtable]$_keyMappings = @{}
    hidden [hashtable]$_commandRegistry = @{}
    
    # Chord state management
    hidden [string]$_activeChord = ""
    hidden [datetime]$_chordStartTime = [datetime]::MinValue
    hidden [int]$_chordTimeoutMs = 2000
    
    # Services
    hidden [EventBus]$_eventBus = $null
    hidden [SimpleStateManager]$_stateManager = $null
    hidden [Logger]$_logger = $null
    
    InputProcessor([EventBus]$eventBus, [SimpleStateManager]$stateManager, [Logger]$logger, [string]$configPath = "") {
        $this._eventBus = $eventBus
        $this._stateManager = $stateManager
        $this._logger = $logger
        
        # Initialize default key mappings and command registry
        $this.InitializeDefaultCommands()
        $this.InitializeDefaultKeyMappings()
        
        # Load user customizations if config path provided
        if ($configPath) {
            $this.LoadUserKeyMappings($configPath)
        }
        
        if ($this._logger) {
            $this._logger.Info("InputProcessor initialized")
        }
    }
    
    # Process a single key press
    [bool] ProcessKey([System.ConsoleKeyInfo]$keyInfo) {
        try {
            $keyString = $this.KeyInfoToString($keyInfo)
            if ($this._logger) { $this._logger.Debug("InputProcessor: Processing key '$keyString'") }
            
            # Handle chord timeout
            if ($this._activeChord -and ((Get-Date) - $this._chordStartTime).TotalMilliseconds -gt $this._chordTimeoutMs) {
                if ($this._logger) { $this._logger.Debug("InputProcessor: Chord '$($this._activeChord)' timed out") }
                $this._activeChord = ""
            }
            
            # Build potential command key (with chord if active)
            $commandKey = if ($this._activeChord) { "$($this._activeChord)+$keyString" } else { $keyString }
            
            # Check if this is a complete command
            if ($this._keyMappings.ContainsKey($commandKey)) {
                $command = $this._keyMappings[$commandKey]
                if ($this._logger) { $this._logger.Debug("InputProcessor: Executing command '$command' for key '$commandKey'") }
                
                # Clear chord state
                $this._activeChord = ""
                
                # Execute the command
                $this.ExecuteCommand($command, $keyInfo)
                return $true
            }
            
            # Check if this starts a chord
            $chordStartKey = if ($this._activeChord) { "$($this._activeChord)+$keyString" } else { $keyString }
            if ($this.IsChordStart($chordStartKey)) {
                if ($this._logger) { $this._logger.Debug("InputProcessor: Starting/continuing chord '$chordStartKey'") }
                $this._activeChord = $chordStartKey
                $this._chordStartTime = Get-Date
                return $true
            }
            
            # No command found
            if ($this._logger) { $this._logger.Debug("InputProcessor: No command found for key '$keyString'") }
            $this._activeChord = ""
            return $false
            
        } catch {
            if ($this._logger) { $this._logger.Error("InputProcessor: Error processing key", $_) }
            $this._activeChord = ""
            return $false
        }
    }
    
    # Convert ConsoleKeyInfo to string representation
    [string] KeyInfoToString([System.ConsoleKeyInfo]$keyInfo) {
        $parts = @()
        
        # Add modifiers
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Control) { $parts += "Ctrl" }
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Alt) { $parts += "Alt" }
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift) { $parts += "Shift" }
        
        # Add key name
        $keyName = switch ($keyInfo.Key) {
            ([System.ConsoleKey]::Enter) { "Enter" }
            ([System.ConsoleKey]::Escape) { "Esc" }
            ([System.ConsoleKey]::Tab) { "Tab" }
            ([System.ConsoleKey]::Backspace) { "Backspace" }
            ([System.ConsoleKey]::Delete) { "Delete" }
            ([System.ConsoleKey]::Insert) { "Insert" }
            ([System.ConsoleKey]::Home) { "Home" }
            ([System.ConsoleKey]::End) { "End" }
            ([System.ConsoleKey]::PageUp) { "PageUp" }
            ([System.ConsoleKey]::PageDown) { "PageDown" }
            ([System.ConsoleKey]::UpArrow) { "Up" }
            ([System.ConsoleKey]::DownArrow) { "Down" }
            ([System.ConsoleKey]::LeftArrow) { "Left" }
            ([System.ConsoleKey]::RightArrow) { "Right" }
            ([System.ConsoleKey]::F1) { "F1" }
            ([System.ConsoleKey]::F2) { "F2" }
            ([System.ConsoleKey]::F3) { "F3" }
            ([System.ConsoleKey]::F4) { "F4" }
            ([System.ConsoleKey]::F5) { "F5" }
            ([System.ConsoleKey]::F6) { "F6" }
            ([System.ConsoleKey]::F7) { "F7" }
            ([System.ConsoleKey]::F8) { "F8" }
            ([System.ConsoleKey]::F9) { "F9" }
            ([System.ConsoleKey]::F10) { "F10" }
            ([System.ConsoleKey]::F11) { "F11" }
            ([System.ConsoleKey]::F12) { "F12" }
            ([System.ConsoleKey]::Spacebar) { "Space" }
            default { 
                if ($keyInfo.KeyChar -and -not [char]::IsControl($keyInfo.KeyChar)) {
                    $keyInfo.KeyChar.ToString()
                } else {
                    $keyInfo.Key.ToString()
                }
            }
        }
        
        $parts += $keyName
        return $parts -join "+"
    }
    
    # Check if a key combination is the start of a chord
    [bool] IsChordStart([string]$keyString) {
        # Check if any command starts with this key combination
        foreach ($mappedKey in $this._keyMappings.Keys) {
            if ($mappedKey.StartsWith("$keyString+") -and $mappedKey -ne $keyString) {
                return $true
            }
        }
        return $false
    }
    
    # Execute a command
    [void] ExecuteCommand([string]$command, [System.ConsoleKeyInfo]$keyInfo) {
        if (-not $this._commandRegistry.ContainsKey($command)) {
            if ($this._logger) { $this._logger.Warn("InputProcessor: Unknown command '$command'") }
            return
        }
        
        $commandDef = $this._commandRegistry[$command]
        
        # Publish command event via EventBus
        $this._eventBus.Publish("command.$command", @{
            Command = $command
            Description = $commandDef.Description
            KeyInfo = $keyInfo
            Context = $this.GetCurrentContext()
        })
        
        # Also publish generic command event
        $this._eventBus.Publish("command.executed", @{
            Command = $command
            Description = $commandDef.Description
            KeyInfo = $keyInfo
        })
    }
    
    # Get current context for command execution
    [hashtable] GetCurrentContext() {
        $state = $this._stateManager.GetState()
        return @{
            CurrentScreen = $state.UI.CurrentScreen
            ScreenStack = $state.UI.ScreenStack
            WindowDimensions = $state.UI.WindowDimensions
        }
    }
    
    # Initialize default command registry
    [void] InitializeDefaultCommands() {
        $this._commandRegistry = @{
            # Navigation commands
            "nav.up" = @{ Description = "Move selection up" }
            "nav.down" = @{ Description = "Move selection down" }
            "nav.left" = @{ Description = "Move selection left" }
            "nav.right" = @{ Description = "Move selection right" }
            "nav.page_up" = @{ Description = "Page up" }
            "nav.page_down" = @{ Description = "Page down" }
            "nav.home" = @{ Description = "Go to beginning" }
            "nav.end" = @{ Description = "Go to end" }
            
            # Action commands
            "action.select" = @{ Description = "Select/activate item" }
            "action.cancel" = @{ Description = "Cancel/escape" }
            "action.delete" = @{ Description = "Delete item" }
            "action.edit" = @{ Description = "Edit item" }
            "action.new" = @{ Description = "Create new item" }
            "action.save" = @{ Description = "Save changes" }
            "action.refresh" = @{ Description = "Refresh data" }
            
            # Screen switching
            "screen.tasks" = @{ Description = "Switch to Tasks screen" }
            "screen.time" = @{ Description = "Switch to Time Entry screen" }
            "screen.commands" = @{ Description = "Switch to Commands screen" }
            "screen.excel" = @{ Description = "Switch to Excel Mapping screen" }
            
            # Application commands
            "app.exit" = @{ Description = "Exit application" }
            "app.help" = @{ Description = "Show help" }
            
            # Text editing
            "edit.backspace" = @{ Description = "Delete character backward" }
            "edit.delete" = @{ Description = "Delete character forward" }
            "edit.cut" = @{ Description = "Cut selection" }
            "edit.copy" = @{ Description = "Copy selection" }
            "edit.paste" = @{ Description = "Paste from clipboard" }
        }
        
        if ($this._logger) {
            $this._logger.Debug("InputProcessor: Default commands registered")
        }
    }
    
    # Initialize default key mappings
    [void] InitializeDefaultKeyMappings() {
        $this._keyMappings = @{
            # Navigation
            "Up" = "nav.up"
            "Down" = "nav.down" 
            "Left" = "nav.left"
            "Right" = "nav.right"
            "PageUp" = "nav.page_up"
            "PageDown" = "nav.page_down"
            "Home" = "nav.home"
            "End" = "nav.end"
            
            # Actions
            "Enter" = "action.select"
            "Esc" = "action.cancel"
            "Delete" = "action.delete"
            "F2" = "action.edit"
            "Ctrl+n" = "action.new"
            "Ctrl+s" = "action.save"
            "F5" = "action.refresh"
            
            # Single-key shortcuts for common actions
            "n" = "action.new"
            "d" = "action.delete"
            "e" = "action.edit"
            "s" = "action.save"
            "r" = "action.refresh"
            "x" = "task.toggle.complete"
            "Spacebar" = "task.toggle.collapse"
            "t" = "app.theme.cycle"
            
            # Screen switching (F-keys)
            "F7" = "screen.tasks"
            "F3" = "screen.time" 
            "F4" = "screen.commands"
            "F6" = "screen.excel"
            
            # Application
            "Ctrl+q" = "app.exit"
            "F1" = "app.help"
            
            # Text editing
            "Backspace" = "edit.backspace"
            "Ctrl+x" = "edit.cut"
            "Ctrl+c" = "edit.copy"
            "Ctrl+v" = "edit.paste"
        }
        
        if ($this._logger) { $this._logger.Debug("InputProcessor: Default key mappings registered") }
    }
    
    # Add or update a key mapping
    [void] SetKeyMapping([string]$key, [string]$command) {
        if (-not $this._commandRegistry.ContainsKey($command)) {
            if ($this._logger) { $this._logger.Warn("InputProcessor: Cannot map key '$key' to unknown command '$command'") }
            return
        }
        
        $this._keyMappings[$key] = $command
        if ($this._logger) { $this._logger.Debug("InputProcessor: Mapped key '$key' to command '$command'") }
    }
    
    # Remove a key mapping
    [void] RemoveKeyMapping([string]$key) {
        if ($this._keyMappings.ContainsKey($key)) {
            $this._keyMappings.Remove($key)
            if ($this._logger) { $this._logger.Debug("InputProcessor: Removed key mapping for '$key'") }
        }
    }
    
    # Get all current key mappings
    [hashtable] GetKeyMappings() {
        return $this._keyMappings.Clone()
    }
    
    # Get all registered commands
    [hashtable] GetCommands() {
        return $this._commandRegistry.Clone()
    }
    
    # Load user key mappings from JSON file
    [void] LoadUserKeyMappings([string]$configPath) {
        $keyMappingsFile = Join-Path $configPath "keymappings.json"
        
        if (-not (Test-Path $keyMappingsFile)) {
            if ($this._logger) { $this._logger.Info("No user key mappings file found at $keyMappingsFile") }
            return
        }
        
        try {
            if ($this._logger) { $this._logger.Info("Loading user key mappings from $keyMappingsFile") }
            $json = Get-Content $keyMappingsFile -Raw -Encoding UTF8
            $userMappings = ConvertFrom-Json $json -AsHashtable
            
            foreach ($key in $userMappings.Keys) {
                $command = $userMappings[$key]
                
                # Validate that the command exists
                if ($this._commandRegistry.ContainsKey($command)) {
                    $this._keyMappings[$key] = $command
                    if ($this._logger) { $this._logger.Debug("User mapping: '$key' -> '$command'") }
                } else {
                    if ($this._logger) { $this._logger.Warn("User key mapping '$key' -> '$command' ignored: command '$command' not registered") }
                }
            }
            
            if ($this._logger) { $this._logger.Info("Loaded $($userMappings.Keys.Count) user key mappings") }
            
        } catch {
            if ($this._logger) { $this._logger.Error("Failed to load user key mappings from $keyMappingsFile", $_) }
        }
    }
    
    # Save current key mappings to JSON file (for user customization)
    [void] SaveUserKeyMappings([string]$configPath) {
        $keyMappingsFile = Join-Path $configPath "keymappings.json"
        
        try {
            # Create config directory if it doesn't exist
            $configDir = Split-Path -Parent $keyMappingsFile
            if (-not (Test-Path $configDir)) {
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            }
            
            # Save current mappings (excluding defaults for cleaner file)
            $json = ConvertTo-Json $this._keyMappings -Depth 2
            [System.IO.File]::WriteAllText($keyMappingsFile, $json)
            
            if ($this._logger) { $this._logger.Info("Saved user key mappings to $keyMappingsFile") }
            
        } catch {
            if ($this._logger) { $this._logger.Error("Failed to save user key mappings to $keyMappingsFile", $_) }
        }
    }
    
    # Export default key mappings for user reference
    [void] ExportDefaultKeyMappings([string]$configPath) {
        $defaultsFile = Join-Path $configPath "keymappings-defaults.json"
        
        try {
            # Create config directory if it doesn't exist
            $configDir = Split-Path -Parent $defaultsFile
            if (-not (Test-Path $configDir)) {
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            }
            
            # Build a user-friendly structure with descriptions
            $exportData = @{
                "info" = "Default key mappings for SimpleTaskPro. Copy entries to keymappings.json to customize."
                "mappings" = @{}
            }
            
            foreach ($key in $this._keyMappings.Keys) {
                $command = $this._keyMappings[$key]
                $commandInfo = $this._commandRegistry[$command]
                $exportData.mappings[$key] = @{
                    "command" = $command
                    "description" = $commandInfo.Description
                }
            }
            
            $json = ConvertTo-Json $exportData -Depth 3
            [System.IO.File]::WriteAllText($defaultsFile, $json)
            
            if ($this._logger) { $this._logger.Info("Exported default key mappings to $defaultsFile") }
            
        } catch {
            if ($this._logger) { $this._logger.Error("Failed to export default key mappings to $defaultsFile", $_) }
        }
    }
}