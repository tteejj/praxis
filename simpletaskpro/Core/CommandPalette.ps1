# CommandPalette.ps1 - Command palette for text-based command execution
# Supports fuzzy search, command history, and extensible command system

class CommandPalette {
    [string]$InputBuffer = ""
    [int]$CursorPosition = 0
    [string[]]$Commands = @()
    [string[]]$FilteredCommands = @()
    [int]$SelectedIndex = 0
    [string[]]$History = @()
    [int]$HistoryIndex = -1
    [hashtable]$CommandMap = @{}
    [object]$Context = $null
    [bool]$IsActive = $false
    
    CommandPalette($context) {
        $this.Context = $context
        $this.InitializeCommands()
        $this.LoadHistory()
    }
    
    [void] InitializeCommands() {
        # Core task commands
        $this.RegisterCommand("new task", "Create a new task", "NewTask")
        $this.RegisterCommand("new subtask", "Create a new subtask", "NewSubtask") 
        $this.RegisterCommand("edit task", "Edit current task", "EditTask")
        $this.RegisterCommand("edit tags", "Edit task tags", "EditTags")
        $this.RegisterCommand("edit notes", "Edit task notes", "EditNotes")
        $this.RegisterCommand("delete task", "Delete current task", "DeleteTask")
        $this.RegisterCommand("complete task", "Toggle task completion", "ToggleComplete")
        $this.RegisterCommand("move up", "Move task up", "MoveTaskUp")
        $this.RegisterCommand("move down", "Move task down", "MoveTaskDown")
        
        # Filter commands
        $this.RegisterCommand("filter all", "Show all tasks", "FilterAll")
        $this.RegisterCommand("filter today", "Show today's tasks", "FilterToday")
        $this.RegisterCommand("filter high", "Show high priority tasks", "FilterHigh")
        $this.RegisterCommand("filter medium", "Show medium priority tasks", "FilterMedium")
        $this.RegisterCommand("filter low", "Show low priority tasks", "FilterLow")
        $this.RegisterCommand("filter completed", "Show completed tasks", "FilterCompleted")
        $this.RegisterCommand("filter project", "Show project tasks only", "FilterProject")
        $this.RegisterCommand("clear filter", "Clear all filters", "ClearFilter")
        
        # View commands
        $this.RegisterCommand("collapse all", "Collapse all subtasks", "CollapseAll")
        $this.RegisterCommand("expand all", "Expand all subtasks", "ExpandAll")
        $this.RegisterCommand("toggle collapse", "Toggle current task collapse", "ToggleCollapse")
        $this.RegisterCommand("zoom focus", "Focus on current task", "ZoomFocus")
        $this.RegisterCommand("zoom out", "Show full task tree", "ZoomOut")
        $this.RegisterCommand("center current", "Center current task", "CenterCurrent")
        
        # Theme and appearance
        $this.RegisterCommand("toggle theme", "Change current task theme", "ToggleTheme")
        $this.RegisterCommand("theme editor", "Open theme editor", "ThemeEditor")
        $this.RegisterCommand("cycle global theme", "Cycle global application theme", "CycleGlobalTheme")
        
        # Clipboard operations
        $this.RegisterCommand("copy task", "Copy current task", "CopyTask")
        $this.RegisterCommand("copy title", "Copy task title", "CopyTitle")
        $this.RegisterCommand("copy notes", "Copy task notes", "CopyNotes")
        $this.RegisterCommand("copy formatted", "Copy task formatted for export", "CopyFormatted")
        $this.RegisterCommand("copy timesheet", "Copy timesheet format", "CopyTimesheet")
        $this.RegisterCommand("paste task", "Paste as new task", "PasteTask")
        $this.RegisterCommand("paste subtask", "Paste as subtask", "PasteSubtask")
        
        # Project management
        $this.RegisterCommand("project screen", "Open project management screen", "ProjectScreen")
        $this.RegisterCommand("project settings", "Open project settings", "ProjectSettings")
        $this.RegisterCommand("project folder", "Open project folder", "ProjectFolder")
        $this.RegisterCommand("project export", "Export project data", "ProjectExport")
        
        # Time entry
        $this.RegisterCommand("time entry", "Switch to time entry mode", "SwitchToTimeEntry")
        $this.RegisterCommand("new time entry", "Create new time entry", "NewTimeEntry")
        $this.RegisterCommand("new project time", "Create new project time entry", "NewProjectTime")
        $this.RegisterCommand("export timesheet", "Export timesheet data", "ExportTimesheet")
        
        # System commands
        $this.RegisterCommand("save all", "Save all changes", "SaveAll")
        $this.RegisterCommand("reload data", "Reload task data", "ReloadData")
        $this.RegisterCommand("backup data", "Backup task data", "BackupData")
        $this.RegisterCommand("export data", "Export all data", "ExportData")
        $this.RegisterCommand("import data", "Import task data", "ImportData")
        
        # Advanced commands with parameters
        $this.RegisterCommand("goto line", "Go to specific task line", "GotoLine")
        $this.RegisterCommand("find task", "Find task by title", "FindTask")
        $this.RegisterCommand("set priority", "Set task priority (high/medium/low)", "SetPriority")
        $this.RegisterCommand("set due date", "Set task due date", "SetDueDate")
        $this.RegisterCommand("add tag", "Add tag to current task", "AddTag")
        $this.RegisterCommand("remove tag", "Remove tag from current task", "RemoveTag")
        
        # Development and debugging
        $this.RegisterCommand("toggle debug", "Toggle debug mode", "ToggleDebug")
        $this.RegisterCommand("show stats", "Show application statistics", "ShowStats")
        $this.RegisterCommand("clear cache", "Clear application cache", "ClearCache")
        $this.RegisterCommand("refresh screen", "Refresh screen rendering", "RefreshScreen")
        
        # Help and documentation
        $this.RegisterCommand("help", "Show help information", "ShowHelp")
        $this.RegisterCommand("shortcuts", "Show keyboard shortcuts", "ShowShortcuts")
        $this.RegisterCommand("about", "Show about information", "ShowAbout")
        
        $this.Commands = $this.CommandMap.Keys | Sort-Object
        $this.FilteredCommands = $this.Commands
    }
    
    [void] RegisterCommand([string]$name, [string]$description, [string]$action) {
        $this.CommandMap[$name] = @{
            Description = $description
            Action = $action
        }
    }
    
    [void] Show() {
        $this.IsActive = $true
        $this.InputBuffer = ""
        $this.CursorPosition = 0
        $this.FilteredCommands = $this.Commands
        $this.SelectedIndex = 0
        $this.HistoryIndex = -1
    }
    
    [void] Hide() {
        $this.IsActive = $false
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.IsActive) { return $false }
        
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) {
                $this.Hide()
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                if ($this.FilteredCommands.Count -gt 0 -and $this.SelectedIndex -lt $this.FilteredCommands.Count) {
                    $selectedCommand = $this.FilteredCommands[$this.SelectedIndex]
                    $this.ExecuteCommand($selectedCommand)
                    $this.AddToHistory($selectedCommand)
                    $this.Hide()
                }
                return $true
            }
            ([System.ConsoleKey]::UpArrow) {
                if ($this.FilteredCommands.Count -gt 0) {
                    $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - 1)
                }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.FilteredCommands.Count -gt 0) {
                    $this.SelectedIndex = [Math]::Min($this.FilteredCommands.Count - 1, $this.SelectedIndex + 1)
                }
                return $true
            }
            ([System.ConsoleKey]::Tab) {
                # Autocomplete with current selection
                if ($this.FilteredCommands.Count -gt 0 -and $this.SelectedIndex -lt $this.FilteredCommands.Count) {
                    $selected = $this.FilteredCommands[$this.SelectedIndex]
                    $this.InputBuffer = $selected
                    $this.CursorPosition = $selected.Length
                    $this.UpdateFilter()
                }
                return $true
            }
            ([System.ConsoleKey]::Backspace) {
                if ($this.CursorPosition -gt 0) {
                    $this.InputBuffer = $this.InputBuffer.Remove($this.CursorPosition - 1, 1)
                    $this.CursorPosition--
                    $this.UpdateFilter()
                }
                return $true
            }
            ([System.ConsoleKey]::Delete) {
                if ($this.CursorPosition -lt $this.InputBuffer.Length) {
                    $this.InputBuffer = $this.InputBuffer.Remove($this.CursorPosition, 1)
                    $this.UpdateFilter()
                }
                return $true
            }
            ([System.ConsoleKey]::LeftArrow) {
                $this.CursorPosition = [Math]::Max(0, $this.CursorPosition - 1)
                return $true
            }
            ([System.ConsoleKey]::RightArrow) {
                $this.CursorPosition = [Math]::Min($this.InputBuffer.Length, $this.CursorPosition + 1)
                return $true
            }
            ([System.ConsoleKey]::Home) {
                $this.CursorPosition = 0
                return $true
            }
            ([System.ConsoleKey]::End) {
                $this.CursorPosition = $this.InputBuffer.Length
                return $true
            }
            default {
                # Handle printable characters
                if (-not [char]::IsControl($key.KeyChar)) {
                    $this.InputBuffer = $this.InputBuffer.Insert($this.CursorPosition, $key.KeyChar)
                    $this.CursorPosition++
                    $this.UpdateFilter()
                }
                return $true
            }
        }
        
        return $false
    }
    
    [void] UpdateFilter() {
        if ([string]::IsNullOrEmpty($this.InputBuffer)) {
            $this.FilteredCommands = $this.Commands
        } else {
            # Fuzzy search - matches if all characters appear in order
            $pattern = $this.InputBuffer.ToLower()
            $this.FilteredCommands = @()
            
            foreach ($cmd in $this.Commands) {
                if ($this.FuzzyMatch($cmd.ToLower(), $pattern)) {
                    $this.FilteredCommands += $cmd
                }
            }
        }
        
        # Reset selection to top
        $this.SelectedIndex = 0
    }
    
    [bool] FuzzyMatch([string]$text, [string]$pattern) {
        $textIndex = 0
        $patternIndex = 0
        
        while ($textIndex -lt $text.Length -and $patternIndex -lt $pattern.Length) {
            if ($text[$textIndex] -eq $pattern[$patternIndex]) {
                $patternIndex++
            }
            $textIndex++
        }
        
        return $patternIndex -eq $pattern.Length
    }
    
    [void] ExecuteCommand([string]$commandName) {
        if ($this.CommandMap.ContainsKey($commandName)) {
            $command = $this.CommandMap[$commandName]
            $action = $command.Action
            
            # Check if command needs parameters
            if ($this.NeedsParameters($action)) {
                $params = $this.ParseParameters($commandName, $this.InputBuffer)
                $this.Context.HandleAction($action, $params)
            } else {
                $this.Context.HandleAction($action)
            }
        }
    }
    
    [bool] NeedsParameters([string]$action) {
        # Commands that require additional parameters
        $paramCommands = @("GotoLine", "FindTask", "SetPriority", "SetDueDate", "AddTag", "RemoveTag")
        return $action -in $paramCommands
    }
    
    [hashtable] ParseParameters([string]$commandName, [string]$input) {
        # Extract parameters from input buffer
        $params = @{}
        
        # Simple parameter parsing - can be enhanced
        $parts = $input -split '\s+', 2
        if ($parts.Count -gt 1) {
            $params["value"] = $parts[1]
        }
        
        return $params
    }
    
    [void] AddToHistory([string]$command) {
        # Add to history, avoiding duplicates
        if ($command -notin $this.History) {
            $this.History += $command
            # Keep only last 50 commands
            if ($this.History.Count -gt 50) {
                $this.History = $this.History[-50..-1]
            }
            $this.SaveHistory()
        }
    }
    
    [void] LoadHistory() {
        $historyFile = Join-Path $PSScriptRoot "../Data/command_history.json"
        if (Test-Path $historyFile) {
            try {
                $content = Get-Content $historyFile -Raw | ConvertFrom-Json
                $this.History = $content
            } catch {
                $this.History = @()
            }
        }
    }
    
    [void] SaveHistory() {
        $historyFile = Join-Path $PSScriptRoot "../Data/command_history.json"
        $dir = Split-Path $historyFile -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        
        try {
            $this.History | ConvertTo-Json | Set-Content $historyFile
        } catch {
            # Ignore save errors
        }
    }
    
    [string] Render([int]$width, [int]$height) {
        if (-not $this.IsActive) { return "" }
        
        $sb = [System.Text.StringBuilder]::new()
        
        # Calculate dimensions
        $maxItems = [Math]::Min(10, $height - 3)  # Reserve space for input and borders
        
        # Top border
        [void]$sb.AppendLine("╭─ Command Palette " + "─" * ($width - 18) + "╮")
        
        # Input line
        $prompt = ">>> "
        $displayInput = $this.InputBuffer
        $cursorDisplay = if ($this.CursorPosition -lt $displayInput.Length) { 
            $displayInput.Insert($this.CursorPosition, "_") 
        } else { 
            $displayInput + "_" 
        }
        
        [void]$sb.AppendLine("│ $prompt$cursorDisplay".PadRight($width - 1) + "│")
        [void]$sb.AppendLine("├" + "─" * ($width - 2) + "┤")
        
        # Command list
        $startIndex = [Math]::Max(0, $this.SelectedIndex - $maxItems / 2)
        $endIndex = [Math]::Min($this.FilteredCommands.Count, $startIndex + $maxItems)
        
        for ($i = $startIndex; $i -lt $endIndex; $i++) {
            $cmd = $this.FilteredCommands[$i]
            $isSelected = ($i -eq $this.SelectedIndex)
            
            $prefix = if ($isSelected) { "▶ " } else { "  " }
            $description = if ($this.CommandMap.ContainsKey($cmd)) { 
                " - " + $this.CommandMap[$cmd].Description 
            } else { 
                "" 
            }
            
            $line = "$prefix$cmd$description"
            if ($line.Length -gt $width - 3) {
                $line = $line.Substring(0, $width - 6) + "..."
            }
            
            $color = if ($isSelected) { "`e[38;2;255;215;0m" } else { "`e[38;2;200;200;200m" }
            [void]$sb.AppendLine("│$color$($line.PadRight($width - 3))`e[0m│")
        }
        
        # Fill remaining space
        for ($i = ($endIndex - $startIndex); $i -lt $maxItems; $i++) {
            [void]$sb.AppendLine("│" + " " * ($width - 2) + "│")
        }
        
        # Bottom border with stats
        $stats = "[$($this.FilteredCommands.Count)/$($this.Commands.Count)]"
        $bottom = "╰" + "─" * ($width - $stats.Length - 3) + $stats + "╯"
        [void]$sb.AppendLine($bottom)
        
        return $sb.ToString()
    }
}