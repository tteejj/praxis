# KeyMappingService.ps1 - User-configurable key mappings for SimpleTaskPro
# Allows users to customize keyboard shortcuts through settings

class KeyMappingService {
    [hashtable]$KeyMappings = @{}
    [string]$ConfigFile = ""
    
    KeyMappingService() {
        $this.ConfigFile = "$PSScriptRoot/../Data/keymappings.json"
        $this.LoadDefaultMappings()
        $this.LoadUserMappings()
    }
    
    # Load default key mappings
    [void] LoadDefaultMappings() {
        $this.KeyMappings = @{
            # Navigation - Support both Chromebook (Ctrl+F4) and regular F4
            "NavigateToTimeEntry" = @{ Key = "F4"; Modifiers = "Control"; Description = "Navigate to Time Entry screen (Ctrl+F4)" }
            "NavigateToTimeEntryAlt" = @{ Key = "F4"; Modifiers = "None"; Description = "Navigate to Time Entry screen (F4)" }
            "NavigateToCommands" = @{ Key = "F5"; Modifiers = "Control"; Description = "Navigate to Commands screen (Ctrl+F5)" }
            "NavigateToCommandsAlt" = @{ Key = "F5"; Modifiers = "None"; Description = "Navigate to Commands screen (F5)" } 
            "NavigateToExcel" = @{ Key = "F6"; Modifiers = "None"; Description = "Navigate to Excel Mapping screen" }
            "NavigateBack" = @{ Key = "Escape"; Modifiers = "None"; Description = "Navigate back/Exit application" }
            
            # Task Management
            "NewTask" = @{ Key = "N"; Modifiers = "None"; Description = "Create new task" }
            "EditTask" = @{ Key = "E"; Modifiers = "None"; Description = "Edit selected task" }
            "DeleteTask" = @{ Key = "D"; Modifiers = "None"; Description = "Delete selected task" }
            "ToggleComplete" = @{ Key = "X"; Modifiers = "None"; Description = "Toggle task completion" }
            "AddSubtask" = @{ Key = "S"; Modifiers = "None"; Description = "Add subtask to selected task" }
            
            # Filters  
            "FilterAll" = @{ Key = "F1"; Modifiers = "None"; Description = "Show all tasks" }
            "FilterToday" = @{ Key = "F2"; Modifiers = "None"; Description = "Show today's tasks" }
            "FilterHigh" = @{ Key = "F3"; Modifiers = "None"; Description = "Show high priority tasks" }
            "ToggleFilter" = @{ Key = "OemQuestion"; Modifiers = "None"; Description = "Toggle task filter" } # "/" key
            
            # Theme and Settings
            "CycleTheme" = @{ Key = "T"; Modifiers = "Control, Shift"; Description = "Cycle through themes" }
            "OpenSettings" = @{ Key = "F7"; Modifiers = "None"; Description = "Open settings dialog" }
            
            # Navigation within lists
            "MoveUp" = @{ Key = "UpArrow"; Modifiers = "None"; Description = "Move selection up" }
            "MoveDown" = @{ Key = "DownArrow"; Modifiers = "None"; Description = "Move selection down" }
            "PageUp" = @{ Key = "PageUp"; Modifiers = "None"; Description = "Move page up" }
            "PageDown" = @{ Key = "PageDown"; Modifiers = "None"; Description = "Move page down" }
            "MoveTaskUp" = @{ Key = "UpArrow"; Modifiers = "Control"; Description = "Move task up in order" }
            "MoveTaskDown" = @{ Key = "DownArrow"; Modifiers = "Control"; Description = "Move task down in order" }
            "ToggleCollapse" = @{ Key = "Spacebar"; Modifiers = "None"; Description = "Toggle subtask collapse" }
            "CycleFilters" = @{ Key = "OemPipe"; Modifiers = "None"; Description = "Cycle through filters" } # "|" key
            "FilterMedium" = @{ Key = "F"; Modifiers = "None"; Description = "Filter medium priority" }
            "FilterLow" = @{ Key = "L"; Modifiers = "None"; Description = "Filter low priority" }
            
            # Time Entry specific
            "StartTimeEdit" = @{ Key = "E"; Modifiers = "None"; Description = "Start editing time entry" }
            "NewTimeEntry" = @{ Key = "N"; Modifiers = "None"; Description = "Create new time entry" }
            "ToggleTimeFilter" = @{ Key = "T"; Modifiers = "None"; Description = "Toggle time entry filter" }
            "RefreshTimeEntries" = @{ Key = "R"; Modifiers = "None"; Description = "Refresh time entries" }
            
            # Editing
            "CommitEdit" = @{ Key = "Enter"; Modifiers = "None"; Description = "Commit current edit" }
            "CancelEdit" = @{ Key = "Escape"; Modifiers = "None"; Description = "Cancel current edit" }
            "NextField" = @{ Key = "Tab"; Modifiers = "None"; Description = "Move to next field" }
        }
    }
    
    # Load user customizations from file
    [void] LoadUserMappings() {
        if (Test-Path $this.ConfigFile) {
            try {
                $userMappings = Get-Content $this.ConfigFile | ConvertFrom-Json -AsHashtable
                foreach ($actionName in $userMappings.Keys) {
                    $this.KeyMappings[$actionName] = $userMappings[$actionName]
                }
                Write-Host "Loaded user key mappings from $($this.ConfigFile)" -ForegroundColor Green
            } catch {
                Write-Warning "Could not load user key mappings: $_"
            }
        }
    }
    
    # Save current mappings to file
    [void] SaveMappings() {
        try {
            $dataDir = Split-Path $this.ConfigFile -Parent
            if (-not (Test-Path $dataDir)) {
                New-Item -ItemType Directory -Path $dataDir -Force
            }
            
            $this.KeyMappings | ConvertTo-Json -Depth 3 | Out-File $this.ConfigFile -Encoding UTF8
            Write-Host "Saved key mappings to $($this.ConfigFile)" -ForegroundColor Green
        } catch {
            Write-Warning "Could not save key mappings: $_"
        }
    }
    
    # Get key mapping for an action
    [hashtable] GetMapping([string]$actionName) {
        if ($this.KeyMappings.ContainsKey($actionName)) {
            return $this.KeyMappings[$actionName]
        }
        return $null
    }
    
    # Set key mapping for an action
    [void] SetMapping([string]$actionName, [string]$key, [string]$modifiers, [string]$description) {
        $this.KeyMappings[$actionName] = @{
            Key = $key
            Modifiers = $modifiers
            Description = $description
        }
    }
    
    # Check if a key press matches an action
    [bool] MatchesAction([System.ConsoleKeyInfo]$keyInfo, [string]$actionName) {
        $mapping = $this.GetMapping($actionName)
        if (-not $mapping) {
            if ($global:Debug) {
                "DEBUG: No mapping found for action '$actionName'" | Out-File -FilePath "./startup-debug.log" -Append
            }
            return $false
        }
        
        # Check key match
        $keyMatches = $keyInfo.Key.ToString() -eq $mapping.Key
        
        # Check modifiers match
        $expectedModifiers = if ($mapping.Modifiers -eq "None") { 
            [System.ConsoleModifiers]::None 
        } else {
            $modifierList = $mapping.Modifiers -split ', '
            $result = [System.ConsoleModifiers]::None
            foreach ($mod in $modifierList) {
                $result = $result -bor [System.ConsoleModifiers]::$mod
            }
            $result
        }
        
        $modifiersMatch = $keyInfo.Modifiers -eq $expectedModifiers
        
        if ($global:Debug) {
            "DEBUG: MatchesAction '$actionName' - Key: $($keyInfo.Key) vs $($mapping.Key) ($keyMatches), Modifiers: $($keyInfo.Modifiers) vs $expectedModifiers ($modifiersMatch)" | Out-File -FilePath "./startup-debug.log" -Append
        }
        
        return $keyMatches -and $modifiersMatch
    }
    
    # Get all available actions
    [string[]] GetAllActions() {
        return $this.KeyMappings.Keys
    }
    
    # Get key mappings grouped by category
    [hashtable] GetMappingsByCategory() {
        return @{
            "Navigation" = @("NavigateToTimeEntry", "NavigateToCommands", "NavigateToExcel", "NavigateBack")
            "Task Management" = @("NewTask", "EditTask", "DeleteTask", "ToggleComplete", "AddSubtask")  
            "Filters" = @("FilterAll", "FilterToday", "FilterHigh", "ToggleFilter")
            "Theme & Settings" = @("CycleTheme", "OpenSettings")
            "List Navigation" = @("MoveUp", "MoveDown", "PageUp", "PageDown")
            "Time Entry" = @("StartTimeEdit", "NewTimeEntry", "ToggleTimeFilter", "RefreshTimeEntries")
            "Editing" = @("CommitEdit", "CancelEdit", "NextField")
        }
    }
    
    # Reset to default mappings
    [void] ResetToDefaults() {
        $this.LoadDefaultMappings()
        $this.SaveMappings()
    }
    
    # Validate a key mapping (check for conflicts)
    [bool] ValidateMapping([string]$actionName, [string]$key, [string]$modifiers) {
        $testMapping = @{ Key = $key; Modifiers = $modifiers }
        
        foreach ($existingAction in $this.KeyMappings.Keys) {
            if ($existingAction -eq $actionName) { continue } # Skip self
            
            $existing = $this.KeyMappings[$existingAction]
            if ($existing.Key -eq $testMapping.Key -and $existing.Modifiers -eq $testMapping.Modifiers) {
                Write-Warning "Key mapping conflict: $key+$modifiers is already used by $existingAction"
                return $false
            }
        }
        
        return $true
    }
}