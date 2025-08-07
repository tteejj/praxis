# TaskListScreen.ps1 - Simple task list with subtasks

class TaskListScreen {
    [SimpleTaskService]$TaskService
    [SimpleTask[]]$Tasks
    [System.Collections.Generic.List[object]]$FlatList  # Flattened list for navigation
    [int]$SelectedIndex = 0
    [int]$ScrollTop = 0
    [int]$Width
    [int]$Height
    [bool]$GlobalCollapseSubtasks = $false
    [string]$CurrentFilter = "All"  # Filter mode: "All", "Today", "High", etc.
    [string]$TagFilter = ""  # Tag-based filter like "work", "personal", etc.
    
    # Inline editing state
    [int]$EditingIndex = -1
    [string]$EditingField = ""  # "title", "priority", "date", "tags"
    [string]$EditingValue = ""
    [int]$EditingCursor = 0    # Cursor position within EditingValue
    [SimpleTask]$EditingTask = $null
    [bool]$IsNewTask = $false
    
    # Filter input state
    [bool]$FilterInputActive = $false
    [string]$FilterInputValue = ""
    [int]$FilterInputCursor = 0
    
    # Modern RGB Colors
    [string]$HeaderColor = "`e[38;2;100;150;255m"     # Modern blue
    [string]$HighColor = "`e[38;2;255;100;100m"       # Coral red
    [string]$MediumColor = "`e[38;2;255;165;0m"       # Orange
    [string]$LowColor = "`e[38;2;80;200;120m"         # Green
    [string]$TodayColor = "`e[38;2;255;215;0m"        # Bright gold/yellow for TODAY
    [string]$SubtaskColor = "`e[38;2;160;160;160m"    # Medium gray
    [string]$SelectedBg = "`e[48;2;45;45;55m"         # Dark background highlight
    [string]$EvenRowBg = "`e[48;2;25;25;30m"          # Subtle dark background
    [string]$CompletedColor = "`e[38;2;120;120;120m"  # Medium gray
    [string]$TagColor = "`e[38;2;180;180;180m"        # Light gray for tags
    [string]$NormalColor = "`e[0m"                     # Reset
    
    # Date colors
    [string]$OverdueColor = "`e[38;2;255;100;100m"    # Red
    [string]$WeekColor = "`e[38;2;255;165;0m"          # Orange
    [string]$TodayDateColor = "`e[38;2;255;255;100m"       # Yellow
    [string]$FutureColor = "`e[38;2;80;200;120m"       # Green
    [string]$EditHighlight = "`e[47;30m"  # White background, black text (simpler ANSI)
    
    # Column widths - optimized for space efficiency
    [int]$COLUMN_STATUS = 3      # "☐  "
    [int]$COLUMN_PRIORITY = 2    # "H " (single char + space)
    [int]$COLUMN_DATE = 9        # "yyyy-MM-dd" (8 chars + space)
    [int]$COLUMN_ARROW = 3       # "▼  "
    [int]$TREE_INDENT = 7        # "    └─ " for subtasks
    [int]$SUBTASK_INDENT = 4     # "    " spacing
    
    # Backward compatibility aliases
    [int]$StatusCol = 3
    [int]$PriorityCol = 2 
    [int]$DateCol = 9
    [int]$ArrowCol = 3
    [int]$IndentWidth = 4
    
    # Built-in color themes - no external dependencies
    [hashtable]$TaskColors = @{
        "default"  = "`e[38;2;250;248;240m"      # Warm white
        "red"      = "`e[38;2;255;100;100m"      # Bright red  
        "blue"     = "`e[38;2;100;150;255m"      # Modern blue
        "green"    = "`e[38;2;80;200;120m"       # Modern green
        "purple"   = "`e[38;2;200;120;255m"      # Modern purple
        "orange"   = "`e[38;2;255;165;0m"        # Orange
        "cyan"     = "`e[38;2;100;200;200m"      # Cyan
        "pink"     = "`e[38;2;255;80;120m"       # Hot pink
        # Legacy theme name mappings for existing data
        "work"     = "`e[38;2;100;150;255m"      # Blue
        "urgent"   = "`e[38;2;255;100;100m"      # Red
        "personal" = "`e[38;2;80;200;120m"       # Green
        "project"  = "`e[38;2;200;120;255m"      # Purple
    }
    
    [hashtable]$SubtaskColors = @{
        "default"  = "`e[38;2;160;160;160m"      # Medium gray
        "red"      = "`e[38;2;200;80;80m"        # Darker red
        "blue"     = "`e[38;2;80;120;200m"       # Darker blue
        "green"    = "`e[38;2;60;160;100m"       # Darker green
        "purple"   = "`e[38;2;160;100;200m"      # Darker purple
        "orange"   = "`e[38;2;200;130;0m"        # Darker orange
        "cyan"     = "`e[38;2;80;160;160m"       # Darker cyan
        "pink"     = "`e[38;2;200;60;100m"       # Darker pink
        # Legacy theme name mappings for existing data
        "work"     = "`e[38;2;80;120;200m"       # Darker blue
        "urgent"   = "`e[38;2;200;80;80m"        # Darker red
        "personal" = "`e[38;2;60;160;100m"       # Darker green
        "project"  = "`e[38;2;160;100;200m"      # Darker purple
    }
    
    # Pillbox characters
    [string]$PillboxTopLeft = "╭"
    [string]$PillboxTopRight = "╮"
    [string]$PillboxBottomLeft = "╰"
    [string]$PillboxBottomRight = "╯"
    [string]$PillboxHorizontal = "─"
    [string]$PillboxVertical = "│"
    
    TaskListScreen() {
        $this.TaskService = [SimpleTaskService]::new()
        $this.FlatList = [System.Collections.Generic.List[object]]::new()
        # Migrate existing notes to files (run once, safe to call multiple times)
        $this.MigrateNotesToFiles()
        $this.LoadTasks()
    }
    
    # Self-contained color theme methods - replace ColorThemeService
    [string] GetTaskColor([string]$theme) {
        if ($this.TaskColors.ContainsKey($theme)) {
            return $this.TaskColors[$theme]
        }
        return $this.TaskColors["default"]
    }
    
    [string] GetSubtaskColor([string]$theme) {
        if ($this.SubtaskColors.ContainsKey($theme)) {
            return $this.SubtaskColors[$theme]
        }
        return $this.SubtaskColors["default"]
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
        $allTasks = $this.TaskService.GetParentTasks()
        $this.Tasks = $this.FilterTasks($allTasks)
        $this.BuildFlatList()
        
        if ($this.SelectedIndex -ge $this.FlatList.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
        }
    }
    
    [SimpleTask[]] FilterTasks([SimpleTask[]]$tasks) {
        if ($this.CurrentFilter -eq "All" -and $this.TagFilter -eq "") {
            return $tasks
        }
        
        $filteredTasks = @()
        $today = [datetime]::Today
        
        foreach ($task in $tasks) {
            $includeTask = $false
            
            # Priority/Date filtering
            switch ($this.CurrentFilter) {
                "All" { $includeTask = $true }
                "Today" {
                    # Include if priority is "Today" OR due date is today
                    $includeTask = ($task.Priority -eq "Today") -or 
                                  ($task.DueDate -ne [datetime]::MinValue -and $task.DueDate.Date -eq $today)
                }
                "High" { $includeTask = ($task.Priority -eq "High") }
                "Medium" { $includeTask = ($task.Priority -eq "Medium") }
                "Low" { $includeTask = ($task.Priority -eq "Low") }
            }
            
            # Tag filtering (additional filter)
            if ($includeTask -and $this.TagFilter -ne "") {
                $includeTask = $false
                # Check if task has the filtered tag (case insensitive)
                foreach ($tag in $task.Tags) {
                    if ($tag.ToLower() -eq $this.TagFilter.ToLower()) {
                        $includeTask = $true
                        break
                    }
                }
            }
            
            if ($includeTask) {
                $filteredTasks += $task
            }
        }
        
        return $filteredTasks
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
        [void]$sb.Append($this.HeaderColor)
        [void]$sb.Append($this.PillboxTopLeft)
        [void]$sb.Append($this.PillboxHorizontal * ($width - 2))
        [void]$sb.Append($this.PillboxTopRight)
        [void]$sb.Append($this.NormalColor)
    }
    
    [void] RenderPillboxBottom([System.Text.StringBuilder]$sb, [int]$width, [int]$y) {
        [void]$sb.Append([VT]::MoveTo(0, $y))
        [void]$sb.Append($this.HeaderColor)
        [void]$sb.Append($this.PillboxBottomLeft)
        [void]$sb.Append($this.PillboxHorizontal * ($width - 2))
        [void]$sb.Append($this.PillboxBottomRight)
        [void]$sb.Append($this.NormalColor)
    }
    
    [void] RenderPillboxSide([System.Text.StringBuilder]$sb, [int]$x, [int]$y) {
        [void]$sb.Append([VT]::MoveTo($x, $y))
        [void]$sb.Append($this.HeaderColor)
        [void]$sb.Append($this.PillboxVertical)
        [void]$sb.Append($this.NormalColor)
    }

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
        return ""  # Explicit fallback return
    }

    [datetime] ConvertDateInput([string]$input) {
        # Enhanced date input with quick entry shortcuts
        $input = $input.Trim().ToLower()
        if ($input -eq "") {
            return [datetime]::MinValue
        }
        
        $today = [datetime]::Today
        
        # Quick date shortcuts
        switch ($input) {
            "t" { return $today }
            "today" { return $today }
            "tom" { return $today.AddDays(1) }
            "tomorrow" { return $today.AddDays(1) }
            "mon" { return $this.GetNextWeekday([DayOfWeek]::Monday) }
            "tue" { return $this.GetNextWeekday([DayOfWeek]::Tuesday) }
            "wed" { return $this.GetNextWeekday([DayOfWeek]::Wednesday) }
            "thu" { return $this.GetNextWeekday([DayOfWeek]::Thursday) }
            "fri" { return $this.GetNextWeekday([DayOfWeek]::Friday) }
            "sat" { return $this.GetNextWeekday([DayOfWeek]::Saturday) }
            "sun" { return $this.GetNextWeekday([DayOfWeek]::Sunday) }
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
        if ($input -match '^\+(\d+)m$') {
            $months = [int]$matches[1]
            return $today.AddMonths($months)
        }
        
        try {
            if ($input.Length -eq 8) {
                # yyyymmdd format
                $year = [int]$input.Substring(0, 4)
                $month = [int]$input.Substring(4, 2)
                $day = [int]$input.Substring(6, 2)
                return [datetime]::new($year, $month, $day)
            } elseif ($input.Length -eq 4) {
                # mmdd format - use current year
                $year = [datetime]::Now.Year
                $month = [int]$input.Substring(0, 2)
                $day = [int]$input.Substring(2, 2)
                return [datetime]::new($year, $month, $day)
            } else {
                # Try to parse as regular date
                return [datetime]::Parse($input)
            }
        } catch {
            return [datetime]::MinValue
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
    }
    
    [bool] HandleFilterInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Enter) {
                $this.EndFilterInput($true)
                return $true
            }
            ([System.ConsoleKey]::Escape) {
                $this.EndFilterInput($false)
                return $true
            }
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
            [void]$sb.Append($this.EditHighlight + $fieldValue + $this.NormalColor)
        } elseif ($isEditingThis -and ($task.Priority -eq "High" -or $task.Priority -eq "Medium" -or $task.Priority -eq "Low" -or $task.Priority -eq "Today")) {
            # Show inactive field with dim highlight when editing other fields
            $priorityText = switch ($task.Priority) {
                "High" { "H " }
                "Medium" { "M " }
                "Low" { "L " }
                "Today" { "T " }
            }
            [void]$sb.Append("`e[48;2;30;30;40m" + $priorityText + $this.NormalColor)
        } elseif ($task.Priority -eq "High" -or $task.Priority -eq "Medium" -or $task.Priority -eq "Low" -or $task.Priority -eq "Today") {
            $priorityText = switch ($task.Priority) {
                "High" { "H" }
                "Medium" { "M" }
                "Low" { "L" }
                "Today" { "T" }
            }
            $priorityColor = switch ($task.Priority) {
                "High" { $this.HighColor }
                "Medium" { $this.MediumColor }
                "Low" { $this.LowColor }
                "Today" { $this.TodayColor }
            }
            [void]$sb.Append($priorityColor + $priorityText + $this.NormalColor + " ")
        }
        
        # Render date if set or being edited
        if ($isEditingThis -and $this.EditingField -eq "date") {
            # Show active field with bright highlight (6 chars for MM-dd format)
            $fieldValue = $this.EditingValue.PadRight(6)
            [void]$sb.Append($this.EditHighlight + $fieldValue + $this.NormalColor)
        } elseif ($isEditingThis -and $task.DueDate -ne [datetime]::MinValue) {
            # Show inactive field with dim highlight when editing other fields
            $compactDate = $task.DueDate.ToString("MM-dd").PadRight(6)
            [void]$sb.Append("`e[48;2;30;30;40m" + $compactDate + $this.NormalColor)
        } elseif ($task.DueDate -ne [datetime]::MinValue) {
            $compactDate = $task.DueDate.ToString("MM-dd")
            $today = [datetime]::Today
            $due = $task.DueDate.Date
            $days = ($due - $today).Days
            
            # Use same colors as parent tasks
            $dateColor = if ($days -lt 0) {
                $this.OverdueColor
            } elseif ($days -eq 0) {
                $this.TodayDateColor
            } elseif ($days -le 7) {
                $this.WeekColor
            } else {
                $this.FutureColor
            }
            [void]$sb.Append($dateColor + $compactDate + $this.NormalColor + " ")
        }
    }

    [string] GetDateColorAndText([SimpleTask]$task) {
        if ($task.DueDate -eq [datetime]::MinValue) {
            return $this.TagColor + "-".PadRight(8) + $this.NormalColor
        }
        
        $today = [datetime]::Today
        $due = $task.DueDate.Date
        $daysDiff = ($due - $today).Days
        
        $dateText = $due.ToString("yyyy-MM-dd")
        $color = if ($daysDiff -lt 0) { $this.OverdueColor }
                elseif ($daysDiff -eq 0) { $this.TodayDateColor }
                elseif ($daysDiff -le 7) { $this.WeekColor }
                else { $this.FutureColor }
        
        return $color + $dateText + $this.NormalColor
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
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Clear screen
        [void]$sb.Append([VT]::Clear())
        
        # Header with filter info
        [void]$sb.Append([VT]::MoveTo(0, 0))
        [void]$sb.Append($this.HeaderColor)
        $headerText = "TASKPRO - Task Manager"
        if ($this.CurrentFilter -ne "All") {
            $headerText += " [Filter: $($this.CurrentFilter)]"
        }
        if ($this.TagFilter -ne "") {
            $headerText += " [Tag: #$($this.TagFilter)]"
        }
        [void]$sb.Append($headerText)
        [void]$sb.Append($this.NormalColor)
        
        # Column headers
        [void]$sb.Append([VT]::MoveTo(0, 1))
        [void]$sb.Append($this.TagColor)
        [void]$sb.Append("St ")        # Status column (3 chars)
        [void]$sb.Append("P ")         # Priority column (2 chars)
        [void]$sb.Append("Date     ")  # Date column (9 chars)
        [void]$sb.Append("  Title")    # Arrow + title
        [void]$sb.Append($this.NormalColor)
        
        [void]$sb.Append([VT]::MoveTo(0, 2))
        [void]$sb.Append("─" * $this.Width)
        
        # Task list
        $this.RenderTaskList($sb)
        
        # Status bar
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 2))
        [void]$sb.Append("─" * $this.Width)
        
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 1))
        [void]$sb.Append($this.TagColor)
        if ($this.FilterInputActive) {
            # Show filter input as a proper textbox
            $filterPrompt = "Filter: "
            [void]$sb.Append($filterPrompt)
            $fieldWidth = 20
            $fieldValue = $this.FilterInputValue.PadRight($fieldWidth)
            [void]$sb.Append($this.EditHighlight + $fieldValue + $this.NormalColor)
            [void]$sb.Append("  Enter:Apply  Escape:Cancel  (#tag, high/med/low/today, clear)")
        } elseif ($this.EditingIndex -ge 0) {
            [void]$sb.Append("EDITING [$($this.EditingField.ToUpper())]: Tab:Next Field  Enter:Save  Escape:Cancel")
        } else {
            [void]$sb.Append("↑↓:Navigate  E:Edit  N:New  S:Subtask  X:Toggle  T:Theme  /:Filter  F1:All  F2:Today  F3:High  F4:Cycle  F5:Color  F6:Projects  Q:Quit")
        }
        [void]$sb.Append($this.NormalColor)
        
        # Show/hide cursor based on editing state and position it correctly
        if ($this.EditingIndex -ge 0) {
            [void]$sb.Append([VT]::ShowCursor())
            # Set cursor to bright red so it's visible against white background
            [void]$sb.Append("`e]12;#FF0000`e\")  # OSC sequence to set cursor color to red
            # Position cursor at the end of the editing field
            $this.PositionCursorForEditing($sb)
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
                $rightBorderColumn = $this.Width  # Right border at screen edge
                
                # Spacer line above
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append(" " * $this.Width)
                $currentY++
                
                # Pillbox top
                $this.RenderPillboxTop($sb, $pillboxWidth, $currentY)
                $currentY++
                
                # Content line 1 with pillbox sides
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append($this.HeaderColor + $this.PillboxVertical + $this.NormalColor)
                $this.RenderTaskContent($sb, $task, $level, $isLast, $false, $isSelected)
                
                # Move cursor to EXACT right border position
                [void]$sb.Append([VT]::MoveTo($rightBorderColumn, $currentY))
                [void]$sb.Append($this.HeaderColor + $this.PillboxVertical + $this.NormalColor)
                $currentY++
                
                # Content line 2 (tags) with pillbox sides
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append($this.HeaderColor + $this.PillboxVertical + $this.NormalColor)
                
                # Render tag content
                $isEditingThis = ($this.EditingTask -and $this.EditingTask.Id -eq $task.Id)
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
                    [void]$sb.Append($this.TagColor + "⟨" + ($task.Tags -join ", ") + "⟩" + $this.NormalColor)
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
                    [void]$sb.Append("⟨" + $this.EditHighlight + $fieldValue + $this.NormalColor + "⟩")
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
                [void]$sb.Append($this.HeaderColor + $this.PillboxVertical + $this.NormalColor)
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
    
    [void] RenderTaskContent([System.Text.StringBuilder]$sb, [SimpleTask]$task, [int]$level, [bool]$isLast, [bool]$clearToEnd, [bool]$isSelected = $false) {
        $isEditingThis = ($this.EditingTask -and $this.EditingTask.Id -eq $task.Id)
        
        # COLUMN 1: STATUS (3 chars) - ☐ or ■
        if ($isEditingThis -and $this.EditingField -eq "status") {
            # Show active field with bright highlight
            $fieldValue = $this.EditingValue.PadRight(2)
            [void]$sb.Append($this.EditHighlight + $fieldValue + " " + $this.NormalColor)
        } elseif ($isEditingThis) {
            # Show inactive field with dim highlight when editing other fields
            $statusValue = if ($task.Completed) { "■" } else { "☐" }
            [void]$sb.Append("`e[48;2;30;30;40m" + $statusValue.PadRight(2) + " " + $this.NormalColor)
        } else {
            if ($task.Completed) {
                [void]$sb.Append("■  ")  # Filled square for completed
            } else {
                [void]$sb.Append("☐  ")  # Open square for incomplete
            }
        }
        
        # COLUMN 2: PRIORITY (5 chars for parents, 1 char for subtasks)
        if ($level -eq 0) {
            # Parent task - full priority display
            if ($isEditingThis -and $this.EditingField -eq "priority") {
                # Show active field with reverse video highlighting (1 char only)
                $displayValue = if ($this.EditingValue -ne "") { $this.EditingValue } else { " " }
                [void]$sb.Append("`e[7m" + $displayValue + "`e[0m" + " ")  # Reverse video + space
            } elseif ($isEditingThis) {
                # Show inactive field with dim highlight when editing other fields (1 char)
                $priorityText = switch ($task.Priority) {
                    "High" { "H" }
                    "Medium" { "M" }
                    "Low" { "L" }
                    "Today" { "T" }
                    default { " " }
                }
                [void]$sb.Append("`e[48;2;30;30;40m" + $priorityText + "`e[0m" + " ")  # Dim highlight + space
            } else {
                $priorityText = switch ($task.Priority) {
                    "High" { "H " }
                    "Medium" { "M " }
                    "Low" { "L " }
                    "Today" { "T " }
                    default { "  " }
                }
                $priorityColor = switch ($task.Priority) {
                    "High" { $this.HighColor }
                    "Medium" { $this.MediumColor }
                    "Low" { $this.LowColor }
                    "Today" { $this.TodayColor }
                    default { $this.TagColor }
                }
                [void]$sb.Append($priorityColor + $priorityText + $this.NormalColor)
            }
        } else {
            # Subtasks don't show priority in columns - will show after tree chars
            [void]$sb.Append("  ")  # Empty spacing for subtasks (2 chars)
        }
        
        # COLUMN 3: DATE (9 chars for parents)
        if ($level -eq 0) {
            # Parent task - full date display
            if ($isEditingThis -and $this.EditingField -eq "date") {
                # Show active field with reverse video highlighting (8 chars for date)
                $displayValue = if ($this.EditingValue -ne "") { $this.EditingValue.PadRight(8) } else { " ".PadRight(8) }
                [void]$sb.Append("`e[7m" + $displayValue + "`e[0m" + " ")  # Reverse video
            } elseif ($isEditingThis) {
                # Show inactive field with dim highlight when editing other fields
                $dateText = if ($task.DueDate -eq [datetime]::MinValue) { " ".PadRight(8) } else { $task.DueDate.ToString("yyyy-MM-dd") }
                [void]$sb.Append("`e[48;2;30;30;40m" + $dateText + "`e[0m" + " ")  # Dim highlight
            } else {
                [void]$sb.Append($this.GetDateColorAndText($task))
                [void]$sb.Append(" ")
            }
        } else {
            # Subtasks don't show date in columns - will show after tree chars
            [void]$sb.Append(" " * $this.DateCol)  # Empty spacing for subtasks (9 chars)
        }
        
        # COLUMN 4: ARROW (3 chars - closest to task)
        if ($level -eq 0 -and $task.Subtasks.Count -gt 0) {
            if ($this.GlobalCollapseSubtasks -or $task.SubtasksCollapsed) {
                [void]$sb.Append("▶  ")  # Collapsed
            } else {
                [void]$sb.Append("▼  ")  # Expanded
            }
        } else {
            [void]$sb.Append("   ")
        }
        
        # COLUMN 5: TITLE (with indentation for subtasks)
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
                $taskColor = $this.CompletedColor
            } elseif ($level -eq 1) {
                $parentTask = $this.TaskService.GetParentTask($task.Id)
                if ($parentTask) {
                    $taskColor = $this.GetSubtaskColor($parentTask.SubtaskColorTheme)
                } else {
                    $taskColor = $this.SubtaskColor
                }
            } else {
                $taskColor = $this.GetTaskColor($task.ColorTheme)
            }
            
            [void]$sb.Append($taskColor + $task.Title + $this.NormalColor)
        }
        
        # Clear to end of line if requested
        if ($clearToEnd) {
            $contentLength = $this.GetContentLength($task, $level)
            $padding = $this.Width - $contentLength
            [void]$sb.Append(" " * [Math]::Max(0, $padding))
        }
    }
    
    [void] RenderTagContent([System.Text.StringBuilder]$sb, [SimpleTask]$task, [int]$level, [bool]$isLast = $false, [bool]$isSelected = $false) {
        # For subtasks, show tree continuation lines
        if ($level -eq 1) {
            # Render the tree structure columns first
            [void]$sb.Append("   ")  # Status column spacing
            [void]$sb.Append("     ")  # Priority column spacing
            [void]$sb.Append(" " * $this.DateCol)  # Date column spacing
            [void]$sb.Append("   ")  # Arrow column spacing
            
            # Tree continuation: show vertical line unless this subtask is selected OR it's the last one
            if ($isSelected) {
                [void]$sb.Append("       ")  # Same spacing as tree connectors but no symbols
            } elseif ($isLast) {
                [void]$sb.Append("       ")  # No continuation after last subtask
            } else {
                [void]$sb.Append("    │  ")  # Vertical continuation line
            }
        }
        
        if ($task.Tags.Count -gt 0) {
            # For level 0 tasks, need to indent properly
            if ($level -eq 0) {
                $indentSize = $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
                [void]$sb.Append(" " * $indentSize)
            }
            
            # Tags in angle brackets
            [void]$sb.Append($this.TagColor)
            [void]$sb.Append("⟨" + ($task.Tags -join ", ") + "⟩")
            [void]$sb.Append($this.NormalColor)
        }
    }
    
    [int] GetContentLength([SimpleTask]$task, [int]$level) {
        $length = $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
        if ($level -eq 1) {
            $length += 7  # "    └─ "
        }
        
        # Use editing value if this task is being edited
        $isEditingThis = ($this.EditingTask -and $this.EditingTask.Id -eq $task.Id)
        if ($isEditingThis -and $this.EditingField -eq "title") {
            $length += [Math]::Max($task.Title.Length, $this.EditingValue.Length)
        } else {
            $length += $task.Title.Length
        }
        
        return $length
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Handle filter input mode first
        if ($this.FilterInputActive) {
            return $this.HandleFilterInput($key)
        }
        
        # Handle editing mode input second
        if ($this.EditingIndex -ge 0) {
            return $this.HandleEditingInput($key)
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
                        $this.SelectedIndex--
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
                        $this.SelectedIndex++
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
                # Open notes editor
                if ($this.FlatList.Count -gt 0) {
                    $item = $this.FlatList[$this.SelectedIndex]
                    # Edit notes for the selected task (parent or subtask)
                    return $this.EditNotes($item.Task)
                }
                return $true
            }
            ([System.ConsoleKey]::N) {
                # Start inline add new task (same as A key)
                $this.StartInlineAdd()
                return $true
            }
            ([System.ConsoleKey]::S) {
                # Start inline subtask creation
                if ($this.FlatList.Count -gt 0) {
                    $this.StartInlineSubtask()
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
                # Start inline editing of current task
                if ($this.FlatList.Count -gt 0) {
                    $this.StartInlineEdit()
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
            ([System.ConsoleKey]::F4) {
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
                # Open Project Management Screen
                return $this.OpenProjectScreen()
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
                if ($key.KeyChar -eq '/' -and $this.EditingIndex -lt 0) {
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
        $allTasks = $this.TaskService.GetParentTasks()
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
        Write-Host -NoNewline "$($this.HeaderColor)EDITING NOTES: $($task.Title)$($this.NormalColor)"
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
    
    [void] DeleteTask() {
        if ($this.FlatList.Count -eq 0) { return }
        
        $item = $this.FlatList[$this.SelectedIndex]
        
        [Console]::SetCursorPosition(0, $this.Height)
        Write-Host -NoNewline "Delete '$($item.Task.Title)'? (y/N): "
        $confirm = [Console]::ReadKey($true)
        
        if ($confirm.KeyChar -eq 'y' -or $confirm.KeyChar -eq 'Y') {
            $this.TaskService.DeleteTask($item.Task.Id)
            $this.LoadTasks()
        }
    }
    
    # === INLINE EDITING METHODS ===
    
    [void] StartInlineEdit() {
        $item = $this.FlatList[$this.SelectedIndex]
        $this.EditingIndex = $this.SelectedIndex
        $this.EditingTask = $item.Task
        $this.EditingField = "priority"  # Start with priority (leftmost)
        # Preserve existing priority when starting edit
        $priorityChar = switch ($this.EditingTask.Priority) {
            "High" { "h" }
            "Medium" { "m" }
            "Low" { "l" }
            "Today" { "t" }
            default { "" }
        }
        $this.EditingValue = $priorityChar
        $this.EditingCursor = $this.EditingValue.Length
        $this.IsNewTask = $false
    }
    
    [void] StartInlineAdd() {
        # Create a new task and add it temporarily to the end
        $newTask = [SimpleTask]::new("")
        $this.FlatList.Add(@{
            Task = $newTask
            Level = 0
            IsLast = $false
        })
        $this.EditingIndex = $this.FlatList.Count - 1
        $this.EditingTask = $newTask
        $this.EditingField = "title"  # Start with title for immediate input
        $this.EditingValue = ""
        $this.EditingCursor = 0
        $this.SelectedIndex = $this.EditingIndex
        $this.IsNewTask = $true
        $this.EnsureVisible()
    }
    
    [void] StartInlineSubtask() {
        $item = $this.FlatList[$this.SelectedIndex]
        $parentTask = if ($item.Task.IsParent()) { $item.Task } else { $this.TaskService.GetTask($item.Task.ParentId) }
        
        if (-not $parentTask) { return }
        
        # Create a new subtask and add it after the parent's subtasks
        $newSubtask = [SimpleTask]::new("")
        
        # Find the position to insert (after last subtask of this parent)
        $insertIndex = $this.SelectedIndex + 1
        for ($i = $this.SelectedIndex + 1; $i -lt $this.FlatList.Count; $i++) {
            $nextItem = $this.FlatList[$i]
            if ($nextItem.Level -eq 1 -and $this.TaskService.GetParentTask($nextItem.Task.Id).Id -eq $parentTask.Id) {
                $insertIndex = $i + 1
            } else {
                break
            }
        }
        
        $this.FlatList.Insert($insertIndex, @{
            Task = $newSubtask
            Level = 1
            IsLast = $false
        })
        
        $this.EditingIndex = $insertIndex
        $this.EditingTask = $newSubtask
        $this.EditingField = "title"  # Start with title for immediate input
        $this.EditingValue = ""
        $this.EditingCursor = 0
        $this.SelectedIndex = $this.EditingIndex
        $this.IsNewTask = $true
        $this.EnsureVisible()
    }
    
    [bool] HandleEditingInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Enter) {
                # Save immediately when Enter is pressed, regardless of field
                $this.SaveInlineEdit()
                return $true
            }
            ([System.ConsoleKey]::Escape) {
                # Cancel editing
                $this.CancelInlineEdit()
                return $true
            }
            ([System.ConsoleKey]::Tab) {
                # Switch between fields for all tasks (new and existing)
                if ($key.Modifiers -band [System.ConsoleModifiers]::Shift) {
                    $this.PreviousEditField()
                } else {
                    $this.NextEditField()
                }
                return $true
            }
            ([System.ConsoleKey]::Backspace) {
                if ($this.EditingCursor -gt 0) {
                    $this.EditingValue = $this.EditingValue.Remove($this.EditingCursor - 1, 1)
                    $this.EditingCursor--
                }
                return $true
            }
            ([System.ConsoleKey]::Delete) {
                if ($this.EditingCursor -lt $this.EditingValue.Length) {
                    $this.EditingValue = $this.EditingValue.Remove($this.EditingCursor, 1)
                }
                return $true
            }
            ([System.ConsoleKey]::LeftArrow) {
                if ($this.EditingCursor -gt 0) {
                    $this.EditingCursor--
                }
                return $true
            }
            ([System.ConsoleKey]::RightArrow) {
                if ($this.EditingCursor -lt $this.EditingValue.Length) {
                    $this.EditingCursor++
                }
                return $true
            }
            ([System.ConsoleKey]::Home) {
                $this.EditingCursor = 0
                return $true
            }
            ([System.ConsoleKey]::End) {
                $this.EditingCursor = $this.EditingValue.Length
                return $true
            }
            ([System.ConsoleKey]::UpArrow) {
                # Save and move up (like subtasks)
                $this.SaveInlineEdit()
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this.EnsureVisible()
                }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                # Save and move down (like subtasks)
                $this.SaveInlineEdit()
                if ($this.SelectedIndex -lt ($this.FlatList.Count - 1)) {
                    $this.SelectedIndex++
                    $this.EnsureVisible()
                }
                return $true
            }
            default {
                # Add character to editing value with field-specific validation
                if ($key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                    $newValue = $this.EditingValue.Insert($this.EditingCursor, $key.KeyChar)
                    
                    # Validate input based on field type
                    $isValid = $false
                    switch ($this.EditingField) {
                        "status" {
                            # Status: only accept ☐, ■, x, space, or single characters
                            $isValid = $newValue.Length -le 1
                        }
                        "priority" {
                            # Priority: only accept single letter shortcuts (h/m/l/t) - max 1 char
                            $isValid = $newValue.Length -le 1 -and ($newValue -eq "" -or $newValue.ToLower() -match '^[hmlt]$')
                        }
                        "date" {
                            # Date: max 10 chars, allow date formats and shortcuts
                            $isValid = $newValue.Length -le 10 -and 
                                      ($newValue -match '^[\d\-/tmowuehrsna\+]*$' -or $newValue -eq "")
                        }
                        "title" {
                            # Title: reasonable length limit
                            $isValid = $newValue.Length -le 80
                        }
                        "tags" {
                            # Tags: reasonable length limit, allow tag characters
                            $isValid = $newValue.Length -le 100 -and 
                                      ($newValue -match '^[a-zA-Z0-9\-_,\s#]*$' -or $newValue -eq "")
                        }
                        default {
                            $isValid = $true
                        }
                    }
                    
                    if ($isValid) {
                        $this.EditingValue = $newValue
                        $this.EditingCursor++
                    }
                }
                return $true
            }
        }
        return $true
    }
    
    [void] NextEditField() {
        # Save current field value only if something was entered, then move to next field
        switch ($this.EditingField) {
            "priority" {
                # Only update if user entered something
                if ($this.EditingValue.Trim() -ne "") {
                    $this.EditingTask.Priority = $this.ConvertPriorityInput($this.EditingValue)
                }
                $this.EditingField = "date"
                # Preserve existing date when switching fields
                $this.EditingValue = if ($this.EditingTask.DueDate -ne [datetime]::MinValue) { $this.EditingTask.DueDate.ToString("yyyy-MM-dd") } else { "" }
                $this.EditingCursor = $this.EditingValue.Length
            }
            "date" {
                # Only update if user entered something
                if ($this.EditingValue.Trim() -ne "") {
                    $this.EditingTask.DueDate = $this.ConvertDateInput($this.EditingValue)
                }
                $this.EditingField = "title"
                # Preserve existing title when switching fields
                $this.EditingValue = $this.EditingTask.Title
                $this.EditingCursor = $this.EditingValue.Length
            }
            "title" {
                # Only update if user entered something
                if ($this.EditingValue.Trim() -ne "") {
                    $this.EditingTask.Title = $this.EditingValue
                }
                $this.EditingField = "tags"
                # Preserve existing tags when switching fields
                $this.EditingValue = if ($this.EditingTask.Tags.Count -gt 0) { ($this.EditingTask.Tags -join ", ") } else { "" }
                $this.EditingCursor = $this.EditingValue.Length
            }
            "tags" {
                # Only update if user entered something
                if ($this.EditingValue.Trim() -ne "") {
                    $tagParts = $this.EditingValue -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                    $this.EditingTask.Tags = $tagParts
                }
                
                # Always cycle back to priority - consistent behavior
                $this.EditingField = "priority"
                # Preserve existing priority when switching fields
                $priorityChar = switch ($this.EditingTask.Priority) {
                    "High" { "h" }
                    "Medium" { "m" }
                    "Low" { "l" }
                    "Today" { "t" }
                    default { "" }
                }
                $this.EditingValue = $priorityChar
                $this.EditingCursor = $this.EditingValue.Length
            }
        }
    }
    
    [void] PreviousEditField() {
        # Save current field value only if something was entered, then move to previous field
        switch ($this.EditingField) {
            "priority" {
                # Only update if user entered something
                if ($this.EditingValue.Trim() -ne "") {
                    $this.EditingTask.Priority = $this.ConvertPriorityInput($this.EditingValue)
                }
                $this.EditingField = "tags"
                # Preserve existing tags when switching fields
                $this.EditingValue = if ($this.EditingTask.Tags.Count -gt 0) { ($this.EditingTask.Tags -join ", ") } else { "" }
                $this.EditingCursor = $this.EditingValue.Length
            }
            "date" {
                # Only update if user entered something
                if ($this.EditingValue.Trim() -ne "") {
                    $this.EditingTask.DueDate = $this.ConvertDateInput($this.EditingValue)
                }
                $this.EditingField = "priority"
                # Preserve existing priority when switching fields
                $priorityChar = switch ($this.EditingTask.Priority) {
                    "High" { "h" }
                    "Medium" { "m" }
                    "Low" { "l" }
                    "Today" { "t" }
                    default { "" }
                }
                $this.EditingValue = $priorityChar
                $this.EditingCursor = $this.EditingValue.Length
            }
            "title" {
                # Only update if user entered something
                if ($this.EditingValue.Trim() -ne "") {
                    $this.EditingTask.Title = $this.EditingValue
                }
                $this.EditingField = "date"
                # Preserve existing date when switching fields
                $this.EditingValue = if ($this.EditingTask.DueDate -ne [datetime]::MinValue) { $this.EditingTask.DueDate.ToString("yyyy-MM-dd") } else { "" }
                $this.EditingCursor = $this.EditingValue.Length
            }
            "tags" {
                # Only update if user entered something
                if ($this.EditingValue.Trim() -ne "") {
                    $tagParts = $this.EditingValue -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                    $this.EditingTask.Tags = $tagParts
                }
                $this.EditingField = "title"
                # Preserve existing title when switching fields
                $this.EditingValue = $this.EditingTask.Title
                $this.EditingCursor = $this.EditingValue.Length
            }
        }
    }
    
    [void] SaveInlineEdit() {
        # Apply final field value
        switch ($this.EditingField) {
            "title" { $this.EditingTask.Title = $this.EditingValue }
            "priority" { $this.EditingTask.Priority = $this.ConvertPriorityInput($this.EditingValue) }
            "date" {
                $this.EditingTask.DueDate = $this.ConvertDateInput($this.EditingValue)
            }
            "tags" {
                # Parse tags from input
                if ($this.EditingValue) {
                    $tagParts = $this.EditingValue -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                    $this.EditingTask.Tags = $tagParts
                } else {
                    $this.EditingTask.Tags = @()
                }
            }
        }
        
        # Apply current editing value to the appropriate field
        switch ($this.EditingField) {
            "title" { $this.EditingTask.Title = $this.EditingValue.Trim() }
            "priority" { $this.EditingTask.Priority = $this.ConvertPriorityInput($this.EditingValue) }
            "date" { $this.EditingTask.DueDate = $this.ConvertDateInput($this.EditingValue) }
            "tags" {
                if ($this.EditingValue.Trim()) {
                    $tagParts = $this.EditingValue -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                    $this.EditingTask.Tags = $tagParts
                } else {
                    $this.EditingTask.Tags = @()
                }
            }
        }
        
        # Auto-tag for Today priority
        if ($this.EditingTask.Priority -eq "Today" -and -not ($this.EditingTask.Tags -contains "today")) {
            $this.EditingTask.Tags += "today"
        }
        
        # Save to service if we have a title
        if ($this.EditingTask.Title.Trim()) {
            if ($this.IsNewTask) {
                # New task - check if it's a subtask
                $item = $this.FlatList[$this.EditingIndex]
                if ($item.Level -eq 1) {
                    # Find parent task
                    for ($i = $this.EditingIndex - 1; $i -ge 0; $i--) {
                        $parentItem = $this.FlatList[$i]
                        if ($parentItem.Level -eq 0) {
                            $this.TaskService.AddSubtask($parentItem.Task.Id, $this.EditingTask)
                            break
                        }
                    }
                } else {
                    # Regular parent task
                    $this.TaskService.AddTask($this.EditingTask)
                }
            } else {
                # Existing task
                $this.TaskService.UpdateTask($this.EditingTask)
            }
        } else {
            # Empty title, remove if it was a new task
            if ($this.IsNewTask) {
                $this.FlatList.RemoveAt($this.EditingIndex)
            }
        }
        
        $this.EndInlineEdit()
    }
    
    [void] CancelInlineEdit() {
        # Remove new task if it was being added
        if ($this.IsNewTask) {
            $this.FlatList.RemoveAt($this.EditingIndex)
            if ($this.SelectedIndex -ge $this.FlatList.Count) {
                $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
            }
        }
        $this.EndInlineEdit()
    }
    
    [void] EndInlineEdit() {
        $this.EditingIndex = -1
        $this.EditingField = ""
        $this.EditingValue = ""
        $this.EditingCursor = 0
        $this.EditingTask = $null
        $this.IsNewTask = $false
        $this.LoadTasks()  # Refresh the list
    }
    
    [void] PositionCursorForEditing([System.Text.StringBuilder]$sb) {
        if ($this.EditingIndex -lt 0 -or -not $this.EditingTask) {
            return
        }
        
        # Calculate cursor position based on which field is being edited
        $item = $this.FlatList[$this.EditingIndex]
        $level = $item.Level
        $isSelected = ($this.EditingIndex -eq $this.SelectedIndex)
        
        # Find the Y position of this item in the rendered list
        $startY = 3
        $currentY = $startY
        $visibleIndex = -1
        
        for ($i = $this.ScrollTop; $i -lt $this.FlatList.Count; $i++) {
            if ($i -eq $this.EditingIndex) {
                $visibleIndex = $currentY
                break
            }
            $currentY += $this.GetItemHeight($i)
        }
        
        if ($visibleIndex -eq -1) {
            return  # Item not visible
        }
        
        # Calculate cursor X position based on field and level
        $cursorX = 0
        $cursorY = $visibleIndex
        
        if ($isSelected) {
            # Selected item with pillbox - add 1 for pillbox border and position in content line
            $cursorY += 2  # Skip spacer and top border to get to content line
        }
        
        switch ($this.EditingField) {
            "status" {
                # Status field starts at column 0, cursor at beginning
                $cursorX = 0
            }
            "priority" {
                if ($level -eq 0) {
                    # Priority field starts after status column, cursor at EditingCursor position
                    $cursorX = $this.COLUMN_STATUS + $this.EditingCursor
                } else {
                    # Subtask priority appears after tree chars, cursor at EditingCursor position
                    $cursorX = $this.COLUMN_STATUS + $this.COLUMN_PRIORITY + $this.COLUMN_DATE + $this.COLUMN_ARROW + $this.TREE_INDENT + $this.EditingCursor
                }
            }
            "date" {
                if ($level -eq 0) {
                    # Date field starts after status + priority, cursor at EditingCursor position
                    $cursorX = $this.COLUMN_STATUS + $this.COLUMN_PRIORITY + $this.EditingCursor
                } else {
                    # Subtask date appears after priority, cursor at EditingCursor position
                    $priorityWidth = if ($this.EditingTask.Priority) { 2 } else { 0 }
                    $cursorX = $this.COLUMN_STATUS + $this.COLUMN_PRIORITY + $this.COLUMN_DATE + $this.COLUMN_ARROW + $this.TREE_INDENT + $priorityWidth + $this.EditingCursor
                }
            }
            "title" {
                if ($level -eq 0) {
                    # Title starts after all columns, cursor at EditingCursor position
                    $cursorX = $this.COLUMN_STATUS + $this.COLUMN_PRIORITY + $this.COLUMN_DATE + $this.COLUMN_ARROW + $this.EditingCursor
                } else {
                    # Calculate position after tree chars and priority/date for subtasks, cursor at EditingCursor position
                    $baseX = $this.COLUMN_STATUS + $this.COLUMN_PRIORITY + $this.COLUMN_DATE + $this.COLUMN_ARROW + $this.TREE_INDENT
                    # Add priority and date widths if they exist
                    if ($this.EditingTask.Priority) { $baseX += 2 }  # 2 chars for subtask priority
                    if ($this.EditingTask.DueDate -ne [datetime]::MinValue) { $baseX += 6 }  # 6 chars for MM-dd
                    $cursorX = $baseX + $this.EditingCursor
                }
            }
            "tags" {
                # Tags appear in the second line of pillbox (if selected)
                if ($isSelected) {
                    $cursorY += 1  # Move to tags line in pillbox
                    $indentSize = $this.COLUMN_STATUS + $this.COLUMN_PRIORITY + $this.COLUMN_DATE + $this.COLUMN_ARROW
                    if ($level -eq 1) { $indentSize += $this.TREE_INDENT }
                    # Position cursor inside the ⟨⟩ brackets at EditingCursor position: pillbox border + indent + "⟨" + text
                    $cursorX = 1 + $indentSize + 1 + $this.EditingCursor
                }
            }
        }
        
        # Adjust for pillbox border when selected
        if ($isSelected -and $this.EditingField -ne "tags") {
            $cursorX += 1  # Add 1 for left pillbox border
        }
        
        [void]$sb.Append([VT]::MoveTo($cursorX, $cursorY))
    }
    
    [void] OpenProjectTextExport() {
        # ExcelDataFlow export directory
        $excelDataFlowPath = Join-Path (Split-Path $PSScriptRoot -Parent) "ExcelDataFlow"
        
        if (-not (Test-Path $excelDataFlowPath)) {
            [Console]::SetCursorPosition(0, $this.Height)
            Write-Host -NoNewline "ExcelDataFlow directory not found at: $excelDataFlowPath " -ForegroundColor Red
            Write-Host -NoNewline "Press any key to continue..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
            return
        }
        
        # Look for the most recent text export file anywhere in ExcelDataFlow
        $exportFiles = @()
        $searchPatterns = @("*.txt", "*.csv", "*.json", "*.tsv", "*.xml")
        
        # Search root directory and Projects subdirectory recursively
        $searchPaths = @($excelDataFlowPath)
        $projectsDir = Join-Path $excelDataFlowPath "Projects"
        if (Test-Path $projectsDir) {
            $searchPaths += $projectsDir
        }
        
        foreach ($searchPath in $searchPaths) {
            foreach ($pattern in $searchPatterns) {
                $files = Get-ChildItem -Path $searchPath -Filter $pattern -File -Recurse | Where-Object { 
                    $_.Name -like "*Export*" -or $_.Name -like "*export*" 
                }
                $exportFiles += $files
            }
        }
        
        if ($exportFiles.Count -eq 0) {
            [Console]::SetCursorPosition(0, $this.Height)
            Write-Host -NoNewline "No ExcelDataFlow export files found " -ForegroundColor Yellow
            Write-Host -NoNewline "Press any key to continue..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
            return
        }
        
        # Get the most recent export file
        $mostRecentFile = $exportFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        [Console]::SetCursorPosition(0, $this.Height)
        Write-Host -NoNewline "Opening most recent export: $($mostRecentFile.Name) " -ForegroundColor Green
        Write-Host -NoNewline "Press any key to continue..." -ForegroundColor Gray
        [Console]::ReadKey($true) | Out-Null
        
        # Open the file with default system editor
        try {
            if ([System.Environment]::OSVersion.Platform -eq "Unix" -or $env:OS -ne "Windows_NT") {
                # Unix-like systems
                if (Get-Command "xdg-open" -ErrorAction SilentlyContinue) {
                    Start-Process "xdg-open" -ArgumentList "`"$($mostRecentFile.FullName)`""
                } elseif (Get-Command "open" -ErrorAction SilentlyContinue) {
                    Start-Process "open" -ArgumentList "`"$($mostRecentFile.FullName)`""
                } else {
                    # Fallback to common text editors
                    $editors = @("nano", "vim", "vi", "gedit")
                    $foundEditor = $false
                    foreach ($editor in $editors) {
                        if (Get-Command $editor -ErrorAction SilentlyContinue) {
                            Start-Process $editor -ArgumentList "`"$($mostRecentFile.FullName)`""
                            $foundEditor = $true
                            break
                        }
                    }
                    if (-not $foundEditor) {
                        throw "No suitable text editor found"
                    }
                }
            } else {
                # Windows
                Start-Process -FilePath $mostRecentFile.FullName
            }
        } catch {
            [Console]::SetCursorPosition(0, $this.Height)
            Write-Host -NoNewline "Failed to open file: $_ " -ForegroundColor Red
            Write-Host -NoNewline "Press any key to continue..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        }
    }
    
    [void] OpenThemeEditor() {
        # Simple color picker menu for task themes
        if ($this.FlatList.Count -eq 0 -or $this.SelectedIndex -lt 0) {
            return
        }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $selectedTask = $item.Task
        $isSubtask = ($item.Level -eq 1)
        
        # Determine what we're editing
        if ($isSubtask) {
            # Editing subtask colors - get parent task
            $parentTask = $this.TaskService.GetParentTask($selectedTask.Id)
            if (-not $parentTask) { return }
            $currentTheme = $parentTask.SubtaskColorTheme
            $editingTarget = "subtask"
        } else {
            # Editing parent task color
            $currentTheme = $selectedTask.ColorTheme
            $editingTarget = "task"
            $parentTask = $selectedTask
        }
        
        # Build menu string safely
        $themes = @("default", "red", "blue", "green", "purple", "orange", "cyan", "pink")
        $targetText = if ($isSubtask) { "Subtask Color" } else { "Task Color" }
        $menuText = "Choose ${targetText}: "
        
        for ($i = 0; $i -lt $themes.Count; $i++) {
            $theme = $themes[$i]
            # Show appropriate color preview - task color for parents, subtask color for subtasks
            $colorCode = if ($isSubtask) { $this.GetSubtaskColor($theme) } else { $this.GetTaskColor($theme) }
            $number = $i + 1
            $bracket = if ($theme -eq $currentTheme) { "[$number]" } else { " $number " }
            $menuText += "$colorCode$bracket$($this.NormalColor) "
        }
        
        $menuText += " 9:Custom  (ESC:Cancel)"
        
        # Show menu safely
        $menuY = $this.Height - 3
        try {
            [Console]::SetCursorPosition(0, $menuY)
            [Console]::Write($menuText)
            [Console]::CursorVisible = $false
            
            # Wait for user input
            while ($true) {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    
                    if ($key.Key -eq [System.ConsoleKey]::Escape) {
                        break  # Cancel
                    } elseif ($key.KeyChar -ge '1' -and $key.KeyChar -le '8') {
                        # Apply preset color
                        $themeIndex = [int]$key.KeyChar - 49  # Convert '1'-'8' to 0-7
                        $newTheme = $themes[$themeIndex]
                        
                        if ($isSubtask) {
                            # Update subtask colors for parent
                            $parentTask.SubtaskColorTheme = $newTheme
                            $this.TaskService.UpdateTask($parentTask)
                        } else {
                            # Update parent task color
                            $selectedTask.ColorTheme = $newTheme
                            $selectedTask.SubtaskColorTheme = $newTheme
                            $this.TaskService.UpdateTask($selectedTask)
                        }
                        $this.LoadTasks()
                        break
                    } elseif ($key.KeyChar -eq '9') {
                        # Custom RGB editor (Step 3)
                        $this.OpenCustomColorEditor($selectedTask, $isSubtask, $parentTask)
                        break
                    }
                }
                Start-Sleep -Milliseconds 50
            }
        } catch {
            # Graceful fallback on any console error - just cycle to next theme
            $selectedTask.ColorTheme = $this.GetNextTheme($selectedTask.ColorTheme)
            $selectedTask.SubtaskColorTheme = $selectedTask.ColorTheme
            $this.TaskService.UpdateTask($selectedTask)
            $this.LoadTasks()
        } finally {
            # Clear the menu line safely
            try {
                [Console]::SetCursorPosition(0, $menuY)
                [Console]::Write(" " * $this.Width)
            } catch {
                # Ignore cleanup errors
            }
        }
    }
    
    [void] OpenCustomColorEditor([SimpleTask]$task, [bool]$isSubtask = $false, [SimpleTask]$parentTask = $null) {
        # Simple RGB color editor
        $startY = $this.Height - 5
        
        # Start with current color or default
        $r = 128
        $g = 128  
        $b = 255
        
        # Try to extract RGB from current theme if it's a custom color
        $currentColorTheme = if ($isSubtask -and $parentTask) { $parentTask.SubtaskColorTheme } else { $task.ColorTheme }
        if ($currentColorTheme -and $currentColorTheme.StartsWith("custom_")) {
            $parts = $currentColorTheme.Split('_')
            if ($parts.Count -eq 4) {
                try {
                    $r = [int]$parts[1]
                    $g = [int]$parts[2]
                    $b = [int]$parts[3]
                } catch {
                    # Use defaults if parsing fails
                }
            }
        }
        
        $currentField = 0  # 0=R, 1=G, 2=B
        
        try {
            [Console]::CursorVisible = $false
            
            while ($true) {
                # Clear editor area
                for ($i = 0; $i -lt 5; $i++) {
                    [Console]::SetCursorPosition(0, $startY + $i)
                    [Console]::Write(" " * $this.Width)
                }
                
                # Show RGB editor
                [Console]::SetCursorPosition(0, $startY)
                $editorTitle = if ($isSubtask) { "Custom RGB Subtask Color Editor" } else { "Custom RGB Color Editor" }
                [Console]::Write($editorTitle)
                
                # Show RGB fields
                $fields = @("Red  ", "Green", "Blue ")
                $values = @($r, $g, $b)
                
                for ($i = 0; $i -lt 3; $i++) {
                    [Console]::SetCursorPosition(0, $startY + 1 + $i)
                    $highlight = if ($i -eq $currentField) { "`e[7m" } else { "" }
                    $reset = if ($i -eq $currentField) { "`e[0m" } else { "" }
                    [Console]::Write("$($fields[$i]): $highlight$($values[$i].ToString().PadLeft(3))$reset")
                }
                
                # Show color preview
                [Console]::SetCursorPosition(15, $startY + 1)
                $colorCode = "`e[38;2;$r;$g;${b}m"
                [Console]::Write("$colorCode████ Preview$($this.NormalColor)")
                
                # Show help
                [Console]::SetCursorPosition(0, $startY + 4)
                [Console]::Write("↑↓:Adjust ±10  ←→:Switch Field  Enter:Apply  Escape:Cancel")
                
                # Handle input
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    
                    switch ($key.Key) {
                        ([System.ConsoleKey]::Escape) {
                            return  # Cancel
                        }
                        ([System.ConsoleKey]::Enter) {
                            # Apply custom color
                            $customTheme = "custom_${r}_${g}_$b"
                            
                            # Add to color dictionaries
                            $this.TaskColors[$customTheme] = "`e[38;2;$r;$g;${b}m"
                            $this.SubtaskColors[$customTheme] = "`e[38;2;$([Math]::Max(0,$r-40));$([Math]::Max(0,$g-40));$([Math]::Max(0,$b-40))m"
                            
                            # Apply to appropriate target
                            if ($isSubtask -and $parentTask) {
                                # Update subtask colors for parent
                                $parentTask.SubtaskColorTheme = $customTheme
                                $this.TaskService.UpdateTask($parentTask)
                            } else {
                                # Update parent task color
                                $task.ColorTheme = $customTheme
                                $task.SubtaskColorTheme = $customTheme
                                $this.TaskService.UpdateTask($task)
                            }
                            $this.LoadTasks()
                            return
                        }
                        ([System.ConsoleKey]::LeftArrow) {
                            $currentField = ($currentField + 2) % 3  # Previous field
                        }
                        ([System.ConsoleKey]::RightArrow) {
                            $currentField = ($currentField + 1) % 3  # Next field
                        }
                        ([System.ConsoleKey]::UpArrow) {
                            # Increase current field
                            switch ($currentField) {
                                0 { $r = [Math]::Min(255, $r + 10) }
                                1 { $g = [Math]::Min(255, $g + 10) }
                                2 { $b = [Math]::Min(255, $b + 10) }
                            }
                        }
                        ([System.ConsoleKey]::DownArrow) {
                            # Decrease current field
                            switch ($currentField) {
                                0 { $r = [Math]::Max(0, $r - 10) }
                                1 { $g = [Math]::Max(0, $g - 10) }
                                2 { $b = [Math]::Max(0, $b - 10) }
                            }
                        }
                    }
                }
                
                Start-Sleep -Milliseconds 50
            }
        } catch {
            # Graceful fallback on any error
        } finally {
            # Clear editor area
            try {
                for ($i = 0; $i -lt 5; $i++) {
                    [Console]::SetCursorPosition(0, $startY + $i)
                    [Console]::Write(" " * $this.Width)
                }
            } catch {
                # Ignore cleanup errors
            }
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
        $projectScreen.SetServices($this.TaskService, $this.ThemeService)
        $projectScreen.SetParentTask($parentTask)
        $projectScreen.SetBounds(0, 0, $this.Width, $this.Height)
        
        # Show the screen - this will handle all input until user returns
        $projectScreen.Show()
        
        # When we return, reload tasks in case anything changed
        $this.LoadTasks()
        
        return $true
    }
}
