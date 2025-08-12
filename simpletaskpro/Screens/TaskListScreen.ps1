# TaskListScreen.ps1 - Simple task list with subtasks
# Enhanced with FastLineBuilder and SmoothRenderer for better performance

# Input state enumeration for state machine
enum TaskListInputState {
    Browsing
    Filtering
    TimeEntry
}

class TaskListScreen : BaseListScreen {
    [SimpleTaskService]$TaskService
    [KeyMappingService]$KeyService
    
    # State Machine property
    [TaskListInputState]$InputState = [TaskListInputState]::Browsing
    [SimpleTask[]]$Tasks
    [System.Collections.Generic.List[object]]$FlatList  # Flattened list for navigation
    [int]$SelectedIndex = 0
    [int]$PreviousSelectedIndex = 0  # For animation tracking
    [int]$ScrollTop = 0
    [int]$Width
    [int]$Height
    [bool]$GlobalCollapseSubtasks = $false
    [string]$CurrentFilter = "All"  # Filter mode: "All", "Today", "High", etc.
    [string]$TagFilter = ""  # Tag-based filter like "work", "personal", etc.
    
    # TIME ENTRY MODE - LEGACY (Now handled by separate TimeEntryScreen)
    [TimeTrackingService]$TimeService = $null
    [SimpleTimeEntry[]]$TimeEntries = @()
    [hashtable]$TaskLookup = @{}  # ID2 → SimpleTask mapping
    [object]$AppReference = $null
    
    # Status messages
    [string]$StatusMessage = ""
    [datetime]$StatusMessageTime = [DateTime]::MinValue
    
    # Time entry display state (when in TimeEntry mode)
    [System.Collections.Generic.List[object]]$TimeFlatList
    [int]$TimeSelectedIndex = 0
    [int]$TimeScrollTop = 0
    # All time editing state now handled by BaseListScreen
    [bool]$IsTimeFilterActive = $true  # Start filtered (show only entries with time)
    
    # Time entry column widths (matching TimeTracker exactly)
    [int]$NameCol = 25       # Task name or time code description
    [int]$ID1Col = 6         # Project code (5 chars + space) or time code
    [int]$ID2Col = 13        # Unique ID (12 chars + space)
    [int]$MonCol = 8         # Monday hours
    [int]$TueCol = 8         # Tuesday hours
    [int]$WedCol = 8         # Wednesday hours
    [int]$ThuCol = 8         # Thursday hours
    [int]$FriCol = 8         # Friday hours
    [int]$TotalCol = 8       # Total hours
    
    # Time entry colors now use centralized theme
    
    # All editing state now handled by BaseListScreen (EditingItem, EditingField, EditingValue, EditingCursor)
    
    # Filter input state
    [bool]$FilterInputActive = $false
    [string]$FilterInputValue = ""
    [int]$FilterInputCursor = 0
    
    # All colors now use centralized AppThemeManager
    
    # Date and edit colors now use centralized theme
    [string]$EditHighlight = "`e[47;30m"  # White background, black text (simpler ANSI)
    
    # Column widths - project management layout
    [int]$COLUMN_ID1 = 5         # "Q4  " (3 chars + 2 spaces)
    [int]$COLUMN_ID2 = 14        # "RPT-2025-001  " (12 chars + 2 spaces)
    [int]$COLUMN_CREATED = 12    # "2025-08-06  " (10 chars + 2 spaces)
    [int]$COLUMN_DATE = 12       # "2025-08-06  " (10 chars + 2 spaces)
    [int]$COLUMN_ARROW = 3       # "▼  "
    [int]$TREE_INDENT = 7        # "    └─ " for subtasks
    [int]$SUBTASK_INDENT = 4     # "    " spacing
    
    # Legacy column widths (kept for compatibility)
    [int]$COLUMN_STATUS = 4      # Now ID1
    [int]$COLUMN_PRIORITY = 13   # Now ID2
    [int]$StatusCol = 4
    [int]$PriorityCol = 13 
    [int]$DateCol = 9
    [int]$ArrowCol = 3
    [int]$IndentWidth = 4
    
    # Built-in color themes - no external dependencies
    # Task colors now use centralized AppThemeManager
    
    # Subtask colors now use centralized AppThemeManager
    
    # Pillbox characters
    [string]$PillboxTopLeft = "╭"
    [string]$PillboxTopRight = "╮"
    [string]$PillboxBottomLeft = "╰"
    [string]$PillboxBottomRight = "╯"
    [string]$PillboxHorizontal = "─"
    [string]$PillboxVertical = "│"
    
    # Enhanced rendering components - unified architecture
    [FastLineBuilder]$LineBuilder  
    [UnifiedRenderer]$Renderer      # Replaces SmoothRenderer with StringBuilder-only approach
    # Removed UseEnhancedRendering toggle - enhanced rendering is now standard
    # Removed EnableSlideAnimations toggle - animations are always enabled
    
    TaskListScreen() {
        $this.TaskService = [SimpleTaskService]::new()
        $this.KeyService = [KeyMappingService]::new()
        $this.FlatList = [System.Collections.Generic.List[object]]::new()
        $this.TimeFlatList = [System.Collections.Generic.List[object]]::new()
        
        # Initialize unified rendering system - no fallback modes
        try {
            $this.LineBuilder = [FastLineBuilder]::new()
            $this.Renderer = [UnifiedRenderer]::new()  # UnifiedRenderer uses pure StringBuilder approach
            # Write-Host "Unified rendering system initialized successfully" -ForegroundColor Green
        } catch {
            Write-Warning "Unified rendering initialization failed: $_. Application may not function correctly."
            throw "Critical rendering system failure: $_"
        }
        
        # Using original hotkey system only
        
        # Initialize time service
        $this.TimeService = [TimeTrackingService]::new()
        
        # Migrate existing notes to files (run once, safe to call multiple times)
        $this.MigrateNotesToFiles()
        $this.LoadTasks()
    }
    
    # TIME ENTRY INITIALIZATION METHODS
    [void] SetAppReference($app) {
        $this.AppReference = $app
    }
    
    [void] InitializeTimeService() {
        try {
            $this.TimeService = [TimeTrackingService]::new()
            $this.LoadTaskLookup()
        } catch {
            Write-Warning "Time tracking unavailable: $_"
        }
    }
    
    [void] LoadTaskLookup() {
        if (-not $this.TimeService) { 
            "DEBUG: TimeService not available for LoadTaskLookup $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            return 
        }
        
        $allTasks = $this.TaskService.GetParentTasks()  # Get all tasks for lookup (no filtering)
        "DEBUG: LoadTaskLookup - Got $($allTasks.Count) parent tasks $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        $this.TaskLookup.Clear()
        
        foreach ($task in $allTasks) {
            # Index by ID2 (if populated)
            if ($task.ID2) {
                $this.TaskLookup[$task.ID2] = $task
                "DEBUG: Added task to lookup: ID2=$($task.ID2), Title=$($task.Title) $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            }
            # Also index by regular Id as fallback
            $this.TaskLookup[$task.Id] = $task
            
            # Include subtasks
            foreach ($subtask in $task.Subtasks) {
                if ($subtask.ID2) {
                    $this.TaskLookup[$subtask.ID2] = $subtask
                    "DEBUG: Added subtask to lookup: ID2=$($subtask.ID2), Title=$($subtask.Title) $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
                }
                $this.TaskLookup[$subtask.Id] = $subtask
            }
        }
        "DEBUG: TaskLookup loaded with $($this.TaskLookup.Keys.Count) keys $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
    }
    
    # TIME ENTRY MODE SWITCHING
    [void] SwitchToTimeEntryMode() {
        try {
            if (-not $this.TimeService) { 
                return 
            }
            # Time entry mode now handled by separate TimeEntryScreen
            $this.TimeSelectedIndex = 0
            $this.TimeScrollTop = 0
        } catch {
            # Fall back to tasks mode on error
            # Error logging removed - time entry handled by separate screen
        }
    }
    
    [void] SwitchToTaskMode() {
        # Legacy method - now handled by EventBus navigation
        $this.LoadTasks()
    }
    
    [void] LoadTimeEntries() {
        if (-not $this.TimeService) { return }
        
        $allEntries = $this.TimeService.GetCurrentWeekEntries()
        "DEBUG: LoadTimeEntries - allEntries count: $($allEntries.Count) $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        
        if ($this.IsTimeFilterActive) {
            # Filtered: Only show entries with time > 0 this week
            $this.TimeEntries = $allEntries | Where-Object { $_.Total -gt 0 }
            "DEBUG: Filtered mode - TimeEntries count: $($this.TimeEntries.Count) $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        } else {
            # Unfiltered: Show all current week entries PLUS all projects as potential entries
            $this.TimeEntries = @()
            
            # Add existing time entries
            $this.TimeEntries += $allEntries
            "DEBUG: After adding existing entries - TimeEntries count: $($this.TimeEntries.Count) $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            
            # Add placeholder entries for all projects that don't have time logged yet
            $existingProjectCodes = $allEntries | Where-Object { $_.ProjectCode } | ForEach-Object { $_.ProjectCode }
            "DEBUG: Existing project codes: $($existingProjectCodes -join ', ') $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            "DEBUG: TaskLookup has $($this.TaskLookup.Keys.Count) keys $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            
            foreach ($projectCode in $this.TaskLookup.Keys) {
                $task = $this.TaskLookup[$projectCode]
                # Only add if it's a project (has ID2) and doesn't already have a time entry
                if ($task.ID2 -and $task.ID2 -notin $existingProjectCodes) {
                    $placeholderEntry = [SimpleTimeEntry]::new()
                    $placeholderEntry.ProjectCode = $task.ID2
                    $placeholderEntry.Description = $task.Title
                    $placeholderEntry.ID1Display = if ($task.ID1) { $task.ID1 } else { "" }
                    $placeholderEntry.IsProjectEntry = $true
                    $placeholderEntry.WeekEndingFriday = $this.TimeService.CurrentWeekFriday.ToString("yyyyMMdd")
                    $this.TimeEntries += $placeholderEntry
                    "DEBUG: Added placeholder for $($task.ID1) $($task.ID2) - $($task.Title) $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
                }
            }
            "DEBUG: Final TimeEntries count: $($this.TimeEntries.Count) $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        }
        
        $this.BuildTimeFlatList()
        "DEBUG: TimeFlatList count after build: $($this.TimeFlatList.Count) $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        
        if ($this.TimeSelectedIndex -ge $this.TimeFlatList.Count) {
            $this.TimeSelectedIndex = [Math]::Max(0, $this.TimeFlatList.Count - 1)
        }
    }
    
    [void] BuildTimeFlatList() {
        $this.TimeFlatList.Clear()
        
        foreach ($entry in $this.TimeEntries) {
            if ($entry) {  # Add null check
                $this.TimeFlatList.Add(@{
                    Entry = $entry
                    IsLast = $false
                })
            }
        }
    }
    
    # Self-contained color theme methods - replace ColorThemeService
    [string] GetTaskColor([string]$theme) {
        # For now, use the main text color - theme-specific task colors
        # will be handled by AppThemeManager in the future
        return [AppThemeManager]::GetColor("Text")
    }
    
    [string] GetSubtaskColor([string]$theme) {
        # For now, use muted color for all subtasks
        # Theme-specific subtask colors will be handled by AppThemeManager in the future
        return [AppThemeManager]::GetColor("Muted")
    }
    
    [string] GetNextTheme([string]$currentTheme) {
        $themes = @("default", "red", "blue", "green", "purple", "orange", "cyan", "pink")
        $currentIndex = $themes.IndexOf($currentTheme)
        if ($currentIndex -eq -1) { $currentIndex = 0 }
        $nextIndex = ($currentIndex + 1) % $themes.Count
        return $themes[$nextIndex]
    }
    
    [void] Initialize([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
    }
    
    [void] LoadTasks() {
        # Phase 2.4: Use enhanced service method with filtering parameters
        $this.Tasks = $this.TaskService.GetParentTasks($this.CurrentFilter, $this.TagFilter)
        $this.BuildFlatList()
        
        if ($this.SelectedIndex -ge $this.FlatList.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
        }
    }
    
    # Phase 2.4: FilterTasks method removed - filtering logic moved to SimpleTaskService.GetParentTasks()
    
    # Step 3.4: Advanced Data Entry Shortcuts (moved from FastLineBuilder)
    [string] ConvertPriorityInput([string]$input) {
        # Convert h/m/l/t input to High/Medium/Low/Today (only accept single letters)
        $cleanInput = $input.ToLower().Trim()
        switch ($cleanInput) {
            "h" { return "High" }
            "m" { return "Medium" }
            "l" { return "Low" }
            "t" { return "Today" }
            default { 
                return ""  # Return empty if invalid input
            }
        }
        return ""  # PowerShell requires explicit return after switch
    }
    
    [datetime] ConvertDateInput([string]$input) {
        # Enhanced date input with quick entry shortcuts
        $input = $input.Trim().ToLower()
        if ($input -eq "" -or $input -eq "clear") {
            return [datetime]::MinValue
        }
        
        $today = [datetime]::Today
        
        # Quick date shortcuts
        switch ($input) {
            "tod" { return $today }
            "today" { return $today }
            "tom" { return $today.AddDays(1) }
            "tomorrow" { return $today.AddDays(1) }
            "yes" { return $today.AddDays(-1) }
            "yesterday" { return $today.AddDays(-1) }
            "mon" { return $this.GetNextWeekday([DayOfWeek]::Monday) }
            "tue" { return $this.GetNextWeekday([DayOfWeek]::Tuesday) }
            "wed" { return $this.GetNextWeekday([DayOfWeek]::Wednesday) }
            "thu" { return $this.GetNextWeekday([DayOfWeek]::Thursday) }
            "fri" { return $this.GetNextWeekday([DayOfWeek]::Friday) }
            "sat" { return $this.GetNextWeekday([DayOfWeek]::Saturday) }
            "sun" { return $this.GetNextWeekday([DayOfWeek]::Sunday) }
            default { }  # Continue to next parsing logic
        }
        
        # Relative date shortcuts (+3, +1w, etc.)
        if ($input -match '^\+(\d+)$') {
            $days = [int]$matches[1]
            return $today.AddDays($days)
        }
        if ($input -match '^\+(\d+)w$') {
            $weeks = [int]$matches[1]
            return $today.AddDays($weeks * 7)
        }
        
        # Try standard date parsing
        try {
            $result = [datetime]::ParseExact($input, @("yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "M/d/yyyy", "yyyy-M-d"), $null, [System.Globalization.DateTimeStyles]::None)
            return $result
        } catch {
            try {
                # Fallback to general parsing
                $result = [datetime]::Parse($input)
                return $result
            } catch {
                # If all parsing fails, return MinValue
                return [datetime]::MinValue
            }
        }
    }
    
    [datetime] GetNextWeekday([DayOfWeek]$targetDay) {
        $today = [datetime]::Today
        $daysUntilTarget = ([int]$targetDay - [int]$today.DayOfWeek + 7) % 7
        if ($daysUntilTarget -eq 0) {
            $daysUntilTarget = 7  # Next week if today is the target day
        }
        return $today.AddDays($daysUntilTarget)
    }
    
    [int] GetItemHeight([int]$itemIndex) {
        # Selected item gets pillbox (5 lines: spacer + top + content + content + bottom)
        # Normal item gets 2 lines
        if ($itemIndex -eq $this.SelectedIndex) {
            return 5
        } else {
            return 2
        }
    }
    
    [int] CalculatePillboxWidth([SimpleTask]$task, [int]$level) {
        # Calculate minimum width needed for content
        $line1Length = $this.GetContentLength($task, $level)
        
        # Calculate tag line length
        $line2Length = 0
        if ($task.Tags.Count -gt 0) {
            $indentSize = $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
            if ($level -eq 1) {
                $indentSize += 7  # "    └─ "
            }
            $line2Length = $indentSize + 1 + ($task.Tags -join ", ").Length + 1  # "⟨tags⟩"
        }
        
        # Use the longer of the two lines, plus borders and padding  
        $contentWidth = [Math]::Max($line1Length, $line2Length)
        $pillboxWidth = $contentWidth + 4  # "│" + " " + content + "│"
        
        # Ensure minimum width and don't exceed screen
        $minWidth = 40
        $maxWidth = $this.Width - 4
        
        return [Math]::Min($maxWidth, [Math]::Max($minWidth, $pillboxWidth))
    }
    
    [void] RenderPillboxTop([System.Text.StringBuilder]$sb, [int]$width, [int]$y) {
        [void]$sb.Append([VT]::MoveTo(0, $y))
        [void]$sb.Append([AppThemeManager]::GetColor("Header"))
        [void]$sb.Append($this.PillboxTopLeft)
        [void]$sb.Append($this.PillboxHorizontal * ($width - 2))
        [void]$sb.Append($this.PillboxTopRight)
        [void]$sb.Append([VT]::Reset())
    }
    
    [void] RenderPillboxBottom([System.Text.StringBuilder]$sb, [int]$width, [int]$y) {
        [void]$sb.Append([VT]::MoveTo(0, $y))
        [void]$sb.Append([AppThemeManager]::GetColor("Header"))
        [void]$sb.Append($this.PillboxBottomLeft)
        [void]$sb.Append($this.PillboxHorizontal * ($width - 2))
        [void]$sb.Append($this.PillboxBottomRight)
        [void]$sb.Append([VT]::Reset())
    }
    
    [void] RenderPillboxSide([System.Text.StringBuilder]$sb, [int]$x, [int]$y) {
        [void]$sb.Append([VT]::MoveTo($x, $y))
        [void]$sb.Append([AppThemeManager]::GetColor("Header"))
        [void]$sb.Append($this.PillboxVertical)
        [void]$sb.Append([VT]::Reset())
    }

    
    [void] StartFilterInput() {
        # Start complex filter input mode
        $this.FilterInputActive = $true
        $this.FilterInputValue = ""
        $this.FilterInputCursor = 0
    }
    
    [void] EndFilterInput([bool]$apply = $true) {
        if ($apply -and $this.FilterInputValue.Trim() -ne "") {
            $filterText = $this.FilterInputValue.Trim()
            
            # Parse filter: #tag for tag filter, priority names for priority filter
            if ($filterText -eq "clear") {
                # Clear all filters
                $this.CurrentFilter = "All"
                $this.TagFilter = ""
            } elseif ($filterText.StartsWith("#")) {
                $this.TagFilter = $filterText.Substring(1)
                $this.CurrentFilter = "All"  # Reset priority filter
            } elseif ($filterText -eq "high" -or $filterText -eq "h") {
                $this.CurrentFilter = "High"
                $this.TagFilter = ""
            } elseif ($filterText -eq "medium" -or $filterText -eq "med" -or $filterText -eq "m") {
                $this.CurrentFilter = "Medium"
                $this.TagFilter = ""
            } elseif ($filterText -eq "low" -or $filterText -eq "l") {
                $this.CurrentFilter = "Low"
                $this.TagFilter = ""
            } elseif ($filterText -eq "today" -or $filterText -eq "t") {
                $this.CurrentFilter = "Today"
                $this.TagFilter = ""
            } elseif ($filterText -eq "all" -or $filterText -eq "*") {
                $this.CurrentFilter = "All"
                $this.TagFilter = ""
            } else {
                # Default to tag filter (without #)
                $this.TagFilter = $filterText
                $this.CurrentFilter = "All"
            }
            
            $this.LoadTasks()
        }
        
        $this.FilterInputActive = $false
        $this.FilterInputValue = ""
        $this.FilterInputCursor = 0
        # State Machine: Return to browsing state
        $this.InputState = [TaskListInputState]::Browsing
    }
    
    [bool] HandleFilterInput([System.ConsoleKeyInfo]$key) {
        # Use KeyMappingService for filter commands
        if ($this.KeyService.MatchesAction($key, "CommitEdit")) {
            $this.EndFilterInput($true)
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "CancelEdit")) {
            $this.EndFilterInput($false)
            return $true
        }
        
        # Handle text input keys
        switch ($key.Key) {
            ([System.ConsoleKey]::Backspace) {
                if ($this.FilterInputCursor -gt 0) {
                    $this.FilterInputValue = $this.FilterInputValue.Remove($this.FilterInputCursor - 1, 1)
                    $this.FilterInputCursor--
                }
                return $true
            }
            ([System.ConsoleKey]::LeftArrow) {
                if ($this.FilterInputCursor -gt 0) {
                    $this.FilterInputCursor--
                }
                return $true
            }
            ([System.ConsoleKey]::RightArrow) {
                if ($this.FilterInputCursor -lt $this.FilterInputValue.Length) {
                    $this.FilterInputCursor++
                }
                return $true
            }
            ([System.ConsoleKey]::Home) {
                $this.FilterInputCursor = 0
                return $true
            }
            ([System.ConsoleKey]::End) {
                $this.FilterInputCursor = $this.FilterInputValue.Length
                return $true
            }
            default {
                # Handle printable characters with length validation
                if (-not [char]::IsControl($key.KeyChar)) {
                    $newValue = $this.FilterInputValue.Insert($this.FilterInputCursor, $key.KeyChar)
                    # Limit filter input to reasonable length
                    if ($newValue.Length -le 20) {
                        $this.FilterInputValue = $newValue
                        $this.FilterInputCursor++
                    }
                    return $true
                }
            }
        }
        return $false
    }

    [void] RenderSubtaskPriorityAndDate([System.Text.StringBuilder]$sb, [SimpleTask]$task, [bool]$isEditingThis) {
        # Render priority if set or being edited
        if ($isEditingThis -and $this.EditingField -eq "priority") {
            # Show active field with bright highlight (2 chars for subtask priority)
            $fieldValue = $this.EditingValue.PadRight(2)
            [void]$sb.Append($this.EditHighlight + $fieldValue + [VT]::Reset())
        } elseif ($isEditingThis -and ($task.Priority -eq "High" -or $task.Priority -eq "Medium" -or $task.Priority -eq "Low" -or $task.Priority -eq "Today")) {
            # Show inactive field with dim highlight when editing other fields
            $priorityText = switch ($task.Priority) {
                "High" { "H " }
                "Medium" { "M " }
                "Low" { "L " }
                "Today" { "T " }
            }
            [void]$sb.Append("`e[48;2;30;30;40m" + $priorityText + [VT]::Reset())
        } elseif ($task.Priority -eq "High" -or $task.Priority -eq "Medium" -or $task.Priority -eq "Low" -or $task.Priority -eq "Today") {
            $priorityText = switch ($task.Priority) {
                "High" { "H" }
                "Medium" { "M" }
                "Low" { "L" }
                "Today" { "T" }
            }
            $priorityColor = switch ($task.Priority) {
                "High" { [AppThemeManager]::GetColor("High") }
                "Medium" { [AppThemeManager]::GetColor("Medium") }
                "Low" { [AppThemeManager]::GetColor("Low") }
                "Today" { [AppThemeManager]::GetColor("Today") }
            }
            [void]$sb.Append($priorityColor + $priorityText + [VT]::Reset() + " ")
        }
        
        # Render date if set or being edited
        if ($isEditingThis -and $this.EditingField -eq "date") {
            # Show active field with bright highlight (6 chars for MM-dd format)
            $fieldValue = $this.EditingValue.PadRight(6)
            [void]$sb.Append($this.EditHighlight + $fieldValue + [VT]::Reset())
        } elseif ($isEditingThis -and $task.DueDate -ne [datetime]::MinValue) {
            # Show inactive field with dim highlight when editing other fields
            $compactDate = $task.DueDate.ToString("MM-dd").PadRight(6)
            [void]$sb.Append("`e[48;2;30;30;40m" + $compactDate + [VT]::Reset())
        } elseif ($task.DueDate -ne [datetime]::MinValue) {
            $compactDate = $task.DueDate.ToString("MM-dd")
            $today = [datetime]::Today
            $due = $task.DueDate.Date
            $days = ($due - $today).Days
            
            # Use same colors as parent tasks
            $dateColor = if ($days -lt 0) {
                [AppThemeManager]::GetColor("High")
            } elseif ($days -eq 0) {
                [AppThemeManager]::GetColor("Today")
            } elseif ($days -le 7) {
                [AppThemeManager]::GetColor("Medium")
            } else {
                [AppThemeManager]::GetColor("Low")
            }
            [void]$sb.Append($dateColor + $compactDate + [VT]::Reset() + " ")
        }
    }

    [string] GetDateColorAndText([SimpleTask]$task) {
        if ($task.DueDate -eq [datetime]::MinValue) {
            return [AppThemeManager]::GetColor("Muted") + "-".PadRight(8) + [VT]::Reset()
        }
        
        $today = [datetime]::Today
        $due = $task.DueDate.Date
        $daysDiff = ($due - $today).Days
        
        $dateText = $due.ToString("yyyy-MM-dd")
        $color = if ($daysDiff -lt 0) { [AppThemeManager]::GetColor("High") }
                elseif ($daysDiff -eq 0) { [AppThemeManager]::GetColor("Today") }
                elseif ($daysDiff -le 7) { [AppThemeManager]::GetColor("Medium") }
                else { [AppThemeManager]::GetColor("Low") }
        
        return $color + $dateText + [VT]::Reset()
    }

    [string] GetDateColorAndTextFormatted([SimpleTask]$task) {
        if ($task.DueDate -eq [datetime]::MinValue) {
            return [AppThemeManager]::GetColor("Muted") + "-".PadRight(10) + [VT]::Reset()
        }
        
        $today = [datetime]::Today
        $due = $task.DueDate.Date
        $daysDiff = ($due - $today).Days
        
        $dateText = $due.ToString("yyyy-MM-dd")
        $color = if ($daysDiff -lt 0) { [AppThemeManager]::GetColor("High") }
                elseif ($daysDiff -eq 0) { [AppThemeManager]::GetColor("Today") }
                elseif ($daysDiff -le 7) { [AppThemeManager]::GetColor("Medium") }
                else { [AppThemeManager]::GetColor("Low") }
        
        return $color + $dateText + [VT]::Reset()
    }

    [string] GetDateColor([datetime]$date) {
        if ($date -eq [datetime]::MinValue) {
            return [AppThemeManager]::GetColor("Muted")
        }
        
        $today = [datetime]::Today
        $due = $date.Date
        $daysDiff = ($due - $today).Days
        
        if ($daysDiff -lt 0) { 
            return [AppThemeManager]::GetColor("High") 
        } elseif ($daysDiff -eq 0) { 
            return [AppThemeManager]::GetColor("Today") 
        } elseif ($daysDiff -le 7) { 
            return [AppThemeManager]::GetColor("Medium") 
        } else { 
            return [AppThemeManager]::GetColor("Low") 
        }
    }

    [void] BuildFlatList() {
        $this.FlatList.Clear()
        
        foreach ($task in $this.Tasks) {
            # Add parent task
            $this.FlatList.Add(@{
                Task = $task
                Level = 0
                IsLast = $false
            })
            
            # Add subtasks only if not collapsed (check both global and task-specific)
            $shouldShowSubtasks = -not $this.GlobalCollapseSubtasks -and -not $task.SubtasksCollapsed
            if ($shouldShowSubtasks -and $task.Subtasks.Count -gt 0) {
                for ($i = 0; $i -lt $task.Subtasks.Count; $i++) {
                    $subtask = $task.Subtasks[$i]
                    $isLast = ($i -eq $task.Subtasks.Count - 1)
                    
                    $this.FlatList.Add(@{
                        Task = $subtask
                        Level = 1
                        IsLast = $isLast
                    })
                }
            }
        }
    }
    
    # === BaseListScreen Required Methods ===
    
    [void] LoadData() {
        $this.LoadTasks()
    }
    
    [string] RenderItem([object]$item, [int]$index, [bool]$isSelected) {
        # Delegate to existing TaskListScreen rendering logic
        return $this.RenderTaskLine($item.Task, $item.Level, $isSelected)
    }
    
    [string[]] GetEditableFields([object]$item) {
        # Return editable fields for SimpleTask objects
        "DEBUG: GetEditableFields called with item type: $($item.GetType().Name) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        try {
            $fields = @("Title", "Priority", "DueDate", "Tags", "ID1", "ID2", "CreatedDate")  # All editable fields
            "DEBUG: GetEditableFields returning fields: $($fields -join ', ') $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            return $fields
        } catch {
            "DEBUG: ERROR in GetEditableFields: $($_.Exception.Message) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            throw
        }
    }
    
    [void] SaveItem([object]$item) {
        # Save changes to TaskService
        $this.TaskService.Save()
    }
    
    [object] CreateNewItem() {
        # Create new SimpleTask
        $newTask = [SimpleTask]::new("New Task")
        $this.TaskService.AddTask($newTask)
        return $newTask
    }
    
    # Override StartNewItem to handle FlatList hashtable structure
    [void] StartNewItem() {
        $newTask = $this.CreateNewItem()
        $this.LoadData() # Refresh FlatList with proper hashtable structure
        
        # Find the new task in FlatList and select it
        for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
            if ($this.FlatList[$i].Task.Id -eq $newTask.Id) {
                $this.SelectedIndex = $i
                $this.EnsureVisible()
                
                # Start editing the new task
                $fields = $this.GetEditableFields($this.FlatList[$i])
                if ($fields.Count -gt 0) {
                    $this.StartEdit($fields[0])
                }
                break
            }
        }
    }
    
    # Override field access methods to work with FlatList hashtable structure
    [string] GetFieldValue([object]$item, [string]$field) {
        # $item is a hashtable like @{Task=..., Level=..., IsLast=...}
        # Access the actual Task object
        "DEBUG: GetFieldValue called with field '$field' on item type $($item.GetType().Name) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        try {
            $task = $item.Task
            "DEBUG: GetFieldValue accessing task type $($task.GetType().Name) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            
            # Map FastLineBuilder field names to SimpleTask property names
            $propertyName = switch ($field) {
                "title" { "Title" }
                "priority" { "Priority" }
                "date" { "DueDate" }
                "tags" { "Tags" }
                default { $field }  # Use as-is for other fields
            }
            
            $property = $task.GetType().GetProperty($propertyName)
            if ($property) {
                "DEBUG: GetFieldValue found property $field $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                $value = $property.GetValue($task)
                $result = if ($value -ne $null) { $value.ToString() } else { "" }
                "DEBUG: GetFieldValue returning '$result' for field $field $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                return $result
            } else {
                "DEBUG: GetFieldValue property $field not found, trying fallback $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                if ($task.$field -ne $null) {
                    $result = $task.$field.ToString()
                    "DEBUG: GetFieldValue fallback returning '$result' for field $field $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                    return $result
                }
            }
        } catch {
            "DEBUG: ERROR in GetFieldValue: $($_.Exception.Message) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            throw
        }
        "DEBUG: GetFieldValue returning empty string for field $field $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        return ""
    }
    
    [void] SetFieldValue([object]$item, [string]$field, [string]$value) {
        # $item is a hashtable like @{Task=..., Level=..., IsLast=...}
        # Access the actual Task object
        "DEBUG: SetFieldValue called with field '$field' value '$value' $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        $task = $item.Task
        try {
            # Map FastLineBuilder field names to SimpleTask property names
            $propertyName = switch ($field) {
                "title" { "Title" }
                "priority" { "Priority" }
                "date" { "DueDate" }
                "tags" { "Tags" }
                default { $field }  # Use as-is for other fields
            }
            
            $property = $task.GetType().GetProperty($propertyName)
            if ($property -and $property.CanWrite) {
                # Convert value to appropriate type
                $targetType = $property.PropertyType
                $convertedValue = $this.ConvertValue($value, $targetType)
                $property.SetValue($task, $convertedValue)
                "DEBUG: SetFieldValue completed successfully $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                return
            }
        } catch {
            "DEBUG: ERROR in SetFieldValue: $($_.Exception.Message), trying fallback $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            # Fallback for direct property access
            $task.$field = $value
        }
    }
    
    # Override DeleteCurrentItem to properly delete tasks from TaskService
    [void] DeleteCurrentItem() {
        "DEBUG: DeleteCurrentItem called $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        try {
            if ($this.FlatList.Count -eq 0) { 
                "DEBUG: DeleteCurrentItem - no items in FlatList $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                return 
            }
            
            "DEBUG: DeleteCurrentItem - getting item at index $($this.SelectedIndex) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            $item = $this.FlatList[$this.SelectedIndex]
            $task = $item.Task
            "DEBUG: DeleteCurrentItem - got task with ID $($task.Id) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            
            # Delete from TaskService
            "DEBUG: DeleteCurrentItem - calling TaskService.DeleteTask $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            $this.TaskService.DeleteTask($task.Id)
            "DEBUG: DeleteCurrentItem - TaskService.DeleteTask completed $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            
            # Remove from FlatList
            "DEBUG: DeleteCurrentItem - removing from FlatList $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            $this.FlatList.RemoveAt($this.SelectedIndex)
            "DEBUG: DeleteCurrentItem - removed from FlatList $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            
            # Adjust selection
            if ($this.SelectedIndex -ge $this.FlatList.Count) {
                $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
            }
            "DEBUG: DeleteCurrentItem - adjusted selection to $($this.SelectedIndex) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            
            $this.SetStatusMessage("Task deleted", 2000)
            "DEBUG: DeleteCurrentItem completed successfully $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        } catch {
            "DEBUG: ERROR in DeleteCurrentItem: $($_.Exception.Message) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            throw
        }
    }
    
    # Override GetFieldScreenPosition to provide correct cursor positioning
    [hashtable] GetFieldScreenPosition([string]$field, [int]$cursor, [object]$item) {
        # Calculate the actual screen position where each field appears
        # Based on TaskListScreen's pillbox layout
        
        # Find the editing item's screen position
        $editingIndex = -1
        for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
            if ($this.FlatList[$i].Task.Id -eq $item.Task.Id) {
                $editingIndex = $i
                break
            }
        }
        
        if ($editingIndex -eq -1) {
            return @{ X = 2; Y = 3 }  # Fallback position
        }
        
        # Calculate Y position based on item position and scrolling
        $startY = 3
        $currentY = $startY
        for ($i = $this.ScrollTop; $i -lt $editingIndex; $i++) {
            if ($i -eq $this.SelectedIndex) {
                $currentY += 4  # Selected item with pillbox
            } else {
                $currentY += 2  # Normal item
            }
        }
        
        # If editing item is selected, it's inside pillbox
        if ($editingIndex -eq $this.SelectedIndex) {
            $contentLineY = $currentY + 1  # Content line is after top border
            
            switch ($field) {
                "Title" {
                    return @{ X = 2 + $cursor; Y = $contentLineY }
                }
                "Priority" {
                    return @{ X = 60 + $cursor; Y = $contentLineY }
                }
                "DueDate" {
                    return @{ X = 85 + $cursor; Y = $contentLineY }
                }
                "Tags" {
                    return @{ X = 10 + $cursor; Y = $contentLineY + 1 }
                }
                "ID1" {
                    return @{ X = 10 + $cursor; Y = $contentLineY }
                }
                "ID2" {
                    return @{ X = 25 + $cursor; Y = $contentLineY }
                }
                "CreatedDate" {
                    return @{ X = 45 + $cursor; Y = $contentLineY }
                }
                default {
                    return @{ X = 2 + $cursor; Y = $contentLineY }
                }
            }
        } else {
            # Not selected item - simpler positioning
            return @{ X = 2 + $cursor; Y = $currentY }
        }
        
        # This should never be reached, but PowerShell requires explicit return
        return @{ X = 2; Y = 3 }
    }
    
    [object] ConvertValue([string]$value, [Type]$targetType) {
        "DEBUG: ConvertValue called: '$value' to type $($targetType.Name) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        try {
            if ($targetType -eq [string]) { return $value }
            if ($targetType -eq [int]) { return if ($value) { [int]$value } else { 0 } }
            if ($targetType -eq [bool]) { return [bool]$value }
            if ($targetType -eq [datetime]) { 
                return if ($value) { [datetime]::Parse($value) } else { [datetime]::MinValue }
            }
            if ($targetType -eq [string[]]) {
                return if ($value) { $value -split ',' | ForEach-Object { $_.Trim() } } else { @() }
            }
            "DEBUG: ConvertValue using default conversion $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            return $value  # Default fallback
        } catch {
            "DEBUG: ERROR in ConvertValue: $($_.Exception.Message) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            return $value
        }
    }
    
    # Override field cycling to add wraparound behavior
    [void] NextEditField() {
        if ($this.EditingItem -eq $null) { return }
        
        $fields = $this.GetEditableFields($this.EditingItem)
        $currentIndex = $fields.IndexOf($this.EditingField)
        
        if ($currentIndex -ge 0) {
            # Wraparound: if at last field, go to first field
            $nextIndex = ($currentIndex + 1) % $fields.Count
            $this.EditingField = $fields[$nextIndex]
            $this.EditingValue = $this.GetFieldValue($this.EditingItem, $this.EditingField)
            $this.EditingCursor = $this.EditingValue.Length
        }
    }
    
    [void] PreviousEditField() {
        if ($this.EditingItem -eq $null) { return }
        
        $fields = $this.GetEditableFields($this.EditingItem)
        $currentIndex = $fields.IndexOf($this.EditingField)
        
        if ($currentIndex -ge 0) {
            # Wraparound: if at first field, go to last field
            $prevIndex = if ($currentIndex -eq 0) { $fields.Count - 1 } else { $currentIndex - 1 }
            $this.EditingField = $fields[$prevIndex]
            $this.EditingValue = $this.GetFieldValue($this.EditingItem, $this.EditingField)
            $this.EditingCursor = $this.EditingValue.Length
        }
    }
    
    [string] Render() {
        # TaskListScreen now only renders task mode - TimeEntry handled by separate screen
        $baseContent = $this.RenderTaskModeEnhanced()
        
        # Add modal system overlays
        return $this.RenderWithOverlays($baseContent)
    }
    
    [string] RenderWithOverlays([string]$baseContent) {
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.Append($baseContent)
        
        # Add status line with modal engine status
        if ($this.ModalEngine) {
            $statusLine = $this.ModalEngine.GetStatusLine()
            if ($this.StatusMessage -and ([DateTime]::Now - $this.StatusMessageTime).TotalSeconds -lt 3) {
                $statusLine += " | $($this.StatusMessage)"
            }
            
            [void]$sb.Append([VT]::MoveTo(0, $this.Height - 1))
            [void]$sb.Append([AppThemeManager]::GetColor("Muted"))
            [void]$sb.Append($statusLine.PadRight($this.Width))
            [void]$sb.Append([VT]::Reset())
        }
        
        # Render help screen overlay
        if ($this.ShowHelpScreen -and $this.ModalEngine) {
            $helpContent = $this.ModalEngine.GenerateHelpScreen()
            $helpLines = $helpContent -split "`n"
            
            $helpWidth = 65
            $helpHeight = $helpLines.Count
            $helpX = ($this.Width - $helpWidth) / 2
            $helpY = ($this.Height - $helpHeight) / 2
            
            for ($i = 0; $i -lt $helpLines.Count; $i++) {
                if ($helpY + $i -lt $this.Height -and $helpY + $i -ge 0) {
                    [void]$sb.Append([VT]::MoveTo($helpX, $helpY + $i))
                    [void]$sb.Append($helpLines[$i])
                }
            }
        }
        
        # Render command palette overlay
        if ($this.ShowCommandPalette -and $this.CommandPalette -and $this.CommandPalette.IsActive) {
            $paletteHeight = [Math]::Min(15, $this.Height - 2)
            $paletteWidth = [Math]::Min(80, $this.Width - 4)
            $paletteX = ($this.Width - $paletteWidth) / 2
            $paletteY = ($this.Height - $paletteHeight) / 2
            
            $paletteContent = $this.CommandPalette.Render($paletteWidth, $paletteHeight)
            $paletteLines = $paletteContent -split "`n"
            
            for ($i = 0; $i -lt $paletteLines.Count; $i++) {
                if ($paletteY + $i -lt $this.Height) {
                    [void]$sb.Append([VT]::MoveTo($paletteX, $paletteY + $i))
                    [void]$sb.Append($paletteLines[$i])
                }
            }
        }
        
        return $sb.ToString()
    }
    
    [string] RenderTaskMode() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Clear screen
        [void]$sb.Append([VT]::Clear())
        
        # Header with filter info
        [void]$sb.Append([VT]::MoveTo(0, 0))
        [void]$sb.Append([AppThemeManager]::GetColor("Header"))
        $headerText = "TASKPRO - Task Manager"
        if ($this.CurrentFilter -ne "All") {
            $headerText += " [Filter: $($this.CurrentFilter)]"
        }
        if ($this.TagFilter -ne "") {
            $headerText += " [Tag: #$($this.TagFilter)]"
        }
        [void]$sb.Append($headerText)
        [void]$sb.Append([VT]::Reset())
        
        # Column headers
        [void]$sb.Append([VT]::MoveTo(0, 1))
        [void]$sb.Append([AppThemeManager]::GetColor("Muted"))
        [void]$sb.Append(" ID1  ")     # SHIFTED RIGHT: ID1 column (5 chars)
        [void]$sb.Append("ID2           ") # ID2 column (14 chars)
        [void]$sb.Append("Created     ")   # Created date column (12 chars)
        [void]$sb.Append("Due         ")   # Due date column (12 chars)
        [void]$sb.Append("  Title")        # Arrow + title
        [void]$sb.Append([VT]::Reset())
        
        [void]$sb.Append([VT]::MoveTo(0, 2))
        [void]$sb.Append(" " + ("─" * ($this.Width - 1)))  # SHIFTED RIGHT
        
        # Task list
        $this.RenderTaskList($sb)
        
        # Status bar
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 2))
        [void]$sb.Append(" " + ("─" * ($this.Width - 1)))  # SHIFTED RIGHT
        
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 1))
        [void]$sb.Append([AppThemeManager]::GetColor("Muted"))
        if ($this.FilterInputActive) {
            # Show filter input as a proper textbox
            $filterPrompt = " Filter: "  # SHIFTED RIGHT
            [void]$sb.Append($filterPrompt)
            $fieldWidth = 20
            $fieldValue = $this.FilterInputValue.PadRight($fieldWidth)
            [void]$sb.Append($this.EditHighlight + $fieldValue + [VT]::Reset())
            [void]$sb.Append("   Enter:Apply  Escape:Cancel  (#tag, high/med/low/today, clear)")  # SHIFTED RIGHT
        } elseif ($this.EditingItem -ne $null) {
            [void]$sb.Append(" EDITING [$($this.EditingField.ToUpper())]: Tab:Next Field  Enter:Save  Escape:Cancel")  # SHIFTED RIGHT
        } else {
            [void]$sb.Append(" ↑↓:Navigate  E:Edit  N:New  S:Subtask  X:Toggle  T:Theme  /:Filter  F1:All  F2:Today  F3:High  F4:TimeEntry  F5:Color  F6:Excel  F7:Settings  F8:Folder  F9:T2020  F10:Export  F11:Log  F12:Cycle  Q:Quit")  # SHIFTED RIGHT
        }
        [void]$sb.Append([VT]::Reset())
        
        # Show/hide cursor based on editing state and position it correctly with enhanced positioning
        if ($this.EditingItem -ne $null) {
            [void]$sb.Append([VT]::ShowCursor())
            # Set cursor to bright red so it's visible against white background
            [void]$sb.Append("`e]12;#FF0000`e\")  # OSC sequence to set cursor color to red
            # Use enhanced cursor positioning
            $this.PositionEnhancedEditingCursor($sb)
        } elseif ($this.FilterInputActive) {
            [void]$sb.Append([VT]::ShowCursor())
            # Set cursor to bright red for visibility
            [void]$sb.Append("`e]12;#FF0000`e\")
            # Position cursor in filter input field
            $filterCursorX = 8 + $this.FilterInputCursor  # "Filter: " = 8 chars
            [void]$sb.Append([VT]::MoveTo($filterCursorX, $this.Height - 1))
        } else {
            [void]$sb.Append([VT]::HideCursor())
            # Reset cursor color to default when hidden
            [void]$sb.Append("`e]12;#FFFFFF`e\")  # Reset to white
        }
        
        return $sb.ToString()
    }
    
    # COMPLETE UNIFIED RENDERING - Pure StringBuilder, everything integrated
    [string] RenderTaskModeEnhanced() {
        # No fallback modes - unified rendering is the only rendering system
        if ($this.LineBuilder -eq $null -or $this.Renderer -eq $null) {
            throw "Critical error: Unified rendering system not initialized"
        }
        
        # Build ENTIRE screen in single StringBuilder - no separate rendering calls
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.Append([VT]::Clear())
        
        # Header with filter info - using centralized theme system
        [void]$sb.Append([VT]::MoveTo(0, 0))
        [void]$sb.Append([AppThemeManager]::GetColor("Header"))  # Centralized theme instead of hardcoded
        $headerText = " TASKPRO - Task Manager (Enhanced)"
        if ($this.CurrentFilter -ne "All") {
            $headerText += " [Filter: $($this.CurrentFilter)]"
        }
        if ($this.TagFilter -ne "") {
            $headerText += " [Tag: #$($this.TagFilter)]"
        }
        [void]$sb.Append($headerText.PadRight($this.Width))
        [void]$sb.Append([VT]::Reset())
        
        # Column headers
        [void]$sb.Append([VT]::MoveTo(0, 1))
        [void]$sb.Append([AppThemeManager]::GetColor("Muted"))
        [void]$sb.Append(" ID1  ")     # SHIFTED RIGHT: ID1 column (5 chars)
        [void]$sb.Append("ID2           ") # ID2 column (14 chars)
        [void]$sb.Append("Created     ")   # Created date column (12 chars)
        [void]$sb.Append("Due         ")   # Due date column (12 chars)
        [void]$sb.Append("  Title")        # Arrow + title
        [void]$sb.Append([VT]::Reset())
        
        # Separator line
        [void]$sb.Append([VT]::MoveTo(0, 2))
        [void]$sb.Append([AppThemeManager]::GetColor("Header"))
        [void]$sb.Append(" " + ("─" * ($this.Width - 1)))  # SHIFTED RIGHT
        [void]$sb.Append([VT]::Reset())
        
        # Status bar with theme integration and theme picker hotkey
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 1))
        [void]$sb.Append([AppThemeManager]::GetColor("StatusBar"))  # Centralized theme
        $currentTheme = [AppThemeManager]::GetCurrentThemeName()
        $status = "  [N]ew [E]dit [D]elete [F]ilter [T]ags [M]ode [F4]Time [F5]Commands [Ctrl+Shift+T]heme:$currentTheme ESC:Quit "
        [void]$sb.Append($status.PadRight($this.Width))
        [void]$sb.Append([VT]::Reset())
        
        # COMPLETE TASK RENDERING WITH PILLBOX INTEGRATION
        if ($this.FlatList.Count -gt 0) {
            # Calculate visible area
            $startY = 3
            $availableHeight = $this.Height - 5
            $currentY = $startY
            
            # Render each task completely in StringBuilder
            for ($i = $this.ScrollTop; $i -lt $this.FlatList.Count -and ($currentY - $startY) -lt $availableHeight; $i++) {
                $item = $this.FlatList[$i]
                $task = $item.Task
                $level = $item.Level
                $isLast = $item.IsLast
                $isSelected = ($i -eq $this.SelectedIndex)
                
                # Position cursor
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                
                if ($isSelected) {
                    # SELECTED ITEM: Render with pillbox
                    
                    # Top border
                    [void]$sb.Append([AppThemeManager]::GetPillboxColor())
                    [void]$sb.Append("╭" + [StringCache]::GetRepeatedChar('─', $this.Width - 2) + "╮")
                    [void]$sb.Append([VT]::Reset())
                    $currentY++
                    
                    # Content line with borders
                    [void]$sb.Append([VT]::MoveTo(0, $currentY))
                    [void]$sb.Append([AppThemeManager]::GetPillboxColor() + "│")
                    
                    # Get content from FastLineBuilder (without selection highlighting)
                    $contentLine = $this.LineBuilder.BuildContentLine($task, $level, $isLast, $false, $this)
                    # Remove the leading space that FastLineBuilder adds for pillbox
                    if ($contentLine.StartsWith(" ")) {
                        $contentLine = $contentLine.Substring(1)
                    }
                    [void]$sb.Append($contentLine)
                    
                    # Pad to right border using visual length calculation
                    $visualLength = $this.LineBuilder.GetContentLength($task, $level, $this)  # Already excludes leading space
                    $usedWidth = 1 + $visualLength  # 1 for left border
                    $paddingNeeded = $this.Width - $usedWidth - 1  # 1 for right border
                    if ($paddingNeeded -gt 0) {
                        [void]$sb.Append([StringCache]::GetSpaces($paddingNeeded))
                    }
                    [void]$sb.Append([AppThemeManager]::GetPillboxColor() + "│")
                    [void]$sb.Append([VT]::Reset())
                    $currentY++
                    
                    # Tag line with borders
                    [void]$sb.Append([VT]::MoveTo(0, $currentY))
                    [void]$sb.Append([AppThemeManager]::GetPillboxColor() + "│")
                    
                    # Get tag line from FastLineBuilder
                    $tagLine = $this.LineBuilder.BuildTagLine($task, $level, $isLast, $false, $this)
                    # Remove the leading space that FastLineBuilder adds for pillbox
                    if ($tagLine.StartsWith(" ")) {
                        $tagLine = $tagLine.Substring(1)
                    }
                    [void]$sb.Append($tagLine)
                    
                    # Pad to right border - strip VT100 codes for accurate length
                    $tagVisualLength = ($tagLine -replace '\e\[[0-9;]*m', '').Length
                    $usedWidth = 1 + $tagVisualLength  # 1 for left border
                    $paddingNeeded = $this.Width - $usedWidth - 1  # 1 for right border
                    if ($paddingNeeded -gt 0) {
                        [void]$sb.Append([StringCache]::GetSpaces($paddingNeeded))
                    }
                    [void]$sb.Append([AppThemeManager]::GetPillboxColor() + "│")
                    [void]$sb.Append([VT]::Reset())
                    $currentY++
                    
                    # Bottom border
                    [void]$sb.Append([VT]::MoveTo(0, $currentY))
                    [void]$sb.Append([AppThemeManager]::GetPillboxColor())
                    [void]$sb.Append("╰" + [StringCache]::GetRepeatedChar('─', $this.Width - 2) + "╯")
                    [void]$sb.Append([VT]::Reset())
                    $currentY++
                    
                } else {
                    # NORMAL ITEM: Render without pillbox
                    
                    # Content line
                    $contentLine = $this.LineBuilder.BuildContentLine($task, $level, $isLast, $false, $this)
                    [void]$sb.Append($contentLine)
                    $currentY++
                    
                    # Tag line
                    [void]$sb.Append([VT]::MoveTo(0, $currentY))
                    $tagLine = $this.LineBuilder.BuildTagLine($task, $level, $isLast, $false, $this)
                    [void]$sb.Append($tagLine)
                    $currentY++
                }
            }
            
            # Clear remaining lines
            while ($currentY -lt ($this.Height - 2)) {
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append([VT]::ClearLine())
                $currentY++
            }
            
            $this.PreviousSelectedIndex = $this.SelectedIndex
            
        } else {
            # No tasks message using StringBuilder approach
            [void]$sb.Append([VT]::MoveTo(2, 5))
            [void]$sb.Append([AppThemeManager]::GetColor("Muted"))
            [void]$sb.Append("No tasks match the current filter.")
            [void]$sb.Append([VT]::Reset())
        }
        
        # Cursor management integrated with StringBuilder
        if ($this.EditingItem -ne $null) {
            [void]$sb.Append([VT]::ShowCursor())
            [void]$sb.Append("`e]12;#FF0000`e\")  # Red cursor for visibility
            # Position cursor using enhanced positioning
            $this.PositionEnhancedEditingCursor($sb)
        } else {
            [void]$sb.Append([VT]::HideCursor())
            [void]$sb.Append("`e]12;#FFFFFF`e\")  # Reset cursor color
        }
        
        # Return complete screen - single StringBuilder output eliminates dual output conflicts
        return $sb.ToString()
    }
    
    # Theme cycling - replaces animation toggles
    [void] CycleTheme() {
        $newTheme = [AppThemeManager]::CycleTheme()
        # Theme change affects entire application immediately
        Write-Host "Switched to theme: $newTheme" -ForegroundColor Green
    }
    
    # Helper to update selected index with animation tracking
    [void] SetSelectedIndex([int]$newIndex) {
        $this.PreviousSelectedIndex = $this.SelectedIndex
        $this.SelectedIndex = $newIndex
    }
    
    # TIME ENTRY RENDERING (EXACT COPY OF TIMETRACKER FUNCTIONALITY)
    [string] RenderTimeEntryMode() {
        try {
            "DEBUG: Starting RenderTimeEntryMode... $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            $sb = [System.Text.StringBuilder]::new()
            
            # Clear screen
            [void]$sb.Append([VT]::Clear())
        
        # Header
        [void]$sb.Append([VT]::MoveTo(0, 0))
        [void]$sb.Append([AppThemeManager]::GetColor("Header"))
        [void]$sb.Append(" TASKPRO - TIME ENTRY".PadRight($this.Width))
        [void]$sb.Append([VT]::Reset())
        
        # Week display
        [void]$sb.Append([VT]::MoveTo(0, 1))
        [void]$sb.Append([AppThemeManager]::GetColor("Header"))
        $weekText = $this.TimeService.GetWeekDisplayString()
        if ($this.TimeService.IsCurrentWeek()) {
            $weekText += " (Current Week)"
        }
        [void]$sb.Append(" " + $weekText.PadRight($this.Width - 1))
        [void]$sb.Append([VT]::Reset())
        
        # Column headers
        [void]$sb.Append([VT]::MoveTo(0, 2))
        [void]$sb.Append([AppThemeManager]::GetColor("Header"))
        
        $currentDay = $this.GetCurrentDayOfWeek()
        $monHeader = if ($currentDay -eq "monday") { "▸Mon" } else { "Mon" }
        $tueHeader = if ($currentDay -eq "tuesday") { "▸Tue" } else { "Tue" }
        $wedHeader = if ($currentDay -eq "wednesday") { "▸Wed" } else { "Wed" }
        $thuHeader = if ($currentDay -eq "thursday") { "▸Thu" } else { "Thu" }
        $friHeader = if ($currentDay -eq "friday") { "▸Fri" } else { "Fri" }
        
        [void]$sb.Append(" Name".PadRight($this.NameCol))
        [void]$sb.Append("ID1".PadRight($this.ID1Col))
        [void]$sb.Append("ID2".PadRight($this.ID2Col))
        [void]$sb.Append($monHeader.PadRight($this.MonCol))
        [void]$sb.Append($tueHeader.PadRight($this.TueCol))
        [void]$sb.Append($wedHeader.PadRight($this.WedCol))
        [void]$sb.Append($thuHeader.PadRight($this.ThuCol))
        [void]$sb.Append($friHeader.PadRight($this.FriCol))
        [void]$sb.Append("Total".PadRight($this.Width - ($this.NameCol + $this.ID1Col + $this.ID2Col + $this.MonCol + $this.TueCol + $this.WedCol + $this.ThuCol + $this.FriCol)))
        [void]$sb.Append([VT]::Reset())
        
        [void]$sb.Append([VT]::MoveTo(0, 3))
        [void]$sb.Append([AppThemeManager]::GetColor("Header"))
        [void]$sb.Append(" " + [StringCache]::GetRepeatedChar('─', $this.Width - 1))
        [void]$sb.Append([VT]::Reset())
        
        # Time entry list
        $this.RenderTimeList($sb)
        
        # Status bar
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 2))
        [void]$sb.Append([AppThemeManager]::GetColor("StatusBar"))
        [void]$sb.Append(" " + [StringCache]::GetRepeatedChar('─', $this.Width - 1))
        [void]$sb.Append([VT]::Reset())
        
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 1))
        [void]$sb.Append([AppThemeManager]::GetColor("StatusBar"))
        [void]$sb.Append("  ↑↓:Navigate  E:Edit  A:Add  D:Delete  C:Current Week  ←→:Week Nav  F4:Tasks".PadRight($this.Width))
        [void]$sb.Append([VT]::Reset())
        
        [void]$sb.Append([VT]::HideCursor())
        
            "DEBUG: RenderTimeEntryMode completed successfully $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            return $sb.ToString()
        } catch {
            "ERROR in RenderTimeEntryMode: $_ $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            "Stack trace: $($_.ScriptStackTrace)" | Out-File -FilePath "./debug-timeentry.log" -Append
            # Return safe fallback
            return "[VT]::Clear() + ""Time Entry Error - Check debug-timeentry.log"""
        }
    }
    
    [string] GetCurrentDayOfWeek() {
        $today = [DateTime]::Today.DayOfWeek
        $isCurrentWeek = $this.TimeService.IsCurrentWeek()
        
        if (-not $isCurrentWeek) {
            return ""
        }
        
        switch ($today) {
            ([DayOfWeek]::Monday) { return "monday" }
            ([DayOfWeek]::Tuesday) { return "tuesday" }
            ([DayOfWeek]::Wednesday) { return "wednesday" }
            ([DayOfWeek]::Thursday) { return "thursday" }
            ([DayOfWeek]::Friday) { return "friday" }
        }
        return ""
    }
    
    [void] RenderTimeList([System.Text.StringBuilder]$sb) {
        try {
            "DEBUG: Starting RenderTimeList, TimeFlatList.Count = $($this.TimeFlatList.Count) $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            $startY = 4
            $currentY = $startY
            $availableHeight = $this.Height - 6  # Header + status bar
        
        # Calculate how many items we can show with dynamic heights
        $visibleItems = @()
        $totalHeight = 0
        
        for ($i = $this.TimeScrollTop; $i -lt $this.TimeFlatList.Count; $i++) {
            $itemHeight = $this.GetTimeItemHeight($i)
            if ($totalHeight + $itemHeight -le $availableHeight) {
                $visibleItems += $i
                $totalHeight += $itemHeight
            } else {
                break
            }
        }
        
        
        # Check if we have any time entries to display
        if ($this.TimeFlatList.Count -eq 0) {
            # No time entries message
            [void]$sb.Append([VT]::MoveTo(2, $startY + 2))
            [void]$sb.Append([AppThemeManager]::GetColor("Muted"))
            [void]$sb.Append("No time entries for this week. Press 'N' to add a new entry.")
            [void]$sb.Append([VT]::Reset())
            return
        }
        
        # Render time entries using calculated visible items
        for ($i = $this.TimeScrollTop; $i -lt $this.TimeFlatList.Count -and $currentY -lt ($this.Height - 2); $i++) {
            $item = $this.TimeFlatList[$i]
            $entry = $item.Entry
            $isSelected = ($i -eq $this.TimeSelectedIndex)
            
            # Skip if entry is null
            if (-not $entry) { continue }
            
            # Render the time entry row
            if ($isSelected) {
                # Render pillbox for selected item (4 lines: spacer + top + content + bottom)
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append("")  # Empty spacer line
                $currentY++
                
                # Top border
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append([AppThemeManager]::GetPillboxColor())
                [void]$sb.Append("╭" + [StringCache]::GetRepeatedChar('─', $this.Width - 2) + "╮")
                [void]$sb.Append([VT]::Reset())
                $currentY++
                
                # Content line with borders
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append([AppThemeManager]::GetPillboxColor() + "│")
                
                # Render content and pad to fit pillbox width
                $this.RenderTimeContent($sb, $entry, $isSelected)
                
                # Calculate actual content width (sum of all column widths)
                $totalContentWidth = $this.NameCol + $this.ID1Col + $this.ID2Col + $this.MonCol + $this.TueCol + $this.WedCol + $this.ThuCol + $this.FriCol + $this.TotalCol
                $availableWidth = $this.Width - 2  # Account for left and right borders
                $paddingNeeded = $availableWidth - $totalContentWidth
                if ($paddingNeeded -gt 0) {
                    [void]$sb.Append(" " * $paddingNeeded)
                }
                
                [void]$sb.Append([AppThemeManager]::GetPillboxColor() + "│")
                [void]$sb.Append([VT]::Reset())
                $currentY++
                
                # Bottom border
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append([AppThemeManager]::GetPillboxColor())
                [void]$sb.Append("╰" + [StringCache]::GetRepeatedChar('─', $this.Width - 2) + "╯")
                [void]$sb.Append([VT]::Reset())
                $currentY++
            } else {
                # Normal row rendering
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                $this.RenderTimeContent($sb, $entry, $isSelected)
                $currentY++
                
                # Add space between rows
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append("")
                $currentY++
            }
        }
        
            # Clear remaining lines
            while ($currentY -lt ($this.Height - 2)) {
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append([VT]::ClearLine())
                $currentY++
            }
            "DEBUG: RenderTimeList completed successfully $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        } catch {
            "ERROR in RenderTimeList: $_ $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            "Stack trace: $($_.ScriptStackTrace)" | Out-File -FilePath "./debug-timeentry.log" -Append
        }
    }
    
    [int] GetTimeItemHeight([int]$itemIndex) {
        # Selected item gets pillbox (4 lines: spacer + top + content + bottom)
        # Normal item gets 2 lines (1 content + 1 spacing)
        if ($itemIndex -eq $this.TimeSelectedIndex) {
            return 4
        } else {
            return 2
        }
    }
    
    [int] CalculateTimePillboxWidth([SimpleTimeEntry]$entry) {
        # Calculate minimum width needed for content
        $contentLength = $this.NameCol + $this.ID1Col + $this.ID2Col + $this.MonCol + $this.TueCol + $this.WedCol + $this.ThuCol + $this.FriCol + $this.TotalCol
        $pillboxWidth = $contentLength + 3  # "│" + content + "│"
        
        # Ensure minimum width and don't exceed screen
        $minWidth = 60
        $maxWidth = $this.Width - 4
        
        return [Math]::Min($maxWidth, [Math]::Max($minWidth, $pillboxWidth))
    }
    
    [void] RenderTimeContent([System.Text.StringBuilder]$sb, [SimpleTimeEntry]$entry, [bool]$isSelected) {
        $isEditingThis = $false  # Time editing now handled by separate TimeEntryScreen
        
        # NAME column (task name or description)
        $task = if ($entry.ProjectCode) { $this.TaskLookup[$entry.ProjectCode] } else { $null }
        $nameDisplay = if ($task) { $task.Title } else { $entry.Description }
        if (-not $nameDisplay) { $nameDisplay = "" }
        
        # Time editing now handled by separate TimeEntryScreen
        {
            $truncatedName = if ($nameDisplay.Length -gt ($this.NameCol - 1)) { 
                $nameDisplay.Substring(0, $this.NameCol - 1) 
            } else { 
                $nameDisplay 
            }
            [void]$sb.Append([AppThemeManager]::GetColor("Value") + $truncatedName.PadRight($this.NameCol) + [VT]::Reset())
        }
        
        # ID1 column (project code or time code)
        if ($entry.IsProject()) {
            # For projects, use the task's ID1 if available, otherwise use the entry's ID1Display
            $id1Display = if ($task -and $task.ID1) { $task.ID1 } else { $entry.ID1Display }
        } elseif ($entry.IsTimeCode()) {
            $id1Display = $entry.ID1Display
        } else {
            $id1Display = "-"
        }
        if (-not $id1Display) { $id1Display = "-" }
        
        if ($isEditingThis -and $this.TimeEditingField -eq "id1") {
            [void]$sb.Append([AppThemeManager]::GetColor("EditHighlight") + $this.TimeEditingValue.PadRight($this.ID1Col) + [VT]::Reset())
        } else {
            $color = if ($entry.IsTimeCode()) { [AppThemeManager]::GetColor("Field") } else { [AppThemeManager]::GetColor("Value") }
            [void]$sb.Append($color + $id1Display.PadRight($this.ID1Col) + [VT]::Reset())
        }
        
        # ID2 column (project ID2 or empty for time codes)
        $id2Display = if ($entry.IsProject()) { $entry.ProjectCode } else { "-" }
        if (-not $id2Display) { $id2Display = "-" }
        
        if ($isEditingThis -and $this.TimeEditingField -eq "id2") {
            [void]$sb.Append([AppThemeManager]::GetColor("EditHighlight") + $this.TimeEditingValue.PadRight($this.ID2Col) + [VT]::Reset())
        } else {
            $color = if ($entry.IsTimeCode()) { [AppThemeManager]::GetColor("Field") } else { [AppThemeManager]::GetColor("Value") }
            [void]$sb.Append($color + $id2Display.PadRight($this.ID2Col) + [VT]::Reset())
        }
        
        # DAY HOURS columns
        $this.RenderTimeDayColumn($sb, $entry, "monday", $entry.Monday, $this.MonCol, $isEditingThis)
        $this.RenderTimeDayColumn($sb, $entry, "tuesday", $entry.Tuesday, $this.TueCol, $isEditingThis)
        $this.RenderTimeDayColumn($sb, $entry, "wednesday", $entry.Wednesday, $this.WedCol, $isEditingThis)
        $this.RenderTimeDayColumn($sb, $entry, "thursday", $entry.Thursday, $this.ThuCol, $isEditingThis)
        $this.RenderTimeDayColumn($sb, $entry, "friday", $entry.Friday, $this.FriCol, $isEditingThis)
        
        # TOTAL column
        $totalText = if ($entry.Total -gt 0) { $entry.Total.ToString("F1") } else { "" }
        [void]$sb.Append([AppThemeManager]::GetColor("High") + $totalText.PadRight($this.TotalCol) + [VT]::Reset())
        
        # Clear to end handled by caller
    }
    
    [void] RenderTimeDayColumn([System.Text.StringBuilder]$sb, [SimpleTimeEntry]$entry, [string]$dayName, [decimal]$hours, [int]$colWidth, [bool]$isEditingThis) {
        $currentDay = $this.GetCurrentDayOfWeek()
        $isCurrentDay = ($dayName -eq $currentDay)
        
        if ($isEditingThis -and $this.TimeEditingField -eq $dayName) {
            [void]$sb.Append([AppThemeManager]::GetColor("EditHighlight") + $this.TimeEditingValue.PadRight($colWidth) + [VT]::Reset())
        } else {
            $hoursText = if ($hours -gt 0) { $hours.ToString("F1") } else { "" }
            if ($isCurrentDay) {
                $color = [AppThemeManager]::GetColor("CurrentDay")
            } else {
                $color = [AppThemeManager]::GetColor("Muted")
            }
            [void]$sb.Append($color + $hoursText.PadRight($colWidth) + [VT]::Reset())
        }
    }
    
    [void] PositionTimeEntryCursor([System.Text.StringBuilder]$sb) {
        if ($this.TimeEditingIndex -lt 0) { return }
        
        # Calculate the Y position of the editing item (in pillbox)
        $startY = 4
        $currentY = $startY
        $foundY = -1
        
        for ($i = $this.TimeScrollTop; $i -lt $this.TimeFlatList.Count; $i++) {
            $itemHeight = $this.GetTimeItemHeight($i)
            if ($i -eq $this.TimeEditingIndex) {
                # Found our editing item - content line is 2nd line of pillbox
                $foundY = $currentY + 2
                break
            }
            $currentY += $itemHeight
            if ($currentY -ge ($this.Height - 6)) { break }
        }
        
        if ($foundY -ge 0) {
            # Calculate X position based on field being edited
            $x = 1  # Start after the left border "│"
            
            switch ($this.TimeEditingField) {
                "name" { $x += $this.TimeEditingValue.Length }
                "id1" { $x += $this.NameCol + $this.TimeEditingValue.Length }
                "id2" { $x += $this.NameCol + $this.ID1Col + $this.TimeEditingValue.Length }
                "monday" { $x += $this.NameCol + $this.ID1Col + $this.ID2Col + $this.TimeEditingValue.Length }
                "tuesday" { $x += $this.NameCol + $this.ID1Col + $this.ID2Col + $this.MonCol + $this.TimeEditingValue.Length }
                "wednesday" { $x += $this.NameCol + $this.ID1Col + $this.ID2Col + $this.MonCol + $this.TueCol + $this.TimeEditingValue.Length }
                "thursday" { $x += $this.NameCol + $this.ID1Col + $this.ID2Col + $this.MonCol + $this.TueCol + $this.WedCol + $this.TimeEditingValue.Length }
                "friday" { $x += $this.NameCol + $this.ID1Col + $this.ID2Col + $this.MonCol + $this.TueCol + $this.WedCol + $this.ThuCol + $this.TimeEditingValue.Length }
            }
            
            [void]$sb.Append([VT]::MoveTo($x, $foundY))
        }
    }
    
    [void] RenderTaskList([System.Text.StringBuilder]$sb) {
        $startY = 3
        $currentY = $startY
        $availableHeight = $this.Height - 5  # Header + status bar
        
        # Calculate how many items we can show with dynamic heights
        $visibleItems = @()
        $totalHeight = 0
        
        for ($i = $this.ScrollTop; $i -lt $this.FlatList.Count; $i++) {
            $itemHeight = $this.GetItemHeight($i)
            if ($totalHeight + $itemHeight -le $availableHeight) {
                $visibleItems += $i
                $totalHeight += $itemHeight
            } else {
                break
            }
        }
        
        # Render each visible item
        foreach ($i in $visibleItems) {
            $item = $this.FlatList[$i]
            $task = $item.Task
            $level = $item.Level
            $isLast = $item.IsLast
            $isSelected = ($i -eq $this.SelectedIndex)
            
            if ($isSelected) {
                # === SELECTED ITEM WITH PILLBOX ===
                
                # Use full screen width for pillbox - much simpler!
                $pillboxWidth = $this.Width
                
                # CRITICAL: Calculate the fixed right border position for BOTH lines  
                $rightBorderColumn = $this.Width - 1  # Right border inside screen bounds
                
                # Spacer line above with tree connectors
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                # For selected items (pillbox), use same spacing logic as normal items
                $this.RenderTreeSpacingLine($sb, $i)
                $currentY++
                
                # Pillbox top
                $this.RenderPillboxTop($sb, $pillboxWidth, $currentY)
                $currentY++
                
                # Content line 1 with pillbox sides
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append([AppThemeManager]::GetColor("Header") + $this.PillboxVertical + [VT]::Reset())
                $this.RenderTaskContent($sb, $task, $level, $isLast, $false, $isSelected)
                
                # Move cursor to EXACT right border position
                [void]$sb.Append([VT]::MoveTo($rightBorderColumn, $currentY))
                [void]$sb.Append([AppThemeManager]::GetColor("Header") + $this.PillboxVertical + [VT]::Reset())
                $currentY++
                
                # Content line 2 (tags) with pillbox sides
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append([AppThemeManager]::GetColor("Header") + $this.PillboxVertical + [VT]::Reset())
                
                # Render tag content
                $isEditingThis = ($this.EditingItem -and $this.EditingItem.Task.Id -eq $task.Id)
                if ($isEditingThis -and $this.EditingField -eq "tags") {
                    # Show active tags field with reverse video highlighting
                    $indentSize = $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
                    if ($level -eq 1) {
                        $indentSize += 7  # "    └─ "
                    }
                    [void]$sb.Append(" " * $indentSize)
                    $existingTags = ($task.Tags -join ", ")
                    $minWidth = 15
                    $fieldWidth = [Math]::Max($minWidth, [Math]::Max($this.EditingValue.Length + 2, $existingTags.Length + 2))
                    $displayValue = if ($this.EditingValue -ne "") { $this.EditingValue.PadRight($fieldWidth) } else { " ".PadRight($fieldWidth) }
                    [void]$sb.Append("⟨" + "`e[7m" + $displayValue + "`e[0m" + "⟩")  # Reverse video
                } elseif ($isEditingThis -and $task.Tags.Count -gt 0) {
                    # Show inactive tags field with dim highlight when editing other fields
                    $indentSize = $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
                    if ($level -eq 1) {
                        $indentSize += 7  # "    └─ "
                    }
                    [void]$sb.Append(" " * $indentSize)
                    $tagsText = ($task.Tags -join ", ")
                    $minWidth = 15
                    $fieldWidth = [Math]::Max($minWidth, $tagsText.Length + 2)
                    $fieldValue = $tagsText.PadRight($fieldWidth)
                    [void]$sb.Append("⟨" + "`e[48;2;30;30;40m" + $fieldValue + "`e[0m" + "⟩")  # Dim highlight
                } elseif ($task.Tags.Count -gt 0) {
                    # Normal tag display
                    $indentSize = $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
                    if ($level -eq 1) {
                        $indentSize += 7  # "    └─ "
                    }
                    [void]$sb.Append(" " * $indentSize)
                    [void]$sb.Append([AppThemeManager]::GetColor("Muted") + "⟨" + ($task.Tags -join ", ") + "⟩" + [VT]::Reset())
                } elseif ($isEditingThis -and $this.EditingField -eq "tags") {
                    # Show active empty tags field when editing tags
                    $indentSize = $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
                    if ($level -eq 1) {
                        $indentSize += 7  # "    └─ "
                    }
                    [void]$sb.Append(" " * $indentSize)
                    $minWidth = 15
                    $fieldWidth = [Math]::Max($minWidth, $this.EditingValue.Length + 5)
                    $fieldValue = $this.EditingValue.PadRight($fieldWidth)
                    [void]$sb.Append("⟨" + $this.EditHighlight + $fieldValue + [VT]::Reset() + "⟩")
                } elseif ($isEditingThis) {
                    # Show empty tags field with dim highlight when editing other fields
                    $indentSize = $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
                    if ($level -eq 1) {
                        $indentSize += 7  # "    └─ "
                    }
                    [void]$sb.Append(" " * $indentSize)
                    $minWidth = 15
                    $fieldValue = " ".PadRight($minWidth)
                    [void]$sb.Append("⟨" + "`e[48;2;30;30;40m" + $fieldValue + "`e[0m" + "⟩")  # Dim highlight
                }
                
                # Move cursor to EXACT same right border position
                [void]$sb.Append([VT]::MoveTo($rightBorderColumn, $currentY))
                [void]$sb.Append([AppThemeManager]::GetColor("Header") + $this.PillboxVertical + [VT]::Reset())
                $currentY++
                
                # Pillbox bottom
                $this.RenderPillboxBottom($sb, $pillboxWidth, $currentY)
                $currentY++
                
            } else {
                # === NORMAL ITEM (2 lines) ===
                
                # Content line 1
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                $this.RenderTaskContent($sb, $task, $level, $isLast, $true, $isSelected)
                $currentY++
                
                # Content line 2 (tags)
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                $this.RenderTagContent($sb, $task, $level, $isLast, $isSelected)
                [void]$sb.Append([VT]::ClearLine())
                $currentY++
            }
        }
        
        # Clear remaining lines properly
        while ($currentY -lt ($this.Height - 2)) {
            [void]$sb.Append([VT]::MoveTo(0, $currentY))
            [void]$sb.Append([VT]::ClearLine())
            $currentY++
        }
    }
    
    # Enhanced task rendering that integrates with original pillbox system
    [void] RenderEnhancedTaskList([System.Text.StringBuilder]$sb) {
        $startY = 3
        $currentY = $startY
        $availableHeight = $this.Height - 5  # Header + status bar
        
        # Calculate visible items the same way as original
        $visibleItems = @()
        $totalHeight = 0
        
        for ($i = $this.ScrollTop; $i -lt $this.FlatList.Count; $i++) {
            $itemHeight = $this.GetItemHeight($i)
            if ($totalHeight + $itemHeight -le $availableHeight) {
                $visibleItems += $i
                $totalHeight += $itemHeight
            } else {
                break
            }
        }
        
        # Render each visible item with enhanced components but original pillbox logic
        foreach ($i in $visibleItems) {
            $item = $this.FlatList[$i]
            $task = $item.Task
            $level = $item.Level
            $isLast = $item.IsLast
            $isSelected = ($i -eq $this.SelectedIndex)
            
            if ($isSelected) {
                # === SELECTED ITEM WITH PILLBOX - full screen width accounting for borders ===
                $pillboxWidth = $this.Width
                
                # Spacer line above with tree connectors
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                $this.RenderTreeSpacingLine($sb, $i)
                $currentY++
                
                # Pillbox top
                $this.RenderPillboxTop($sb, $pillboxWidth, $currentY)
                $currentY++
                
                # Content line 1 with pillbox sides - FastLineBuilder handles pillbox indentation
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append([AppThemeManager]::GetColor("Header") + $this.PillboxVertical + [VT]::Reset())
                $contentLine = $this.LineBuilder.BuildContentLine($task, $level, $isLast, $isSelected, $this)
                [void]$sb.Append($contentLine)
                # Right border positioned to leave space for content + left border
                [void]$sb.Append([VT]::MoveTo($this.Width - 1, $currentY))
                [void]$sb.Append([AppThemeManager]::GetColor("Header") + $this.PillboxVertical + [VT]::Reset())
                $currentY++
                
                # Content line 2 (tags) with pillbox sides - FastLineBuilder handles pillbox indentation
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append([AppThemeManager]::GetColor("Header") + $this.PillboxVertical + [VT]::Reset())
                $tagLine = $this.LineBuilder.BuildTagLine($task, $level, $isLast, $isSelected, $this)
                [void]$sb.Append($tagLine)
                # Right border positioned to leave space for content + left border
                [void]$sb.Append([VT]::MoveTo($this.Width - 1, $currentY))
                [void]$sb.Append([AppThemeManager]::GetColor("Header") + $this.PillboxVertical + [VT]::Reset())
                $currentY++
                
                # Pillbox bottom
                $this.RenderPillboxBottom($sb, $pillboxWidth, $currentY)
                $currentY++
            } else {
                # === NORMAL ITEM (non-selected) ===
                # Content line 1 - use enhanced line builder with screen reference
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                $contentLine = $this.LineBuilder.BuildContentLine($task, $level, $isLast, $isSelected, $this)
                [void]$sb.Append($contentLine)
                $currentY++
                
                # Content line 2 (tags) - use enhanced line builder with screen reference
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                $tagLine = $this.LineBuilder.BuildTagLine($task, $level, $isLast, $isSelected, $this)
                [void]$sb.Append($tagLine)
                $currentY++
            }
        }
        
        # Clear remaining lines properly (same as original)
        while ($currentY -lt ($this.Height - 2)) {
            [void]$sb.Append([VT]::MoveTo(0, $currentY))
            [void]$sb.Append([VT]::ClearLine())
            $currentY++
        }
    }
    
    # Enhanced cursor positioning for editing using FastLineBuilder - updated for unified rendering
    [void] PositionEnhancedEditingCursor([System.Text.StringBuilder]$sb) {
        "DEBUG: PositionEnhancedEditingCursor called - EditingItem: $($this.EditingItem -ne $null), EditingField: '$($this.EditingField)' $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        if ($this.EditingItem -eq $null) { return }
        
        # Find the editing item in the FlatList
        $editingIndex = -1
        for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
            if ($this.FlatList[$i].Task.Id -eq $this.EditingItem.Task.Id) {
                $editingIndex = $i
                break
            }
        }
        if ($editingIndex -lt 0) { return }
        
        $item = $this.FlatList[$editingIndex]
        $task = $item.Task
        $level = $item.Level
        
        # Calculate cursor position based on unified rendering layout
        $startY = 3  # Start Y for task list
        $currentY = $startY
        
        # Count items before the editing item to find Y position
        for ($i = $this.ScrollTop; $i -lt $editingIndex -and $i -lt $this.FlatList.Count; $i++) {
            if ($i -eq $this.SelectedIndex) {
                # Selected item with pillbox: 4 lines (top + content + tags + bottom)
                $currentY += 4
            } else {
                # Normal item: 2 lines (content + tags)
                $currentY += 2
            }
        }
        
        # If we're editing the selected item, cursor is inside the pillbox
        if ($editingIndex -eq $this.SelectedIndex) {
            # FastLineBuilder expects startY to be the content line position
            # Content line is at $currentY + 1 (after top border)
            $contentLineY = $currentY + 1
            
            # Use the new GetFieldScreenPosition method
            $position = $this.GetFieldScreenPosition($this.EditingField, $this.EditingCursor, $this.EditingItem)
            $cursorX = $position.X
            $cursorY = $position.Y
            
            "DEBUG: GetFieldScreenPosition returned - field='$($this.EditingField)', cursorX=$cursorX, cursorY=$cursorY $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            [void]$sb.Append([VT]::MoveTo($cursorX, $cursorY))
        } else {
            # Editing non-selected item (shouldn't happen but handle gracefully)
            $cursorPos = $this.LineBuilder.GetEditingCursorPosition($task, $level, $this.EditingField, $this.EditingCursor, $currentY)
            [void]$sb.Append([VT]::MoveTo($cursorPos.X, $cursorPos.Y))
        }
    }
    
    [void] RenderTreeSpacingLine([System.Text.StringBuilder]$sb, [int]$itemIndex) {
        if ($itemIndex -ge $this.FlatList.Count) { return }
        
        $item = $this.FlatList[$itemIndex]
        $level = $item.Level
        
        if ($level -eq 1) {
            # For subtasks, show the tree connector on spacing line
            $isLast = $item.IsLast
            if ($isLast) {
                [void]$sb.Append("    └─ ")
            } else {
                [void]$sb.Append("    ├─ ")
            }
        } else {
            # For parent tasks, show continuation if they have subtasks
            $task = $item.Task
            if ($task.Subtasks.Count -gt 0) {
                [void]$sb.Append("    │  ")
            }
        }
        [void]$sb.Append([VT]::ClearLine())
    }
    
    [void] RenderTaskContent([System.Text.StringBuilder]$sb, [SimpleTask]$task, [int]$level, [bool]$isLast, [bool]$clearToEnd, [bool]$isSelected = $false) {
        $isEditingThis = ($this.EditingItem -and $this.EditingItem.Task.Id -eq $task.Id)
        
        # COLUMN 1: ID1 (4 chars) - Project code
        if ($level -eq 0) {
            # Parent task - show ID1
            if ($isEditingThis -and $this.EditingField -eq "id1") {
                $fieldValue = $this.EditingValue.PadRight(3)
                [void]$sb.Append($this.EditHighlight + $fieldValue + " " + [VT]::Reset())
            } else {
                $id1Text = if ($task.ID1 -and $task.ID1 -ne "") { $task.ID1.PadRight(3) } else { "   " }
                [void]$sb.Append([AppThemeManager]::GetColor("Field") + $id1Text + "  " + [VT]::Reset())
            }
        } else {
            # Subtasks show completion status
            if ($task.Completed) {
                [void]$sb.Append("■    ")  # Filled square for completed + spaces
            } else {
                [void]$sb.Append("☐    ")  # Open square for incomplete + spaces
            }
        }
        
        # COLUMN 2: ID2 (13 chars) - Project identifier
        if ($level -eq 0) {
            # Parent task - show ID2
            if ($isEditingThis -and $this.EditingField -eq "id2") {
                $fieldValue = $this.EditingValue.PadRight(12)
                [void]$sb.Append($this.EditHighlight + $fieldValue + " " + [VT]::Reset())
            } else {
                $id2Text = if ($task.ID2 -and $task.ID2 -ne "") { $task.ID2.PadRight(12) } else { " ".PadRight(12) }
                [void]$sb.Append([AppThemeManager]::GetColor("Value") + $id2Text + "  " + [VT]::Reset())
            }
        } else {
            # Subtasks show priority after tree chars
            $priorityText = switch ($task.Priority) {
                "High" { "H" }
                "Medium" { "M" }
                "Low" { "L" }
                "Today" { "T" }
                default { " " }
            }
            $priorityColor = switch ($task.Priority) {
                "High" { [AppThemeManager]::GetColor("High") }
                "Medium" { [AppThemeManager]::GetColor("Medium") }
                "Low" { [AppThemeManager]::GetColor("Low") }
                "Today" { [AppThemeManager]::GetColor("Today") }
                default { [AppThemeManager]::GetColor("Muted") }
            }
            [void]$sb.Append($priorityColor + $priorityText + [VT]::Reset() + " ".PadRight(13))
        }
        
        # COLUMN 3: CREATED DATE (12 chars)
        if ($level -eq 0) {
            # Parent task - show created date
            if ($isEditingThis -and $this.EditingField -eq "created") {
                $displayValue = if ($this.EditingValue -ne "") { $this.EditingValue.PadRight(10) } else { " ".PadRight(10) }
                [void]$sb.Append($this.EditHighlight + $displayValue + "  " + [VT]::Reset())
            } else {
                $createdText = if ($task.CreatedDate -eq [datetime]::MinValue) { " ".PadRight(10) } else { $task.CreatedDate.ToString("yyyy-MM-dd") }
                [void]$sb.Append([AppThemeManager]::GetColor("Browser") + $createdText + "  " + [VT]::Reset())
            }
        } else {
            # Subtasks show created date too but smaller
            $createdText = if ($task.CreatedDate -eq [datetime]::MinValue) { " ".PadRight(10) } else { $task.CreatedDate.ToString("yyyy-MM-dd") }
            [void]$sb.Append([AppThemeManager]::GetColor("Muted") + $createdText + "  " + [VT]::Reset())
        }
        
        # COLUMN 4: DUE DATE (12 chars)
        if ($level -eq 0) {
            # Parent task - show due date with color coding
            if ($isEditingThis -and $this.EditingField -eq "date") {
                $displayValue = if ($this.EditingValue -ne "") { $this.EditingValue.PadRight(10) } else { " ".PadRight(10) }
                [void]$sb.Append($this.EditHighlight + $displayValue + "  " + [VT]::Reset())
            } else {
                [void]$sb.Append($this.GetDateColorAndTextFormatted($task))
                [void]$sb.Append("  ")
            }
        } else {
            # Subtasks show due date if they have one
            if ($task.DueDate -ne [datetime]::MinValue) {
                $dueDateText = $task.DueDate.ToString("yyyy-MM-dd")
                $dateColor = $this.GetDateColor($task.DueDate)
                [void]$sb.Append($dateColor + $dueDateText.PadRight(10) + "  " + [VT]::Reset())
            } else {
                [void]$sb.Append(" ".PadRight(12))
            }
        }

        # COLUMN 5: ARROW (3 chars - closest to task)
        if ($level -eq 0 -and $task.Subtasks.Count -gt 0) {
            if ($this.GlobalCollapseSubtasks -or $task.SubtasksCollapsed) {
                [void]$sb.Append("▶  ")  # Collapsed
            } else {
                [void]$sb.Append("▼  ")  # Expanded
            }
        } else {
            [void]$sb.Append("   ")
        }
        
        # COLUMN 6: TITLE (with indentation for subtasks)
        if ($level -eq 1) {
            # Hide connectors when pillbox is selected on this subtask
            if ($isSelected) {
                [void]$sb.Append("       ")  # Same spacing as connectors but no symbols
            } else {
                if ($isLast) {
                    [void]$sb.Append("    └─ ")
                } else {
                    [void]$sb.Append("    ├─ ")
                }
            }
            
            # Add priority and date right after tree chars for subtasks
            $this.RenderSubtaskPriorityAndDate($sb, $task, $isEditingThis)
        }
        
        # Task title color and content
        if ($isEditingThis -and $this.EditingField -eq "title") {
            # Show active field with reverse video highlighting (expandable)
            $minWidth = 20
            $fieldWidth = [Math]::Max($minWidth, [Math]::Max($this.EditingValue.Length + 2, $task.Title.Length + 2))
            $displayValue = if ($this.EditingValue -ne "") { $this.EditingValue.PadRight($fieldWidth) } else { " ".PadRight($fieldWidth) }
            [void]$sb.Append("`e[7m" + $displayValue + "`e[0m")  # Reverse video
        } elseif ($isEditingThis) {
            # Show inactive field with dim highlight when editing other fields
            $minWidth = 20
            $fieldWidth = [Math]::Max($minWidth, $task.Title.Length + 2)
            $titleValue = $task.Title.PadRight($fieldWidth)
            [void]$sb.Append("`e[48;2;30;30;40m" + $titleValue + "`e[0m")  # Dim highlight
        } else {
            if ($task.Completed) {
                $taskColor = [AppThemeManager]::GetColor("Muted")
            } elseif ($level -eq 1) {
                $parentTask = $this.TaskService.GetParentTask($task.Id)
                if ($parentTask) {
                    $taskColor = $this.GetSubtaskColor($parentTask.SubtaskColorTheme)
                } else {
                    $taskColor = [AppThemeManager]::GetColor("Muted")
                }
            } else {
                $taskColor = $this.GetTaskColor($task.ColorTheme)
            }
            
            [void]$sb.Append($taskColor + $task.Title + [VT]::Reset())
        }
        
        # Clear to end of line if requested
        if ($clearToEnd) {
            $contentLength = $this.GetContentLength($task, $level)
            $padding = $this.Width - $contentLength
            [void]$sb.Append(" " * [Math]::Max(0, $padding))
        }
    }
    
    [void] RenderTagContent([System.Text.StringBuilder]$sb, [SimpleTask]$task, [int]$level, [bool]$isLast = $false, [bool]$isSelected = $false) {
        # For subtasks, ALWAYS show tree continuation lines (unless selected)
        if ($level -eq 1) {
            # Render the tree structure columns first
            [void]$sb.Append("   ")  # Status column spacing
            [void]$sb.Append("     ")  # Priority column spacing
            [void]$sb.Append(" " * $this.DateCol)  # Date column spacing
            [void]$sb.Append("   ")  # Arrow column spacing
            
            # Tree connectors: show proper branch connectors unless this subtask is selected
            if ($isSelected) {
                [void]$sb.Append("       ")  # Same spacing as tree connectors but no symbols
            } else {
                if ($isLast) {
                    [void]$sb.Append("    └─ ")
                } else {
                    [void]$sb.Append("    ├─ ")
                }
            }
        } elseif ($level -eq 0) {
            # For parent tasks with subtasks, show continuation line
            if ($task.Subtasks.Count -gt 0 -and -not $isSelected) {
                [void]$sb.Append("   ")  # Status column spacing
                [void]$sb.Append("     ")  # Priority column spacing
                [void]$sb.Append(" " * $this.DateCol)  # Date column spacing
                [void]$sb.Append("   ")  # Arrow column spacing
                [void]$sb.Append("    │  ")  # Vertical continuation line to subtasks
            }
        }
        
        # Always add proper spacing for level 0 tasks when no tree continuation was added
        if ($level -eq 0 -and (-not ($task.Subtasks.Count -gt 0 -and -not $isSelected))) {
            $indentSize = $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
            [void]$sb.Append(" " * $indentSize)
        }
        
        # Show tags if they exist, otherwise add spaces to preserve line content
        if ($task.Tags.Count -gt 0) {
            [void]$sb.Append([AppThemeManager]::GetColor("Muted"))
            [void]$sb.Append("⟨" + ($task.Tags -join ", ") + "⟩")
            [void]$sb.Append([VT]::Reset())
            # Add spaces to ensure content survives VT clearing
            [void]$sb.Append("     ")
        } else {
            # Add spaces so the line has content that survives VT clearing
            [void]$sb.Append("     ")
        }
    }
    
    [int] GetContentLength([SimpleTask]$task, [int]$level) {
        $length = $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
        if ($level -eq 1) {
            $length += 7  # "    └─ "
        }
        
        # Use editing value if this task is being edited
        $isEditingThis = ($this.EditingItem -and $this.EditingItem.Task.Id -eq $task.Id)
        if ($isEditingThis -and $this.EditingField -eq "title") {
            $length += [Math]::Max($task.Title.Length, $this.EditingValue.Length)
        } else {
            $length += $task.Title.Length
        }
        
        return $length
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # If BaseListScreen is handling editing, let it handle ALL input
        if ($this.EditingItem -ne $null) {
            return ([BaseListScreen]$this).HandleInput($key)
        }
        
        # Otherwise, use our state machine for non-editing modes  
        switch ($this.InputState) {
            ([TaskListInputState]::Browsing) {
                return $this.HandleBrowsingInput($key)
            }
            ([TaskListInputState]::Filtering) {
                return $this.HandleFilterInput($key)
            }
            ([TaskListInputState]::TimeEntry) {
                # Time entry mode now handled by separate TimeEntryScreen
                return $this.HandleBrowsingInput($key)
            }
            default {
                # Fallback to browsing if state is corrupted
                $this.InputState = [TaskListInputState]::Browsing
                return $this.HandleBrowsingInput($key)
            }
        }
        
        # This should never be reached, but PowerShell requires it
        return $false
    }
    
    # State Machine Handler: Browsing mode (main navigation)
    [bool] HandleBrowsingInput([System.ConsoleKeyInfo]$key) {
        # Handle navigation keys using KeyMappingService (support both Chromebook Ctrl+F4 and regular F4)
        "DEBUG: Browsing state - Checking navigation for key $($key.Key) with modifiers $($key.Modifiers) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        if ($this.KeyService.MatchesAction($key, "NavigateToTimeEntry") -or $this.KeyService.MatchesAction($key, "NavigateToTimeEntryAlt")) {
            "DEBUG: TimeEntry navigation key pressed - publishing NavigateTo timeentry $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            [EventBus]::Publish("NavigateTo", "timeentry")
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "NavigateToCommands") -or $this.KeyService.MatchesAction($key, "NavigateToCommandsAlt")) {
            "DEBUG: Commands navigation key pressed - publishing NavigateTo commands $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            [EventBus]::Publish("NavigateTo", "commands")
            return $true
        }
        
        # Handle theme cycling using KeyMappingService
        if ($this.KeyService.MatchesAction($key, "CycleTheme")) {
            $this.CycleTheme()
            return $true
        }
        
        # Handle all browsing input using KeyMappingService
        
        # Navigation actions
        if ($this.KeyService.MatchesAction($key, "MoveTaskUp")) {
            if ($this.FlatList.Count -gt 0) {
                $item = $this.FlatList[$this.SelectedIndex]
                $taskId = $item.Task.Id
                if ($global:Debug) { Write-Host "Moving task up: $taskId" -ForegroundColor Cyan }
                
                $this.TaskService.MoveTaskUp($taskId)
                $this.LoadTasks()
                
                # Find the moved task and select it
                $newIndex = -1
                for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
                    if ($this.FlatList[$i].Task.Id -eq $taskId) {
                        $newIndex = $i
                        break
                    }
                }
                if ($newIndex -ge 0) { $this.SelectedIndex = $newIndex }
                $this.EnsureVisible()
            }
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "MoveTaskDown")) {
            if ($this.FlatList.Count -gt 0) {
                $item = $this.FlatList[$this.SelectedIndex]
                $taskId = $item.Task.Id
                if ($global:Debug) { Write-Host "Moving task down: $taskId" -ForegroundColor Cyan }
                
                $this.TaskService.MoveTaskDown($taskId)
                $this.LoadTasks()
                
                # Find the moved task and select it
                $newIndex = -1
                for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
                    if ($this.FlatList[$i].Task.Id -eq $taskId) {
                        $newIndex = $i
                        break
                    }
                }
                if ($newIndex -ge 0) { $this.SelectedIndex = $newIndex }
                $this.EnsureVisible()
            }
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "MoveUp")) {
            if ($this.SelectedIndex -gt 0) {
                $this.SetSelectedIndex($this.SelectedIndex - 1)
                $this.EnsureVisible()
            }
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "MoveDown")) {
            if ($this.SelectedIndex -lt ($this.FlatList.Count - 1)) {
                $this.SetSelectedIndex($this.SelectedIndex + 1)
                $this.EnsureVisible()
            }
            return $true
        }
        
        # Task management actions
        if ($this.KeyService.MatchesAction($key, "ToggleCollapse")) {
            if ($this.FlatList.Count -gt 0) {
                $item = $this.FlatList[$this.SelectedIndex]
                if ($item.Level -eq 0 -and $item.Task.Subtasks.Count -gt 0) {
                    $item.Task.SubtasksCollapsed = -not $item.Task.SubtasksCollapsed
                    $this.TaskService.UpdateTask($item.Task)
                    $this.LoadTasks()
                }
            }
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "ToggleComplete")) {
            if ($this.FlatList.Count -gt 0) {
                $item = $this.FlatList[$this.SelectedIndex]
                $item.Task.IsCompleted = -not $item.Task.IsCompleted
                $this.TaskService.UpdateTask($item.Task)
                $this.LoadTasks()
            }
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "NewTask")) {
            "DEBUG: NewTask KeyMappingService action triggered $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            $this.StartNewItem()
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "EditTask")) {
            "DEBUG: EditTask KeyMappingService action triggered $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            if ($this.FlatList.Count -gt 0) {
                $item = $this.FlatList[$this.SelectedIndex]
                $fields = $this.GetEditableFields($item)
                if ($fields.Count -gt 0) {
                    "DEBUG: KeyMappingService calling StartEdit with field: $($fields[0]) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                    $this.StartEdit($fields[0])
                }
            }
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "DeleteTask")) {
            "DEBUG: DeleteTask KeyMappingService action triggered $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            if ($this.FlatList.Count -gt 0) {
                $this.DeleteCurrentItem()
            }
            return $true
        }
        
        # Filter actions
        if ($this.KeyService.MatchesAction($key, "ToggleFilter")) {
            $this.StartFilterInput()
            $this.InputState = [TaskListInputState]::Filtering
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "FilterAll")) {
            $this.CurrentFilter = "All"
            $this.LoadTasks()
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "FilterToday")) {
            $this.CurrentFilter = "Today" 
            $this.LoadTasks()
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "FilterHigh")) {
            $this.CurrentFilter = "High"
            $this.LoadTasks()
            return $true
        }
        
        # Exit action
        if ($this.KeyService.MatchesAction($key, "NavigateBack")) {
            return $false  # Exit application
        }
        
        # If no action matched, return false
        return $false
        
        # Handle global theme picker hotkey - Ctrl+Shift+T
        if ($key.Key -eq [System.ConsoleKey]::T -and 
            ($key.Modifiers -band [System.ConsoleModifiers]::Control) -and 
            ($key.Modifiers -band [System.ConsoleModifiers]::Shift)) {
            $this.CycleTheme()
            return $true
        }
        
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                # Check for Ctrl+Up (move task up)
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    if ($this.FlatList.Count -gt 0) {
                        $item = $this.FlatList[$this.SelectedIndex]
                        $taskId = $item.Task.Id
                        if ($global:Debug) { Write-Host "Moving task up: $taskId (current selection: $($this.SelectedIndex))" -ForegroundColor Cyan }
                        
                        $this.TaskService.MoveTaskUp($taskId)
                        $this.LoadTasks()
                        
                        # Find the moved task in the new list and select it
                        $newIndex = -1
                        for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
                            if ($this.FlatList[$i].Task.Id -eq $taskId) {
                                $newIndex = $i
                                break
                            }
                        }
                        
                        if ($newIndex -ge 0) {
                            $this.SelectedIndex = $newIndex
                            if ($global:Debug) { Write-Host "Task found at new index: $newIndex" -ForegroundColor Green }
                        } else {
                            if ($global:Debug) { Write-Host "Warning: Task not found after move, keeping current selection" -ForegroundColor Red }
                            # Ensure we don't go out of bounds
                            if ($this.SelectedIndex -ge $this.FlatList.Count) {
                                $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
                            }
                        }
                        $this.EnsureVisible()
                    }
                } else {
                    # Normal navigation
                    if ($this.SelectedIndex -gt 0) {
                        $this.SetSelectedIndex($this.SelectedIndex - 1)
                        $this.EnsureVisible()
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                # Check for Ctrl+Down (move task down)
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    if ($this.FlatList.Count -gt 0) {
                        $item = $this.FlatList[$this.SelectedIndex]
                        $taskId = $item.Task.Id
                        if ($global:Debug) { Write-Host "Moving task down: $taskId (current selection: $($this.SelectedIndex))" -ForegroundColor Cyan }
                        
                        $this.TaskService.MoveTaskDown($taskId)
                        $this.LoadTasks()
                        
                        # Find the moved task in the new list and select it
                        $newIndex = -1
                        for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
                            if ($this.FlatList[$i].Task.Id -eq $taskId) {
                                $newIndex = $i
                                break
                            }
                        }
                        
                        if ($newIndex -ge 0) {
                            $this.SelectedIndex = $newIndex
                            if ($global:Debug) { Write-Host "Task found at new index: $newIndex" -ForegroundColor Green }
                        } else {
                            if ($global:Debug) { Write-Host "Warning: Task not found after move, keeping current selection" -ForegroundColor Red }
                            # Ensure we don't go out of bounds
                            if ($this.SelectedIndex -ge $this.FlatList.Count) {
                                $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
                            }
                        }
                        $this.EnsureVisible()
                    }
                } else {
                    # Normal navigation
                    if ($this.SelectedIndex -lt ($this.FlatList.Count - 1)) {
                        $this.SetSelectedIndex($this.SelectedIndex + 1)
                        $this.EnsureVisible()
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::Spacebar) {
                # Toggle individual task collapse (only if it's a parent with subtasks)
                if ($this.FlatList.Count -gt 0) {
                    $item = $this.FlatList[$this.SelectedIndex]
                    if ($item.Level -eq 0 -and $item.Task.Subtasks.Count -gt 0) {
                        $item.Task.SubtasksCollapsed = -not $item.Task.SubtasksCollapsed
                        $this.TaskService.UpdateTask($item.Task)
                        $this.LoadTasks()
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                # Start editing first field of selected item
                if ($this.FlatList.Count -gt 0) {
                    $item = $this.FlatList[$this.SelectedIndex]
                    $fields = $this.GetEditableFields($item)
                    if ($fields.Count -gt 0) {
                        $this.StartEdit($fields[0])
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::N) {
                # Start creating new item using BaseListScreen
                $this.StartNewItem()
                return $true
            }
            ([System.ConsoleKey]::S) {
                # Start subtask creation using BaseListScreen
                if ($this.FlatList.Count -gt 0) {
                    # Create subtask for the selected parent task
                    $item = $this.FlatList[$this.SelectedIndex]
                    if ($item.Level -eq 0) { # Only create subtasks for parent tasks
                        $parentTask = $item.Task
                        $newSubtask = [SimpleTask]::new("New Subtask")
                        $newSubtask.ParentId = $parentTask.Id
                        $this.TaskService.AddTask($newSubtask)
                        $this.LoadData() # Refresh
                        
                        # Find and select the new subtask for immediate editing
                        for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
                            if ($this.FlatList[$i].Task.Id -eq $newSubtask.Id) {
                                $this.SelectedIndex = $i
                                $fields = $this.GetEditableFields($this.FlatList[$i])
                                if ($fields.Count -gt 0) {
                                    $this.StartEdit($fields[0])
                                }
                                break
                            }
                        }
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::D) {
                $this.DeleteTask()
                return $true
            }
            ([System.ConsoleKey]::C) {
                # Toggle global collapse (collapse all subtasks)
                $this.GlobalCollapseSubtasks = -not $this.GlobalCollapseSubtasks
                $this.LoadTasks()
                return $true
            }
            ([System.ConsoleKey]::X) {
                # Toggle task completion
                if ($this.FlatList.Count -gt 0) {
                    $item = $this.FlatList[$this.SelectedIndex]
                    $this.TaskService.ToggleComplete($item.Task.Id)
                    $this.LoadTasks()
                }
                return $true
            }
            ([System.ConsoleKey]::T) {
                # Toggle color theme for current task
                if ($this.FlatList.Count -gt 0) {
                    $item = $this.FlatList[$this.SelectedIndex]
                    if ($item.Level -eq 0) {
                        # Parent task - cycle through themes
                        $task = $item.Task
                        $task.ColorTheme = $this.GetNextTheme($task.ColorTheme)
                        $task.SubtaskColorTheme = $task.ColorTheme  # Keep subtasks same theme
                        $this.TaskService.UpdateTask($task)
                        $this.LoadTasks()
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::R) {
                # Edit tags for current task (parent or subtask separately)
                if ($this.FlatList.Count -gt 0) {
                    $item = $this.FlatList[$this.SelectedIndex]
                    # Always edit the currently selected task's tags, whether parent or subtask
                    $this.EditTaskTags($item.Task)
                }
                return $true
            }
            ([System.ConsoleKey]::E) {
                # Start editing using BaseListScreen
                "DEBUG: E key pressed - starting edit sequence $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                if ($this.FlatList.Count -gt 0) {
                    "DEBUG: FlatList has $($this.FlatList.Count) items, SelectedIndex=$($this.SelectedIndex) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                    $item = $this.FlatList[$this.SelectedIndex]
                    "DEBUG: Got item: $($item | ConvertTo-Json -Depth 1) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                    
                    try {
                        "DEBUG: Calling GetEditableFields $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                        $fields = $this.GetEditableFields($item)
                        "DEBUG: GetEditableFields returned: $($fields -join ', ') $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                        
                        if ($fields.Count -gt 0) {
                            "DEBUG: Calling StartEdit with field: $($fields[0]) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                            $this.StartEdit($fields[0])
                            "DEBUG: StartEdit completed successfully $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                        } else {
                            "DEBUG: No editable fields found $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                        }
                    } catch {
                        "DEBUG: ERROR in E key handler: $($_.Exception.Message) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                        "DEBUG: Stack trace: $($_.ScriptStackTrace) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                    }
                } else {
                    "DEBUG: FlatList is empty $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                }
                return $true
            }
            ([System.ConsoleKey]::P) {
                # Open project ExcelDataFlow text export
                if ($this.FlatList.Count -gt 0) {
                    $this.OpenProjectTextExport()
                }
                return $true
            }
            ([System.ConsoleKey]::F1) {
                # Toggle filter: All
                $this.CurrentFilter = "All"
                $this.LoadTasks()
                return $true
            }
            ([System.ConsoleKey]::F2) {
                # Toggle filter: Today
                $this.CurrentFilter = "Today" 
                $this.LoadTasks()
                return $true
            }
            ([System.ConsoleKey]::F3) {
                # Toggle filter: High Priority
                $this.CurrentFilter = "High"
                $this.LoadTasks()
                return $true
            }
            ([System.ConsoleKey]::Z) {
                # Toggle enhanced rendering
                $this.ToggleEnhancedRendering()
                return $true
            }
            ([System.ConsoleKey]::Y) {
                # Toggle slide animations
                $this.ToggleSlideAnimations()
                return $true
            }
            ([System.ConsoleKey]::F12) {
                # Cycle through all filters
                $filters = @("All", "Today", "High", "Medium", "Low")
                $currentIndex = $filters.IndexOf($this.CurrentFilter)
                $nextIndex = ($currentIndex + 1) % $filters.Count
                $this.CurrentFilter = $filters[$nextIndex]
                $this.LoadTasks()
                return $true
            }
            ([System.ConsoleKey]::F5) {
                # Open color theme editor
                $this.OpenThemeEditor()
                return $true
            }
            ([System.ConsoleKey]::F6) {
                # Open Excel Data Management Screen
                "DEBUG: F6 key pressed $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                return $this.OpenExcelScreen()
            }
            ([System.ConsoleKey]::F7) {
                # Project Settings
                return $this.OpenProjectSettings()
            }
            ([System.ConsoleKey]::F8) {
                # Open Project Folder
                return $this.OpenProjectFolder()
            }
            ([System.ConsoleKey]::F9) {
                # Open T2020 Call Log
                return $this.OpenT2020CallLog()
            }
            ([System.ConsoleKey]::F10) {
                # Open Export Data File (read-only)
                return $this.OpenExportDataFile()
            }
            ([System.ConsoleKey]::F11) {
                # Open Action Log
                return $this.OpenActionLog()
            }
            ([System.ConsoleKey]::Q) {
                return $false
            }
            default {
                
                # Check for + key or = key (Project Management Screen)
                if ($key.KeyChar -eq '+' -or $key.KeyChar -eq '=') {
                    return $this.OpenProjectScreen()
                }
                
                # Handle filter commands starting with '/'
                if ($key.KeyChar -eq '/' -and $this.EditingItem -eq $null) {
                    if ($this.FilterInputActive) {
                        # If filter is already active, clear it
                        $this.FilterInputValue = ""
                        $this.FilterInputCursor = 0
                    } else {
                        # If filter exists, start with current filter value for editing
                        if ($this.CurrentFilter -ne "All" -or $this.TagFilter -ne "") {
                            $existingFilter = if ($this.TagFilter -ne "") { "#$($this.TagFilter)" } else { $this.CurrentFilter.ToLower() }
                            $this.FilterInputValue = $existingFilter
                            $this.FilterInputCursor = $existingFilter.Length
                        }
                        $this.StartFilterInput()
                    }
                    return $true
                }
                return $true
            }
        }
        
        return $true
    }
    
    
    # Command palette integration
    [void] ShowCommandPalette() {
        if ($this.CommandPalette) {
            $this.CommandPalette.Show()
            $this.ShowCommandPalette = $true
        }
    }
    
    [void] ShowCommandLine() {
        # Implementation for : command mode
        $this.ShowCommandPalette()
    }
    
    [void] ShowSearchLine() {
        # Implementation for / search mode
        $this.StartFilterInput()
    }
    
    [void] HideInputLines() {
        # Hide any input lines
        $this.ShowCommandPalette = $false
        if ($this.FilterInputActive) {
            $this.FilterInputActive = $false
            # State Machine: Return to browsing state when canceling filter
            $this.InputState = [TaskListInputState]::Browsing
        }
    }
    
    [void] SetStatusMessage([string]$message) {
        $this.StatusMessage = $message
        $this.StatusMessageTime = [DateTime]::Now
    }
    
    [void] EnsureVisible() {
        # Ensure selected item is visible with dynamic heights
        if ($this.SelectedIndex -lt $this.ScrollTop) {
            $this.ScrollTop = $this.SelectedIndex
        } else {
            # Check if selected item fits in current view
            $availableHeight = $this.Height - 5
            $totalHeight = 0
            $needsScroll = $true
            
            for ($i = $this.ScrollTop; $i -le $this.SelectedIndex -and $i -lt $this.FlatList.Count; $i++) {
                $itemHeight = $this.GetItemHeight($i)
                $totalHeight += $itemHeight
                
                if ($i -eq $this.SelectedIndex) {
                    if ($totalHeight -le $availableHeight) {
                        $needsScroll = $false
                    }
                    break
                }
            }
            
            if ($needsScroll) {
                # Scroll to show selected item
                $this.ScrollTop = [Math]::Max(0, $this.SelectedIndex - 1)
            }
        }
    }
    
    # Notes file management - each parent task has its own notes file
    [string] GetNotesFilePath([SimpleTask]$task) {
        # Get the parent task for the notes file
        $parentTask = if ($task.IsParent()) { $task } else { $this.TaskService.GetTask($task.ParentId) }
        if (-not $parentTask) { return "" }
        
        # Create notes directory if it doesn't exist
        $notesDir = Join-Path $PSScriptRoot ".." "Data" "notes"
        if (-not (Test-Path $notesDir)) {
            New-Item -ItemType Directory -Path $notesDir -Force | Out-Null
        }
        
        # Use parent task ID as filename
        return Join-Path $notesDir "$($parentTask.Id).txt"
    }
    
    [string] LoadNotesFromFile([SimpleTask]$task) {
        $notesFile = $this.GetNotesFilePath($task)
        if ($notesFile -and (Test-Path $notesFile)) {
            try {
                return [System.IO.File]::ReadAllText($notesFile)
            } catch {
                return ""
            }
        }
        return ""
    }
    
    [void] SaveNotesToFile([SimpleTask]$task, [string]$content) {
        $notesFile = $this.GetNotesFilePath($task)
        if ($notesFile) {
            try {
                # Atomic save: write to temp file first
                $tempFile = "$notesFile.tmp"
                [System.IO.File]::WriteAllText($tempFile, $content)
                Move-Item -Path $tempFile -Destination $notesFile -Force
            } catch {
                # Clean up temp file if it exists
                if (Test-Path "$notesFile.tmp") {
                    Remove-Item -Path "$notesFile.tmp" -Force -ErrorAction SilentlyContinue
                }
                Write-Warning "Failed to save notes: $_"
            }
        }
    }
    
    # Migrate existing notes from JSON to separate files (run once)
    [void] MigrateNotesToFiles() {
        $allTasks = $this.TaskService.GetParentTasks()  # Get all tasks for migration (no filtering)
        foreach ($parentTask in $allTasks) {
            if (-not [string]::IsNullOrWhiteSpace($parentTask.Notes)) {
                # Save existing notes to file
                $this.SaveNotesToFile($parentTask, $parentTask.Notes)
                # Clear notes from JSON (will be saved on next TaskService save)
                $parentTask.Notes = ""
            }
        }
    }
    
    [bool] EditNotes([SimpleTask]$task) {
        # Create full-screen editor (leave room for header and status)
        $editor = [FullNotesEditor]::new()
        $editor.SetBounds(0, 2, $this.Width, $this.Height - 3)
        
        # Get parent task for notes (subtasks share parent's notes)
        $parentTask = if ($task.IsParent()) { $task } else { $this.TaskService.GetTask($task.ParentId) }
        $parentTaskId = if ($parentTask) { $parentTask.Id } else { $task.Id }
        
        # Auto-recover from crash if available (task-specific)
        $recoveredText = $editor.RecoverAutoSave($parentTaskId)
        if ($recoveredText) {
            # Automatically use recovered text
            $editor.SetText($recoveredText)
        } else {
            # Load notes from file (parent task's notes file)
            $notesContent = $this.LoadNotesFromFile($task)
            $editor.SetText($notesContent)
        }
        
        # Show editor header immediately
        [Console]::Clear()
        [Console]::SetCursorPosition(0, 0)
        Write-Host -NoNewline "$([AppThemeManager]::GetColor("Header"))EDITING NOTES: $($task.Title)$([VT]::Reset())"
        [Console]::SetCursorPosition(0, 1)
        Write-Host -NoNewline ("─" * $this.Width)
        [Console]::SetCursorPosition(0, $this.Height - 1)
        Write-Host -NoNewline "Ctrl+S:Save  Escape:Exit  " -ForegroundColor White
        
        # Initial render
        Write-Host -NoNewline $editor.Render()
        
        # Edit loop
        [Console]::CursorVisible = $true
        $saved = $false
        $lastAutoSave = [datetime]::Now
        
        # Set global reference for crash recovery
        $global:CurrentEditor = $editor
        
        try {
            while ($true) {
                # Check for key available (non-blocking for auto-save)
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    
                    if ($key.Key -eq [System.ConsoleKey]::Escape) {
                        # Always auto-save on exit
                        if ($editor.HasUnsavedChanges()) {
                            $this.SaveNotesToFile($task, $editor.GetText())
                            $saved = $true
                        }
                        break
                    } elseif ($key.Key -eq [System.ConsoleKey]::S -and 
                             ($key.Modifiers -band [System.ConsoleModifiers]::Control)) {
                        # Manual save with immediate feedback
                        [Console]::SetCursorPosition(0, $this.Height - 1)
                        Write-Host -NoNewline "Saving..." -ForegroundColor Green -BackgroundColor DarkGreen
                        
                        $this.SaveNotesToFile($task, $editor.GetText())
                        $saved = $true
                        
                        # Show save confirmation immediately
                        [Console]::SetCursorPosition(0, $this.Height - 1)
                        Write-Host -NoNewline "Saved!                                            " -ForegroundColor Green -BackgroundColor DarkGreen
                    } else {
                        if ($editor.HandleInput($key)) {
                            # Re-render the editor after handling input
                            Write-Host -NoNewline $editor.Render()
                        }
                    }
                }
                
                # Auto-save every 10 seconds (silent)
                if (([datetime]::Now - $lastAutoSave).TotalSeconds -gt 10) {
                    $editor.AutoSaveIfNeeded()
                    $lastAutoSave = [datetime]::Now
                }
                
                # Small sleep to prevent CPU spinning
                Start-Sleep -Milliseconds 50
            }
        } finally {
            # Always call OnExit to ensure auto-save
            $editor.OnExit($parentTaskId)
            
            # If we saved, ensure atomic save to notes file
            if ($saved -or $editor.HasUnsavedChanges()) {
                $this.SaveNotesToFile($task, $editor.GetText())
            }
            
            [Console]::CursorVisible = $false
            
            # Clear global reference
            $global:CurrentEditor = $null
            
            # Force refresh of task list
            $this.LoadTasks()
        }
        
        return $true
    }
    
    [bool] EditTaskTags([SimpleTask]$task) {
        # Check if we're in an interactive console environment
        try {
            $testAvailable = [Console]::KeyAvailable
            $testCursor = [Console]::CursorVisible
        } catch {
            # Not in interactive console - fall back to simple text input
            if ($global:Debug) { Write-Host "Console not interactive, using fallback tag editor" -ForegroundColor Yellow }
            return $this.EditTagsFallback($task)
        }
        
        # Create tag editor
        $editor = [TagEditor]::new()
        $editorWidth = [Math]::Min(60, $this.Width - 10)
        $editorHeight = 4
        $editorX = ($this.Width - $editorWidth) / 2
        $editorY = ($this.Height - $editorHeight) / 2
        
        $editor.SetBounds($editorX, $editorY, $editorWidth, $editorHeight)
        $editor.SetTags($task.Tags)
        
        # Save original screen content (simplified)
        $originalCursor = [Console]::CursorVisible
        [Console]::CursorVisible = $true
        
        try {
            while ($true) {
                # Clear editor area and render
                for ($y = $editorY; $y -lt ($editorY + $editorHeight); $y++) {
                    [Console]::SetCursorPosition(0, $y)
                    Write-Host -NoNewline (" " * $this.Width)
                }
                
                # Render editor
                Write-Host -NoNewline $editor.Render()
                
                # Check if console input is available (prevents crash in non-interactive mode)
                try {
                    if (-not [Console]::KeyAvailable) {
                        Start-Sleep -Milliseconds 50
                        continue
                    }
                    $key = [Console]::ReadKey($true)
                } catch {
                    # Console not available or error reading key
                    if ($global:Debug) { Write-Host "Console read error: $_" -ForegroundColor Red }
                    break
                }
                
                if (-not $editor.HandleInput($key)) {
                    # Editor finished
                    if ($key.Key -eq [System.ConsoleKey]::Enter) {
                        # Save tags
                        $task.Tags = $editor.GetTags()
                        $this.TaskService.UpdateTask($task)
                        $this.LoadTasks()
                    }
                    # Escape or Enter - exit without saving on Escape
                    break
                }
            }
        } catch {
            if ($global:Debug) { Write-Host "EditTaskTags error: $_" -ForegroundColor Red }
        } finally {
            [Console]::CursorVisible = $originalCursor
        }
        
        return $true
    }
    
    [bool] EditTagsFallback([SimpleTask]$task) {
        # Simple fallback for non-interactive environments
        Write-Host ""
        Write-Host "Current tags: $($task.Tags -join ', ')" -ForegroundColor Yellow
        Write-Host "Enter new tags (format: #tag1 #tag2 #tag3):" -NoNewline
        try {
            $input = Read-Host
            if ($input) {
                # Parse tags from input
                $tagParts = $input -split '#' | Where-Object { $_.Trim() -ne "" }
                $cleanTags = @()
                foreach ($part in $tagParts) {
                    $cleanTag = $part.Trim() -replace '\s+', '-'
                    if ($cleanTag -ne "") {
                        $cleanTags += $cleanTag
                    }
                }
                $task.Tags = $cleanTags
                $this.TaskService.UpdateTask($task)
                $this.LoadTasks()
                Write-Host "Tags updated: $($task.Tags -join ', ')" -ForegroundColor Green
            }
        } catch {
            if ($global:Debug) { Write-Host "Fallback tag editor error: $_" -ForegroundColor Red }
        }
        return $true
    }
    
    [void] CreateNewTask() {
        [Console]::SetCursorPosition(0, $this.Height)
        Write-Host -NoNewline "New task title: "
        [Console]::CursorVisible = $true
        $title = Read-Host
        [Console]::CursorVisible = $false
        
        if ($title) {
            $task = [SimpleTask]::new($title)
            $this.TaskService.AddTask($task)
            $this.LoadTasks()
        }
    }
    
    [void] CreateSubtask() {
        if ($this.FlatList.Count -eq 0) { return }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $parentTask = if ($item.Task.IsParent()) { $item.Task } else { $this.TaskService.GetTask($item.Task.ParentId) }
        
        if (-not $parentTask) { return }
        
        [Console]::SetCursorPosition(0, $this.Height)
        Write-Host -NoNewline "New subtask for '$($parentTask.Title)': "
        [Console]::CursorVisible = $true
        $title = Read-Host
        [Console]::CursorVisible = $false
        
        if ($title) {
            $subtask = [SimpleTask]::new($title)
            $this.TaskService.AddSubtask($parentTask.Id, $subtask)
            $this.LoadTasks()
        }
    }
    
    # === ALL LEGACY EDITING METHODS REMOVED ===
    
    [void] OpenThemeEditor() {
        # Open the new ThemeEditorDialog
        if ($this.FlatList.Count -eq 0 -or $this.SelectedIndex -lt 0) {
            return
        }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $selectedTask = $item.Task
        $isSubtask = ($item.Level -eq 1)
        
        # Create and show the theme editor dialog
        $themeDialog = [ThemeEditorDialog]::new()
        $customThemeName = $themeDialog.Show()
        
        # If user created a custom theme, apply it
        if ($customThemeName -and $customThemeName -ne "") {
            if ($isSubtask) {
                # Apply to parent task's subtask theme
                $parentTask = $this.TaskService.GetParentTask($selectedTask.Id)
                if ($parentTask) {
                    $parentTask.SubtaskColorTheme = $customThemeName
                    $this.TaskService.Save()
                }
            } else {
                # Apply to selected task
                $selectedTask.ColorTheme = $customThemeName
                $this.TaskService.Save()
            }
            
            # Rebuild and refresh display
            $this.BuildFlatList()
        }
    }
    
    # Project Management Methods - Screen Transition
    
    [bool] OpenProjectScreen() {
        # Get current parent task for context
        if ($this.FlatList.Count -eq 0) {
            return $true
        }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $parentTask = if ($item.Task.IsParent()) { $item.Task } else { $this.TaskService.GetTask($item.Task.ParentId) }
        if (-not $parentTask) {
            return $true
        }
        
        # Create and show the dedicated Project Management Screen
        $projectScreen = [ProjectManagerScreen]::new()
        $projectScreen.SetServices($this.TaskService)
        $projectScreen.SetParentTask($parentTask)
        $projectScreen.SetBounds(0, 0, $this.Width, $this.Height)
        
        # Show the screen - this will handle all input until user returns
        $projectScreen.Show()
        
        # When we return, reload tasks in case anything changed
        $this.LoadTasks()
        
        return $true
    }

    [bool] OpenProjectSettings() {
        if ($this.FlatList.Count -eq 0) { 
            Write-Warning "No tasks available"
            return $true 
        }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $parentTask = if ($item.Task.IsParent()) { $item.Task } else { $this.TaskService.GetTask($item.Task.ParentId) }
        if (-not $parentTask) {
            Write-Warning "No parent task found"
            return $true
        }
        
        $dialog = [ProjectSettingsDialog]::new()
        if ($dialog.Show($parentTask)) {
            $this.TaskService.UpdateTask($parentTask)
            $this.LoadTasks()
        }
        return $true
    }

    [bool] OpenExcelScreen() {
        # Switch to Excel Data Management screen
        "DEBUG: OpenExcelScreen called $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        if ($this.AppReference) {
            "DEBUG: AppReference exists, calling SwitchToExcel $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            $this.AppReference.SwitchToExcel()
        } else {
            "DEBUG: No AppReference available $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        }
        return $true
    }

    [bool] OpenProjectFolder() {
        $parentTask = $this.GetCurrentParentTask()
        if (-not $parentTask) {
            Write-Warning "No parent task selected"
            return $true
        }
        
        if (-not $parentTask.ProjectFolderPath -or -not (Test-Path $parentTask.ProjectFolderPath)) {
            Write-Warning "No project folder configured or folder not found. Press F7 to configure."
            return $true
        }
        
        try {
            Start-Process explorer.exe -ArgumentList $parentTask.ProjectFolderPath
        } catch {
            Write-Warning "Could not open project folder: $_"
        }
        return $true
    }

    [bool] OpenT2020CallLog() {
        $parentTask = $this.GetCurrentParentTask()
        if (-not $parentTask) {
            Write-Warning "No parent task selected"
            return $true
        }
        
        if (-not $parentTask.T2020CallLogFile -or -not (Test-Path $parentTask.T2020CallLogFile)) {
            Write-Warning "No T2020 call log configured or file not found. Press F7 to configure."
            return $true
        }
        
        return $this.EditExternalFile($parentTask.T2020CallLogFile, "T2020 CALL LOG", $false)
    }

    [bool] OpenExportDataFile() {
        $parentTask = $this.GetCurrentParentTask()
        if (-not $parentTask) {
            Write-Warning "No parent task selected"
            return $true
        }
        
        if (-not $parentTask.ExportDataFile -or -not (Test-Path $parentTask.ExportDataFile)) {
            Write-Warning "No export data file configured or file not found. Press F7 to configure."
            return $true
        }
        
        return $this.EditExternalFile($parentTask.ExportDataFile, "EXPORT DATA (READ-ONLY)", $true)
    }

    [bool] OpenActionLog() {
        $parentTask = $this.GetCurrentParentTask()
        if (-not $parentTask) {
            Write-Warning "No parent task selected"
            return $true
        }
        
        if (-not $parentTask.ProjectFolderPath) {
            Write-Warning "No project folder configured. Press F7 to configure."
            return $true
        }
        
        $actionLogPath = Join-Path $parentTask.ProjectFolderPath "$($parentTask.ActionLogName).txt"
        
        # Create action log if it doesn't exist
        if (-not (Test-Path $actionLogPath)) {
            try {
                $initialContent = "# Action Log for $($parentTask.Title)`n# Created: $(Get-Date)`n`n"
                [System.IO.File]::WriteAllText($actionLogPath, $initialContent)
            } catch {
                Write-Warning "Could not create action log file: $_"
                return $true
            }
        }
        
        return $this.EditExternalFile($actionLogPath, "ACTION LOG", $false)
    }

    [SimpleTask] GetCurrentParentTask() {
        if ($this.FlatList.Count -eq 0) { return $null }
        $item = $this.FlatList[$this.SelectedIndex]
        return if ($item.Task.IsParent()) { $item.Task } else { $this.TaskService.GetTask($item.Task.ParentId) }
    }

    [bool] EditExternalFile([string]$filePath, [string]$title, [bool]$readOnly) {
        # Use the existing notes editor but for external files
        $editor = [FullNotesEditor]::new()
        $editor.SetBounds(0, 2, $this.Width, $this.Height - 3)
        
        try {
            $content = [System.IO.File]::ReadAllText($filePath)
            $editor.SetText($content)
        } catch {
            Write-Warning "Could not load file: $_"
            return $true
        }
        
        # Show editor
        [Console]::Clear()
        [Console]::SetCursorPosition(0, 0)
        $titleColor = if ($readOnly) { [AppThemeManager]::GetColor("High") } else { [AppThemeManager]::GetColor("Header") }
        Write-Host -NoNewline "$titleColor$title$([VT]::Reset())"
        
        if ($readOnly) {
            Write-Host -NoNewline " (READ-ONLY - Press 'E' to edit in external editor)"
        }
        
        Write-Host -NoNewline $editor.Render()
        
        # Edit loop
        $saved = $false
        while ($true) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                
                if ($key.Key -eq [System.ConsoleKey]::Escape) {
                    # Auto-save if not read-only and has changes
                    if (-not $readOnly -and $editor.HasUnsavedChanges()) {
                        try {
                            [System.IO.File]::WriteAllText($filePath, $editor.GetText())
                            $saved = $true
                        } catch {
                            Write-Warning "Could not save file: $_"
                        }
                    }
                    break
                } elseif ($key.Key -eq [System.ConsoleKey]::S -and ($key.Modifiers -band [System.ConsoleModifiers]::Control) -and -not $readOnly) {
                    # Manual save
                    try {
                        [System.IO.File]::WriteAllText($filePath, $editor.GetText())
                        [Console]::SetCursorPosition(0, $this.Height - 1)
                        Write-Host -NoNewline "Saved!" -ForegroundColor Green
                        $saved = $true
                    } catch {
                        [Console]::SetCursorPosition(0, $this.Height - 1)
                        Write-Host -NoNewline "Save failed: $_" -ForegroundColor Red
                    }
                } elseif ($key.KeyChar -eq 'E' -and $readOnly) {
                    # Open in external editor for read-only files
                    try {
                        Start-Process notepad.exe -ArgumentList $filePath
                    } catch {
                        Write-Warning "Could not open external editor: $_"
                    }
                } else {
                    if (-not $readOnly -and $editor.HandleInput($key)) {
                        Write-Host -NoNewline $editor.Render()
                    }
                }
            }
            Start-Sleep -Milliseconds 10
        }
        
        return $true
    }
}
