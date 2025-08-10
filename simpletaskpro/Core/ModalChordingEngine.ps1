# ModalChordingEngine.ps1 - Advanced hotkey system with modal chording support
# Enables Vim-like modal commands and chord combinations for complex operations

class ModalChordingEngine {
    [string]$CurrentMode = "Normal"  # Normal, Command, Search, Insert
    [string]$ChordBuffer = ""        # Accumulates chord sequence
    [hashtable]$KeyMaps = @{}        # Mode -> Chord -> Action mappings
    [object]$Context = $null         # Current screen context
    [bool]$ShowChordBuffer = $false  # Visual feedback
    
    ModalChordingEngine($context) {
        $this.Context = $context
        $this.InitializeKeyMaps()
    }
    
    [void] InitializeKeyMaps() {
        # NORMAL MODE - Primary navigation and quick actions
        $this.KeyMaps["Normal"] = @{
            # Single key actions (existing functionality)
            "<Up>" = "MoveUp"
            "<Down>" = "MoveDown" 
            "<Left>" = "MoveLeft"
            "<Right>" = "MoveRight"
            "<Ctrl-Up>" = "MoveTaskUp"
            "<Ctrl-Down>" = "MoveTaskDown"
            "x" = "ToggleComplete"
            "d" = "Delete"
            "n" = "NewTask"
            "s" = "NewSubtask"
            "e" = "EditTask"
            "r" = "EditTags"
            "t" = "ToggleTheme"
            " " = "ToggleCollapse"
            "c" = "GlobalCollapse"
            "/" = "EnterCommandMode"
            ":" = "EnterCommandMode"
            "q" = "Quit"
            "?" = "ShowHelp"
            
            # CHORD SEQUENCES - Multi-key combinations
            "g" = @{
                "g" = "GoToTop"           # gg - go to first task
                "b" = "GoToBottom"        # gb - go to last task
                "h" = "GoToParent"        # gh - go to parent task
                "c" = "GoToChild"         # gc - go to first child
            }
            
            "f" = @{  # File/Filter operations
                "a" = "FilterAll"         # fa - show all tasks
                "t" = "FilterToday"       # ft - today's tasks
                "h" = "FilterHigh"        # fh - high priority
                "c" = "FilterCompleted"   # fc - completed tasks
                "p" = "FilterProject"     # fp - project tasks only
            }
            
            "w" = @{  # Window/Workspace operations
                "s" = "SplitScreen"       # ws - split screen
                "t" = "NewTab"            # wt - new workspace tab
                "n" = "NextWindow"        # wn - next window
                "p" = "PrevWindow"        # wp - previous window
                "q" = "CloseWindow"       # wq - close current window
            }
            
            "y" = @{  # Yank/Copy operations
                "y" = "CopyTask"          # yy - copy current task
                "t" = "CopyTitle"         # yt - copy task title
                "n" = "CopyNotes"         # yn - copy task notes
                "a" = "CopyAll"           # ya - copy task with subtasks
                "f" = "CopyFormatted"     # yf - copy formatted for export
                "s" = "CopyTimesheet"     # ys - copy timesheet format
            }
            
            "p" = @{  # Paste operations
                "p" = "PasteTask"         # pp - paste as new task
                "s" = "PasteSubtask"      # ps - paste as subtask
                "a" = "PasteAfter"        # pa - paste after current
                "b" = "PasteBefore"       # pb - paste before current
            }
            
            "m" = @{  # Mark/Movement operations
                "a" = "MarkTask"          # ma - mark task for operations
                "m" = "MoveMarked"        # mm - move marked tasks
                "c" = "CopyMarked"        # mc - copy marked tasks
                "d" = "DeleteMarked"      # md - delete marked tasks
                "u" = "UnmarkAll"         # mu - unmark all tasks
            }
            
            "z" = @{  # Zoom/View operations
                "z" = "CenterCurrent"     # zz - center current task
                "t" = "ZoomToTask"        # zt - focus on current task tree
                "o" = "ZoomOut"           # zo - show full tree
                "f" = "ZoomFocus"         # zf - focus mode (hide others)
            }
            
            "H" = @{  # Help operations (uppercase H to avoid conflict)
                "h" = "ShowHelp"          # Hh - show help screen
                "k" = "ShowKeys"          # Hk - show key mappings
                "c" = "ShowCommands"      # Hc - show available commands
                "?" = "ShowQuickHelp"     # H? - show quick help overlay
            }
            
            # Function keys mapped to chords for consistency
            "<F1>" = "fa"   # F1 -> fa (filter all)
            "<F2>" = "ft"   # F2 -> ft (filter today)  
            "<F3>" = "fh"   # F3 -> fh (filter high)
            "<F4>" = "SwitchToTimeEntry"
            "<F5>" = "ThemeEditor"
            "<F6>" = "ProjectScreen"
        }
        
        # COMMAND MODE - Text-based commands like vim
        $this.KeyMaps["Command"] = @{
            # Text command processing - handled by command parser
        }
        
        
        # TIME ENTRY MODE - All time entry hotkeys
        $this.KeyMaps["TimeEntry"] = @{
            "j" = "TimeDown"
            "k" = "TimeUp"
            "n" = "NewTimeEntry"
            "a" = "NewProjectTime"
            "e" = "EditTimeEntry"
            "d" = "DeleteTimeEntry"
            "p" = "ToggleTimeFilter"
            "c" = "CurrentWeek"
            "<Left>" = "PrevWeek"
            "<Right>" = "NextWeek"
            "<F4>" = "SwitchToTasks"
            "q" = "SwitchToTasks"
            
            # Time entry chords
            "y" = @{
                "w" = "CopyWeekData"      # yw - copy week timesheet
                "d" = "CopyDayData"       # yd - copy day data
                "p" = "CopyProjectData"   # yp - copy project summary
            }
            
            "f" = @{
                "p" = "FilterProjects"    # fp - show only projects
                "t" = "FilterTimeCodes"   # ft - show only time codes
                "a" = "FilterAll"         # fa - show all entries
            }
        }
    }
    
    [bool] ProcessKey([System.ConsoleKeyInfo]$key) {
        $keyString = $this.KeyToString($key)
        
        # Handle mode switching keys first
        if ($this.CurrentMode -eq "Normal" -and ($keyString -eq ":" -or $keyString -eq "/")) {
            $this.EnterCommandMode()
            return $true
        }
        
        # Handle escape - always returns to Normal mode
        if ($keyString -eq "<Escape>") {
            $this.ExitCurrentMode()
            return $true
        }
        
        # Process the key in current mode
        return $this.ProcessKeyInMode($keyString)
    }
    
    [string] KeyToString([System.ConsoleKeyInfo]$key) {
        # Convert ConsoleKeyInfo to string representation
        if ($key.Key -eq [System.ConsoleKey]::Escape) { return "<Escape>" }
        if ($key.Key -eq [System.ConsoleKey]::Enter) { return "<Enter>" }
        if ($key.Key -eq [System.ConsoleKey]::Tab) { return "<Tab>" }
        if ($key.Key -eq [System.ConsoleKey]::Backspace) { return "<Backspace>" }
        if ($key.Key -eq [System.ConsoleKey]::Delete) { return "<Delete>" }
        if ($key.Key -eq [System.ConsoleKey]::UpArrow) { return "<Up>" }
        if ($key.Key -eq [System.ConsoleKey]::DownArrow) { return "<Down>" }
        if ($key.Key -eq [System.ConsoleKey]::LeftArrow) { return "<Left>" }
        if ($key.Key -eq [System.ConsoleKey]::RightArrow) { return "<Right>" }
        if ($key.Key -ge [System.ConsoleKey]::F1 -and $key.Key -le [System.ConsoleKey]::F12) {
            return "<$($key.Key)>"
        }
        
        # Handle modifiers with special keys first
        if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
            if ($key.Key -eq [System.ConsoleKey]::UpArrow) { return "<Ctrl-Up>" }
            if ($key.Key -eq [System.ConsoleKey]::DownArrow) { return "<Ctrl-Down>" }
            if ($key.Key -eq [System.ConsoleKey]::LeftArrow) { return "<Ctrl-Left>" }
            if ($key.Key -eq [System.ConsoleKey]::RightArrow) { return "<Ctrl-Right>" }
            return "<Ctrl-$($key.KeyChar)>"
        }
        if ($key.Modifiers -band [System.ConsoleModifiers]::Alt) {
            return "<Alt-$($key.KeyChar)>"
        }
        if ($key.Modifiers -band [System.ConsoleModifiers]::Shift -and [char]::IsLetter($key.KeyChar)) {
            return $key.KeyChar.ToString().ToUpper()
        }
        
        return $key.KeyChar.ToString().ToLower()
    }
    
    [bool] ProcessKeyInMode([string]$keyString) {
        $modeMap = $this.KeyMaps[$this.CurrentMode]
        if (-not $modeMap) { return $false }
        
        # Try chord sequence first
        $fullChord = $this.ChordBuffer + $keyString
        
        # Check if this is a complete chord
        if ($modeMap.ContainsKey($fullChord)) {
            $action = $modeMap[$fullChord]
            $this.ChordBuffer = ""
            $this.ShowChordBuffer = $false
            return $this.ExecuteAction($action)
        }
        
        # Check if this could be start of a chord sequence
        $possibleChords = $modeMap.Keys | Where-Object { $_.StartsWith($fullChord) }
        if ($possibleChords.Count -gt 0) {
            $this.ChordBuffer = $fullChord
            $this.ShowChordBuffer = $true
            return $true  # Continue building chord
        }
        
        # Check current buffer for nested chord maps
        if ($this.ChordBuffer.Length -gt 0) {
            $baseKey = $this.ChordBuffer
            if ($modeMap.ContainsKey($baseKey) -and $modeMap[$baseKey] -is [hashtable]) {
                $nestedMap = $modeMap[$baseKey]
                if ($nestedMap.ContainsKey($keyString)) {
                    $action = $nestedMap[$keyString]
                    $this.ChordBuffer = ""
                    $this.ShowChordBuffer = $false
                    return $this.ExecuteAction($action)
                }
            }
        }
        
        # Try single key in current chord state
        if ($this.ChordBuffer.Length -eq 0 -and $modeMap.ContainsKey($keyString)) {
            $mapping = $modeMap[$keyString]
            if ($mapping -is [hashtable]) {
                # This key starts a chord sequence
                $this.ChordBuffer = $keyString
                $this.ShowChordBuffer = $true
                return $true
            } else {
                # Single key action
                return $this.ExecuteAction($mapping)
            }
        }
        
        # No match found - clear chord buffer and try direct execution
        $this.ChordBuffer = ""
        $this.ShowChordBuffer = $false
        return $false
    }
    
    [bool] ExecuteAction([string]$action) {
        # Delegate action execution to the context (TaskListScreen)
        switch ($action) {
            "MoveDown" { return $this.Context.HandleAction("MoveDown") }
            "MoveUp" { return $this.Context.HandleAction("MoveUp") }
            "ToggleComplete" { return $this.Context.HandleAction("ToggleComplete") }
            "NewTask" { return $this.Context.HandleAction("NewTask") }
            "NewSubtask" { return $this.Context.HandleAction("NewSubtask") }
            "EditTask" { return $this.Context.HandleAction("EditTask") }
            "Delete" { return $this.Context.HandleAction("Delete") }
            "CopyTask" { return $this.Context.HandleAction("CopyTask") }
            "PasteTask" { return $this.Context.HandleAction("PasteTask") }
            "FilterAll" { return $this.Context.HandleAction("FilterAll") }
            "FilterToday" { return $this.Context.HandleAction("FilterToday") }
            "SwitchToTimeEntry" { return $this.Context.HandleAction("SwitchToTimeEntry") }
            "Quit" { return $false }
            default { 
                # Try to execute custom action on context
                if ($this.Context -and $this.Context.HandleAction) {
                    return $this.Context.HandleAction($action)
                }
                return $false
            }
        }
        return $false  # This should never be reached, but PowerShell needs it
    }
    
    [void] EnterCommandMode() {
        $this.CurrentMode = "Command"
        $this.ChordBuffer = ""
        $this.ShowChordBuffer = $false
        # Context should show command input line
        $this.Context.ShowCommandLine()
    }
    
    
    [void] ExitCurrentMode() {
        $this.CurrentMode = "Normal"
        $this.ChordBuffer = ""
        $this.ShowChordBuffer = $false
        # Context should hide input lines
        $this.Context.HideInputLines()
    }
    
    [string] GetStatusLine() {
        $status = "[$($this.CurrentMode)]"
        if ($this.ShowChordBuffer -and $this.ChordBuffer.Length -gt 0) {
            $status += " $($this.ChordBuffer)"
        }
        return $status
    }
    
    [string[]] GetAvailableCommands() {
        # Return list of available commands for current mode (for help/autocomplete)
        $commands = @()
        $modeMap = $this.KeyMaps[$this.CurrentMode]
        if ($modeMap) {
            foreach ($key in $modeMap.Keys) {
                if ($modeMap[$key] -is [hashtable]) {
                    foreach ($subKey in $modeMap[$key].Keys) {
                        $commands += "$key$subKey"
                    }
                } else {
                    $commands += $key
                }
            }
        }
        return $commands
    }
    
    [string] GenerateHelpScreen() {
        $sb = [System.Text.StringBuilder]::new()
        
        [void]$sb.AppendLine("╭─ SimpleTaskPro Hotkey Reference " + "─" * 40 + "╮")
        [void]$sb.AppendLine("│                                                               │")
        [void]$sb.AppendLine("│ NAVIGATION:                                                   │")
        [void]$sb.AppendLine("│   ↑/↓       - Move up/down          ←/→   - Move left/right │")
        [void]$sb.AppendLine("│   gg        - Go to top             gb    - Go to bottom    │")
        [void]$sb.AppendLine("│                                                               │")
        [void]$sb.AppendLine("│ TASK OPERATIONS:                                              │")
        [void]$sb.AppendLine("│   n         - New task              s     - New subtask     │")
        [void]$sb.AppendLine("│   e         - Edit task             x     - Toggle complete │")
        [void]$sb.AppendLine("│   d         - Delete task           r     - Edit tags       │")
        [void]$sb.AppendLine("│   t         - Toggle theme          Space - Toggle collapse │")
        [void]$sb.AppendLine("│                                                               │")
        [void]$sb.AppendLine("│ CLIPBOARD:                                                    │")
        [void]$sb.AppendLine("│   yy        - Copy task             yt    - Copy title      │")
        [void]$sb.AppendLine("│   yf        - Copy formatted        pp    - Paste task      │")
        [void]$sb.AppendLine("│   ps        - Paste as subtask                               │")
        [void]$sb.AppendLine("│                                                               │")
        [void]$sb.AppendLine("│ FILTERS:                                                      │")
        [void]$sb.AppendLine("│   fa        - Filter all            ft    - Filter today    │")
        [void]$sb.AppendLine("│   fh        - Filter high priority  c     - Global collapse │")
        [void]$sb.AppendLine("│                                                               │")
        [void]$sb.AppendLine("│ COMMANDS & HELP:                                              │")
        [void]$sb.AppendLine("│   /         - Command palette       ?     - Show help       │")
        [void]$sb.AppendLine("│   hh        - Full help             hk    - Show keys       │")
        [void]$sb.AppendLine("│   hc        - Show commands         F4    - Time entry mode │")
        [void]$sb.AppendLine("│                                                               │")
        [void]$sb.AppendLine("│ Press ESC or q to close help                                 │")
        [void]$sb.AppendLine("╰" + "─" * 63 + "╯")
        
        return $sb.ToString()
    }
    
    [string] GenerateQuickHelp() {
        return "↑↓=move  n=new  e=edit  yy=copy  pp=paste  /=commands  ?=help  q=quit"
    }
    
    [hashtable[]] GetKeyMappings() {
        $mappings = @()
        $modeMap = $this.KeyMaps["Normal"]
        
        foreach ($key in $modeMap.Keys) {
            if ($modeMap[$key] -is [hashtable]) {
                foreach ($subKey in $modeMap[$key].Keys) {
                    $mappings += @{
                        Key = "$key$subKey"
                        Action = $modeMap[$key][$subKey]
                    }
                }
            } else {
                $mappings += @{
                    Key = $key
                    Action = $modeMap[$key]
                }
            }
        }
        
        return $mappings | Sort-Object Key
    }
}