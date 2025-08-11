# TimeEntryScreen.ps1 - Dedicated time entry screen with EventBus integration
# Extracted from TaskListScreen.ps1 to provide clean separation of concerns

class TimeEntryScreen {
    [TimeTrackingService]$TimeService = $null
    [KeyMappingService]$KeyService = $null
    [SimpleTimeEntry[]]$TimeEntries = @()
    [hashtable]$TaskLookup = @{}  # ID2 → SimpleTask mapping
    [object]$AppReference = $null
    
    # Screen dimensions
    [int]$Width
    [int]$Height
    
    # Status messages
    [string]$StatusMessage = ""
    [datetime]$StatusMessageTime = [DateTime]::MinValue
    
    # Time entry display state
    [System.Collections.Generic.List[object]]$TimeFlatList
    [int]$TimeSelectedIndex = 0
    [int]$TimeScrollTop = 0
    [int]$TimeEditingIndex = -1
    [string]$TimeEditingField = ""
    [string]$TimeEditingValue = ""
    [SimpleTimeEntry]$TimeEditingEntry = $null
    [bool]$IsNewTimeEntry = $false
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
    
    TimeEntryScreen() {
        $this.TimeFlatList = [System.Collections.Generic.List[object]]::new()
        $this.TimeEntries = @()
        $this.TaskLookup = @{}
        
        # Initialize services
        try {
            $this.TimeService = [TimeTrackingService]::new()
            $this.KeyService = [KeyMappingService]::new()
            if ($this.TimeService) {
                $this.BuildTaskLookup()
                $this.LoadTimeEntries()
            }
        } catch {
            Write-Host "Warning: Could not initialize TimeTrackingService: $_" -ForegroundColor Yellow
            $this.TimeService = $null
        }
    }
    
    [void] SetAppReference($appRef) {
        $this.AppReference = $appRef
    }
    
    [void] BuildTaskLookup() {
        if (-not $this.AppReference -or -not $this.AppReference.TaskScreen -or -not $this.AppReference.TaskScreen.TaskService) {
            # Initialize empty lookup if services aren't available yet
            $this.TaskLookup = @{}
            return
        }
        
        try {
            $this.TaskLookup.Clear()
            $allTasks = $this.AppReference.TaskScreen.TaskService.GetAllTasks()
            
            foreach ($task in $allTasks) {
                if ($task.ID2) {
                    $this.TaskLookup[$task.ID2] = $task
                }
            }
        } catch {
            Write-Host "Warning: Could not build task lookup: $_" -ForegroundColor Yellow  
            $this.TaskLookup = @{}
        }
    }
    
    [void] LoadTimeEntries() {
        if (-not $this.TimeService) { 
            $this.TimeEntries = @()
            $this.BuildTimeFlatList()
            return 
        }
        
        try {
            $allEntries = $this.TimeService.GetCurrentWeekEntries()
        } catch {
            Write-Host "Warning: Could not load time entries: $_" -ForegroundColor Yellow
            $allEntries = @()
        }
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
    
    [void] Initialize([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
    }
    
    [string] Render() {
        try {
            "DEBUG: Starting TimeEntry Render... $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            
            $sb = [System.Text.StringBuilder]::new()
            
            # Clear screen
            [void]$sb.Append([VT]::Clear())
            [void]$sb.Append([VT]::MoveTo(0, 0))
            
            # Render time entry mode content
            $baseContent = $this.RenderTimeEntryMode()
            [void]$sb.Append($baseContent)
            
            # Status bar
            [void]$sb.Append([VT]::MoveTo(0, $this.Height - 2))
            [void]$sb.Append([VT]::ClearLine())
            [void]$sb.Append([AppThemeManager]::GetColor("Background"))
            [void]$sb.Append(" ↑↓:Navigate  E:Edit  N:New  T:Filter  F4:Back  F5:Commands  F6:Excel  Q:Quit")
            
            # Status message if present
            if ($this.StatusMessage -and ([DateTime]::Now - $this.StatusMessageTime).TotalSeconds -lt 5) {
                [void]$sb.Append([VT]::MoveTo(0, $this.Height - 1))
                [void]$sb.Append([VT]::ClearLine())
                [void]$sb.Append([AppThemeManager]::GetColor("Success"))
                [void]$sb.Append(" $($this.StatusMessage)")
                [void]$sb.Append([AppThemeManager]::GetColor("Reset"))
            }
            
            "DEBUG: TimeEntry Render completed successfully $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            return $sb.ToString()
        } catch {
            "ERROR in TimeEntry Render: $_ $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            return "[Error rendering time entry screen: $_]"
        }
    }
    
    [string] RenderTimeEntryMode() {
        try {
            "DEBUG: Starting RenderTimeEntryMode... $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            
            $sb = [System.Text.StringBuilder]::new()
            
            # Safety check - if TimeService failed to initialize, show error message
            if (-not $this.TimeService) {
                [void]$sb.Append([VT]::MoveTo(0, 0))
                try {
                    [void]$sb.Append([AppThemeManager]::GetColor("Error"))
                } catch {
                    # AppThemeManager might also be null, just use plain text
                }
                [void]$sb.Append("Time Entry Service Not Available")
                try {
                    [void]$sb.Append([AppThemeManager]::GetColor("Reset"))
                } catch {
                    # Ignore if AppThemeManager is not available
                }
                [void]$sb.Append([VT]::MoveTo(0, 2))
                [void]$sb.Append("TimeTrackingService failed to initialize.")
                [void]$sb.Append([VT]::MoveTo(0, 3))
                [void]$sb.Append("Press F4 to return to Tasks.")
                return $sb.ToString()
            }
            
            # Header
            "DEBUG: About to render header... $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            [void]$sb.Append([VT]::MoveTo(0, 0))
            [void]$sb.Append([AppThemeManager]::GetColor("Header"))
            "DEBUG: Getting week ending date... $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            $weekEnding = if ($this.TimeService.CurrentWeekFriday) { 
                $this.TimeService.CurrentWeekFriday.ToString('yyyy-MM-dd')
            } else { 
                "Not Available" 
            }
            "DEBUG: Week ending: $weekEnding $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            [void]$sb.Append("Time Entry - Week ending: $weekEnding")
            [void]$sb.Append([AppThemeManager]::GetColor("Reset"))
            "DEBUG: Header rendered successfully $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            
            if ($this.IsTimeFilterActive) {
                [void]$sb.Append(" [FILTERED - only entries with time]")
            } else {
                [void]$sb.Append(" [ALL PROJECTS]")
            }
            
            # Time entry table headers
            "DEBUG: About to render table headers... $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            [void]$sb.Append([VT]::MoveTo(0, 2))
            [void]$sb.Append([AppThemeManager]::GetColor("Header"))
            [void]$sb.Append("Task".PadRight($this.NameCol))
            [void]$sb.Append("Code".PadRight($this.ID1Col))
            [void]$sb.Append("Project".PadRight($this.ID2Col))
            [void]$sb.Append("Mon".PadRight($this.MonCol))
            [void]$sb.Append("Tue".PadRight($this.TueCol))
            [void]$sb.Append("Wed".PadRight($this.WedCol))
            [void]$sb.Append("Thu".PadRight($this.ThuCol))
            [void]$sb.Append("Fri".PadRight($this.FriCol))
            [void]$sb.Append("Total".PadRight($this.TotalCol))
            [void]$sb.Append([AppThemeManager]::GetColor("Reset"))
            "DEBUG: Table headers rendered successfully $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            
            # Time entries
            "DEBUG: About to render time entries... TimeFlatList.Count = $($this.TimeFlatList.Count) $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            $startRow = 4
            $maxRows = $this.Height - 6
            $endIndex = [Math]::Min($this.TimeScrollTop + $maxRows, $this.TimeFlatList.Count)
            
            for ($i = $this.TimeScrollTop; $i -lt $endIndex; $i++) {
                "DEBUG: Rendering entry $i of $($this.TimeFlatList.Count) $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
                $row = $startRow + ($i - $this.TimeScrollTop)
                $item = $this.TimeFlatList[$i]
                if (-not $item) {
                    "DEBUG: Item $i is null! $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
                    continue
                }
                $entry = $item.Entry
                if (-not $entry) {
                    "DEBUG: Entry for item $i is null! $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
                    continue
                }
                $isSelected = ($i -eq $this.TimeSelectedIndex)
                
                [void]$sb.Append([VT]::MoveTo(0, $row - 1))
                
                if ($isSelected) {
                    # Add pillbox for selected item
                    [void]$sb.Append([AppThemeManager]::GetColor("Selection"))
                    [void]$sb.Append("╭")
                    [void]$sb.Append("─" * ($this.Width - 2))
                    [void]$sb.Append("╮")
                    [void]$sb.Append([VT]::MoveTo(0, $row))
                    [void]$sb.Append("│ ")
                } else {
                    [void]$sb.Append([AppThemeManager]::GetColor("Text"))
                    [void]$sb.Append("  ") # Indent for non-selected items
                }
                
                "DEBUG: About to call RenderTimeContent for entry $i $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
                $this.RenderTimeContent($sb, $entry, $isSelected)
                "DEBUG: RenderTimeContent completed for entry $i $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
                
                if ($isSelected) {
                    # Close pillbox
                    [void]$sb.Append(" │")
                    [void]$sb.Append([VT]::MoveTo(0, $row + 1))
                    [void]$sb.Append("╰")
                    [void]$sb.Append("─" * ($this.Width - 2))
                    [void]$sb.Append("╯")
                }
                
                [void]$sb.Append([AppThemeManager]::GetColor("Reset"))
            }
            
            "DEBUG: Time entries loop completed $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            
            # Position cursor if editing
            "DEBUG: About to call PositionTimeEntryCursor $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            $this.PositionTimeEntryCursor($sb)
            "DEBUG: PositionTimeEntryCursor completed $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            
            "DEBUG: About to return from RenderTimeEntryMode $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            return $sb.ToString()
            
            "DEBUG: RenderTimeEntryMode completed successfully $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        } catch {
            "ERROR in RenderTimeEntryMode: $_ $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            return "[Error rendering time entry mode: $_]"
        }
    }
    
    [void] RenderTimeContent([System.Text.StringBuilder]$sb, [SimpleTimeEntry]$entry, [bool]$isSelected) {
        "DEBUG: RenderTimeContent - entry is null: $($entry -eq $null) $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        if (-not $entry) {
            "DEBUG: Entry is null, skipping render $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            return
        }
        
        # Task name (truncated to fit column)
        "DEBUG: About to get Description property $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        $description = if ($entry.Description) { $entry.Description } else { "" }
        "DEBUG: Description = '$description' $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        $taskName = if ($description.Length -gt $this.NameCol - 1) {
            $description.Substring(0, $this.NameCol - 4) + "..."
        } else {
            $description.PadRight($this.NameCol)
        }
        [void]$sb.Append($taskName)
        "DEBUG: Task name rendered $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        
        # ID1 (Project Code)
        $id1Display = if ($entry.ID1Display) { $entry.ID1Display } else { "" }
        [void]$sb.Append($id1Display.PadRight($this.ID1Col))
        "DEBUG: ID1 rendered $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        
        # ID2 (Project Code or Time Code)
        $id2Display = if ($entry.ProjectCode) { $entry.ProjectCode } else { "" }
        [void]$sb.Append($id2Display.PadRight($this.ID2Col))
        "DEBUG: ID2 rendered $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        
        # Days and totals
        "DEBUG: About to render day columns $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        $this.RenderTimeDayColumn($sb, $entry, "Monday", $entry.Monday, $this.MonCol, $isSelected -and $this.TimeEditingField -eq "Monday")
        "DEBUG: Monday rendered $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        $this.RenderTimeDayColumn($sb, $entry, "Tuesday", $entry.Tuesday, $this.TueCol, $isSelected -and $this.TimeEditingField -eq "Tuesday")
        "DEBUG: Tuesday rendered $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        $this.RenderTimeDayColumn($sb, $entry, "Wednesday", $entry.Wednesday, $this.WedCol, $isSelected -and $this.TimeEditingField -eq "Wednesday")
        "DEBUG: Wednesday rendered $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        $this.RenderTimeDayColumn($sb, $entry, "Thursday", $entry.Thursday, $this.ThuCol, $isSelected -and $this.TimeEditingField -eq "Thursday")
        "DEBUG: Thursday rendered $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        $this.RenderTimeDayColumn($sb, $entry, "Friday", $entry.Friday, $this.FriCol, $isSelected -and $this.TimeEditingField -eq "Friday")
        "DEBUG: Friday rendered $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        
        # Total column
        $total = if ($entry.Total) { $entry.Total } else { 0 }
        $totalDisplay = if ($total -gt 0) { [string]::Format("{0:F1}", $total) } else { "" }
        [void]$sb.Append($totalDisplay.PadRight($this.TotalCol))
        "DEBUG: Total rendered $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
    }
    
    [void] RenderTimeDayColumn([System.Text.StringBuilder]$sb, [SimpleTimeEntry]$entry, [string]$dayName, [decimal]$hours, [int]$colWidth, [bool]$isEditingThis) {
        $display = if ($hours -gt 0) { [string]::Format("{0:F1}", $hours) } else { "" }
        
        if ($isEditingThis) {
            [void]$sb.Append([AppThemeManager]::GetColor("EditHighlight"))
            [void]$sb.Append("[$($this.TimeEditingValue)]".PadRight($colWidth))
            [void]$sb.Append([AppThemeManager]::GetColor("Selection"))
        } else {
            [void]$sb.Append($display.PadRight($colWidth))
        }
    }
    
    [void] PositionTimeEntryCursor([System.Text.StringBuilder]$sb) {
        if ($this.TimeEditingIndex -ne -1 -and $this.TimeEditingField) {
            $row = 4 + ($this.TimeEditingIndex - $this.TimeScrollTop)
            $col = $this.NameCol + $this.ID1Col + $this.ID2Col + 1
            
            # Calculate column position based on field
            switch ($this.TimeEditingField.ToLower()) {
                "monday" { $col += 0 }
                "tuesday" { $col += $this.MonCol }
                "wednesday" { $col += $this.MonCol + $this.TueCol }
                "thursday" { $col += $this.MonCol + $this.TueCol + $this.WedCol }
                "friday" { $col += $this.MonCol + $this.TueCol + $this.WedCol + $this.ThuCol }
            }
            
            [void]$sb.Append([VT]::MoveTo($col + $this.TimeEditingValue.Length, $row - 1))
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Use KeyMappingService for navigation
        if ($this.KeyService.MatchesAction($key, "NavigateToTimeEntry") -or $this.KeyService.MatchesAction($key, "NavigateToTimeEntryAlt")) {
            "DEBUG: F4 back navigation pressed in TimeEntryScreen $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            [EventBus]::Publish("NavigateBack")
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "NavigateToCommands") -or $this.KeyService.MatchesAction($key, "NavigateToCommandsAlt")) {
            [EventBus]::Publish("NavigateTo", "Commands")
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "NavigateToExcel")) {
            [EventBus]::Publish("NavigateTo", "Excel")
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "NavigateBack")) {
            [EventBus]::Publish("ApplicationExit")
            return $true
        }
        
        return $this.HandleTimeEntryInput($key)
    }
    
    [bool] HandleTimeEntryInput([System.ConsoleKeyInfo]$key) {
        if ($this.TimeFlatList.Count -eq 0) {
            return $true  # Nothing to do
        }
        
        # Handle editing mode
        if ($this.TimeEditingIndex -ne -1) {
            return $this.HandleTimeEditingInput($key)
        }
        
        # Use KeyMappingService for time entry navigation and commands
        if ($this.KeyService.MatchesAction($key, "MoveUp")) {
            if ($this.TimeSelectedIndex -gt 0) {
                $this.TimeSelectedIndex--
                $this.EnsureTimeEntryVisible()
            }
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "MoveDown")) {
            if ($this.TimeSelectedIndex -lt $this.TimeFlatList.Count - 1) {
                $this.TimeSelectedIndex++
                $this.EnsureTimeEntryVisible()
            }
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "DeleteTask")) {
            $this.DeleteTimeEntry()
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "StartTimeEdit")) {
            $this.StartTimeEntryEdit()
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "NewTimeEntry")) {
            $this.StartProjectTimeEntry()
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "ToggleTimeFilter")) {
            $this.IsTimeFilterActive = -not $this.IsTimeFilterActive
            $this.LoadTimeEntries()
            $this.StatusMessage = if ($this.IsTimeFilterActive) { "Filter: ON (entries with time only)" } else { "Filter: OFF (all projects)" }
            $this.StatusMessageTime = [DateTime]::Now
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "RefreshTimeEntries")) {
            $this.LoadTimeEntries()
            $this.StatusMessage = "Time entries refreshed"
            $this.StatusMessageTime = [DateTime]::Now
            return $true
        }
        
        return $true
    }
    
    [bool] HandleTimeEditingInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Enter) {
                $this.CommitTimeEdit()
                return $true
            }
            ([System.ConsoleKey]::Escape) {
                $this.CancelTimeEdit()
                return $true
            }
            ([System.ConsoleKey]::Backspace) {
                if ($this.TimeEditingValue.Length -gt 0) {
                    $this.TimeEditingValue = $this.TimeEditingValue.Substring(0, $this.TimeEditingValue.Length - 1)
                }
                return $true
            }
            ([System.ConsoleKey]::Tab) {
                $this.CommitTimeEdit()
                # Move to next day
                $days = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
                $currentIndex = $days.IndexOf($this.TimeEditingField)
                if ($currentIndex -ne -1 -and $currentIndex -lt $days.Count - 1) {
                    $this.StartTimeEditForField($days[$currentIndex + 1])
                } else {
                    $this.IsNewTimeEntry = $false
                    $this.TimeEditingIndex = -1
                }
                return $true
            }
            default {
                # Handle numeric input for time values
                $char = $key.KeyChar
                if ([char]::IsDigit($char) -or $char -eq '.' -or $char -eq ',') {
                    if ($char -eq ',') { $char = '.' }  # Convert comma to decimal point
                    
                    # Validate time format (allow up to 99.9 hours)
                    $newValue = $this.TimeEditingValue + $char
                    if ([decimal]::TryParse($newValue, [ref]$null) -and [decimal]$newValue -le 99.9) {
                        $this.TimeEditingValue = $newValue
                    }
                }
                return $true
            }
        }
        return $true  # Default case
    }
    
    [void] StartTimeEntryEdit() {
        if ($this.TimeFlatList.Count -eq 0 -or $this.TimeSelectedIndex -ge $this.TimeFlatList.Count) {
            return
        }
        
        $item = $this.TimeFlatList[$this.TimeSelectedIndex]
        if (-not $item -or -not $item.Entry) {
            return
        }
        
        $this.TimeEditingEntry = $item.Entry
        $this.TimeEditingIndex = $this.TimeSelectedIndex
        $this.StartTimeEditForField("Monday")
        $this.IsNewTimeEntry = $false
    }
    
    [void] StartTimeEditForField([string]$field) {
        $this.TimeEditingField = $field
        $this.TimeEditingValue = ""
        
        # Pre-populate with existing value
        switch ($field.ToLower()) {
            "monday" { if ($this.TimeEditingEntry.Monday -gt 0) { $this.TimeEditingValue = [string]$this.TimeEditingEntry.Monday } }
            "tuesday" { if ($this.TimeEditingEntry.Tuesday -gt 0) { $this.TimeEditingValue = [string]$this.TimeEditingEntry.Tuesday } }
            "wednesday" { if ($this.TimeEditingEntry.Wednesday -gt 0) { $this.TimeEditingValue = [string]$this.TimeEditingEntry.Wednesday } }
            "thursday" { if ($this.TimeEditingEntry.Thursday -gt 0) { $this.TimeEditingValue = [string]$this.TimeEditingEntry.Thursday } }
            "friday" { if ($this.TimeEditingEntry.Friday -gt 0) { $this.TimeEditingValue = [string]$this.TimeEditingEntry.Friday } }
        }
    }
    
    [void] StartProjectTimeEntry() {
        if ($this.TimeFlatList.Count -eq 0 -or $this.TimeSelectedIndex -ge $this.TimeFlatList.Count) {
            return
        }
        
        $item = $this.TimeFlatList[$this.TimeSelectedIndex]
        if (-not $item -or -not $item.Entry) {
            return
        }
        
        # If this is a placeholder entry (no ID), create a real one
        if ($item.Entry.Id -eq [guid]::Empty) {
            $newEntry = [SimpleTimeEntry]::new()
            $newEntry.ProjectCode = $item.Entry.ProjectCode
            $newEntry.Description = $item.Entry.Description
            $newEntry.ID1Display = $item.Entry.ID1Display
            $newEntry.IsProjectEntry = $true
            $newEntry.WeekEndingFriday = $this.TimeService.CurrentWeekFriday.ToString("yyyyMMdd")
            
            # Add to service and reload
            $this.TimeService.AddTimeEntry($newEntry)
            $this.LoadTimeEntries()
            
            # Find the new entry and select it
            for ($i = 0; $i -lt $this.TimeFlatList.Count; $i++) {
                if ($this.TimeFlatList[$i].Entry.ProjectCode -eq $newEntry.ProjectCode) {
                    $this.TimeSelectedIndex = $i
                    $item = $this.TimeFlatList[$i]
                    break
                }
            }
        }
        
        $this.TimeEditingEntry = $item.Entry
        $this.TimeEditingIndex = $this.TimeSelectedIndex
        $this.StartTimeEditForField("Monday")
        $this.IsNewTimeEntry = $true
    }
    
    [void] CommitTimeEdit() {
        if ($this.TimeEditingEntry -and $this.TimeEditingField) {
            $this.SetTimeEntryDayValue($this.TimeEditingField, $this.TimeEditingValue)
            
            try {
                if ($this.TimeEditingEntry.Id -eq [guid]::Empty -or $this.IsNewTimeEntry) {
                    # New entry
                    $this.TimeService.AddTimeEntry($this.TimeEditingEntry)
                } else {
                    # Update existing
                    $this.TimeService.UpdateTimeEntry($this.TimeEditingEntry)
                }
                
                # Refresh and maintain selection if possible
                if ($this.IsNewTimeEntry) {
                    $this.LoadTimeEntries()
                    # Try to find and select the updated entry
                    for ($i = 0; $i -lt $this.TimeFlatList.Count; $i++) {
                        if ($this.TimeFlatList[$i].Entry.ProjectCode -eq $this.TimeEditingEntry.ProjectCode) {
                            $this.TimeSelectedIndex = $i
                            break
                        }
                    }
                }
            } catch {
                $this.StatusMessage = "Error saving time entry: $_"
                $this.StatusMessageTime = [DateTime]::Now
            }
        }
        
        if ($this.IsNewTimeEntry) {
            # For new entries, don't clear editing state yet - let tab/enter cycle through days
        } else {
            $this.CancelTimeEdit()
        }
    }
    
    [void] CancelTimeEdit() {
        $this.TimeEditingIndex = -1
        $this.TimeEditingField = ""
        $this.TimeEditingValue = ""
        $this.TimeEditingEntry = $null
        $this.IsNewTimeEntry = $false
    }
    
    [void] DeleteTimeEntry() {
        if ($this.TimeFlatList.Count -eq 0 -or $this.TimeSelectedIndex -ge $this.TimeFlatList.Count) {
            return
        }
        
        $item = $this.TimeFlatList[$this.TimeSelectedIndex]
        if ($item -and $item.Entry -and $item.Entry.Id -ne [guid]::Empty) {
            try {
                $this.TimeService.DeleteTimeEntry($item.Entry.Id)
                $this.LoadTimeEntries()
                $this.StatusMessage = "Time entry deleted"
                $this.StatusMessageTime = [DateTime]::Now
                
                # Adjust selection if needed
                if ($this.TimeSelectedIndex -ge $this.TimeFlatList.Count) {
                    $this.TimeSelectedIndex = [Math]::Max(0, $this.TimeFlatList.Count - 1)
                }
            } catch {
                $this.StatusMessage = "Error deleting entry: $_"
                $this.StatusMessageTime = [DateTime]::Now
            }
        }
    }
    
    [void] SetTimeEntryDayValue([string]$dayName, [string]$value) {
        if (-not $this.TimeEditingEntry) {
            return
        }
        
        $decimalValue = 0
        if ([decimal]::TryParse($value, [ref]$decimalValue)) {
            switch ($dayName.ToLower()) {
                "monday" { $this.TimeEditingEntry.Monday = $decimalValue }
                "tuesday" { $this.TimeEditingEntry.Tuesday = $decimalValue }
                "wednesday" { $this.TimeEditingEntry.Wednesday = $decimalValue }
                "thursday" { $this.TimeEditingEntry.Thursday = $decimalValue }
                "friday" { $this.TimeEditingEntry.Friday = $decimalValue }
            }
            
            # Recalculate total
            $this.TimeEditingEntry.Total = $this.TimeEditingEntry.Monday + 
                                          $this.TimeEditingEntry.Tuesday + 
                                          $this.TimeEditingEntry.Wednesday + 
                                          $this.TimeEditingEntry.Thursday + 
                                          $this.TimeEditingEntry.Friday
        }
    }
    
    [void] EnsureTimeEntryVisible() {
        $maxRows = $this.Height - 6
        
        # Adjust scroll if selection is above visible area
        if ($this.TimeSelectedIndex -lt $this.TimeScrollTop) {
            $this.TimeScrollTop = $this.TimeSelectedIndex
        }
        
        # Adjust scroll if selection is below visible area
        if ($this.TimeSelectedIndex -ge $this.TimeScrollTop + $maxRows) {
            $this.TimeScrollTop = $this.TimeSelectedIndex - $maxRows + 1
        }
        
        # Ensure scroll doesn't go negative
        $this.TimeScrollTop = [Math]::Max(0, $this.TimeScrollTop)
    }
}