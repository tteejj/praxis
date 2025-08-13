# TimeEntryScreen.ps1 - Dedicated time entry screen with EventBus integration
# Extracted from TaskListScreen.ps1 to provide clean separation of concerns

class TimeEntryScreen : ListScreen {
    [TimeTrackingService]$TimeService = $null
    [KeyMappingService]$KeyService = $null
    [SimpleTimeEntry[]]$TimeEntries = @()
    [hashtable]$TaskLookup = @{}  # ID2 → SimpleTask mapping
    [SimpleTaskService]$TaskService = $null
    
    # Screen dimensions inherited from BaseListScreen
    # Inherited: [int]$Width
    # Inherited: [int]$Height
    
    # Status messages inherited from BaseListScreen
    # Inherited: [string]$StatusMessage = ""
    # Inherited: [datetime]$StatusMessageTime = [DateTime]::MinValue
    
    # Time entry display state - using base class properties
    # TimeFlatList renamed to FlatList (inherited)
    # Inherited: [System.Collections.Generic.List[object]]$FlatList
    # Inherited: [int]$SelectedIndex = 0 (was TimeSelectedIndex)
    # Inherited: [int]$ScrollTop = 0 (was TimeScrollTop) 
    # Inherited: [int]$EditingIndex = -1 (was TimeEditingIndex)
    # Inherited: [string]$EditingField = "" (was TimeEditingField)
    # Inherited: [string]$EditingValue = "" (was TimeEditingValue)
    # Inherited: [object]$EditingItem = $null (was TimeEditingEntry)
    # Inherited: [bool]$IsNewItem = $false (was IsNewTimeEntry)
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
    
    TimeEntryScreen([ServiceContainer]$services) : base($services) {
        # Inherited: $this.FlatList is initialized by base constructor (was TimeFlatList)
        $this.TimeEntries = @()
        $this.TaskLookup = @{}
        
        # Initialize services (simplified with new architecture)
        try {
            $this.TimeService = [TimeTrackingService]::new()
            $this.KeyService = [KeyMappingService]::new()
            $this.Title = "Time Entries"
            
            if ($this.TimeService) {
                $this.BuildTaskLookup()
                $this.LoadTimeEntries()
            }
        } catch {
            $this.Logger.Error("Could not initialize TimeTrackingService", $_)
            $this.TimeService = $null
        }
    }
    
    
    [void] BuildTaskLookup() {
        if (-not $this.TaskService) {
            # Initialize TaskService if not available yet
            $this.TaskService = $this.Services.GetService("TaskService")
        }
        
        if (-not $this.TaskService) {
            # Initialize empty lookup if services aren't available yet
            $this.TaskLookup = @{}
            return
        }
        
        try {
            $this.TaskLookup.Clear()
            $allTasks = $this.TaskService.GetAllTasks()
            
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
    
    # Implement abstract methods from BaseListScreen
    [void] LoadData() {
        $this.LoadTimeEntries()
    }
    
    [array] BuildFlatList() {
        return $this.BuildFlatListInternal($null)
    }
    
    [array] BuildFlatList([array]$inputEntries) {
        return $this.BuildFlatListInternal($inputEntries)
    }
    
    [array] BuildFlatListInternal([array]$inputEntries) {
        $entryArray = if ($inputEntries) { $inputEntries } else { $this.TimeEntries }
        $newList = [System.Collections.Generic.List[object]]::new()
        
        foreach ($entry in $entryArray) {
            if ($entry) {  # Add null check
                $newList.Add(@{
                    Entry = $entry
                    IsLast = $false
                })
            }
        }
        
        return $newList.ToArray()
    }
    
    [string] RenderItem([object]$item, [int]$index, [bool]$isSelected) {
        $entry = $item.Entry
        return $this.FormatTimeEntryLine($entry, $isSelected)
    }
    
    [string[]] GetEditableFields([object]$item) {
        # For time entries, return the editable day fields
        return @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Description")
    }
    
    [void] SaveItem([object]$item) {
        $entry = if ($item -is [hashtable]) { $item.Entry } else { $item }
        $this.TimeService.SaveTimeEntry($entry)
        $this.TimeService.Save()
    }
    
    [object] CreateNewItem() {
        $newEntry = [SimpleTimeEntry]::new()
        $newEntry.Description = "New Time Entry"
        $newEntry.WeekEndingFriday = $this.TimeService.CurrentWeekFriday.ToString("yyyyMMdd")
        return @{
            Entry = $newEntry
            IsLast = $false
        }
    }
    
    [void] LoadTimeEntries() {
        if (-not $this.TimeService) { 
            $this.TimeEntries = @()
            $this.FlatList = $this.BuildFlatList()
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
        
        $this.FlatList = $this.BuildFlatList()
        "DEBUG: FlatList count after build: $($this.FlatList.Count) $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        
        if ($this.SelectedIndex -ge $this.FlatList.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
        }
    }
    
    
    [string] FormatTimeEntryLine([SimpleTimeEntry]$entry, [bool]$isSelected) {
        $sb = [System.Text.StringBuilder]::new()
        
        # Format the time entry line (simplified version for now)
        [void]$sb.Append($entry.Description.PadRight(25))
        [void]$sb.Append($entry.ProjectCode.PadRight(13))
        [void]$sb.Append($entry.Monday.ToString("0.0").PadLeft(6))
        [void]$sb.Append($entry.Tuesday.ToString("0.0").PadLeft(6))
        [void]$sb.Append($entry.Wednesday.ToString("0.0").PadLeft(6))
        [void]$sb.Append($entry.Thursday.ToString("0.0").PadLeft(6))
        [void]$sb.Append($entry.Friday.ToString("0.0").PadLeft(6))
        [void]$sb.Append($entry.Total.ToString("0.0").PadLeft(6))
        
        return $sb.ToString()
    }
    
    [void] Initialize([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
    }
    
    # Override field access methods for SimpleTimeEntry objects
    [string] GetFieldValue([object]$item, [string]$field) {
        $entry = if ($item -is [hashtable]) { $item.Entry } else { $item }
        
        switch ($field) {
            "Description" { return if ($entry.Description) { $entry.Description } else { "" } }
            "Monday" { return $entry.Monday.ToString("0.0") }
            "Tuesday" { return $entry.Tuesday.ToString("0.0") }
            "Wednesday" { return $entry.Wednesday.ToString("0.0") }
            "Thursday" { return $entry.Thursday.ToString("0.0") }
            "Friday" { return $entry.Friday.ToString("0.0") }
            default { 
                # Call base class method
                $baseMethod = [ListScreen].GetMethod("GetFieldValue")
                return $baseMethod.Invoke($this, @($item, $field))
            }
        }
        return ""
    }
    
    [void] SetFieldValue([object]$item, [string]$field, [string]$value) {
        $entry = if ($item -is [hashtable]) { $item.Entry } else { $item }
        
        switch ($field) {
            "Description" { $entry.Description = $value }
            "Monday" { 
                try { $entry.Monday = [double]$value } catch { $entry.Monday = 0.0 }
            }
            "Tuesday" { 
                try { $entry.Tuesday = [double]$value } catch { $entry.Tuesday = 0.0 }
            }
            "Wednesday" { 
                try { $entry.Wednesday = [double]$value } catch { $entry.Wednesday = 0.0 }
            }
            "Thursday" { 
                try { $entry.Thursday = [double]$value } catch { $entry.Thursday = 0.0 }
            }
            "Friday" { 
                try { $entry.Friday = [double]$value } catch { $entry.Friday = 0.0 }
            }
            default { 
                # Call base class method
                $baseMethod = [ListScreen].GetMethod("SetFieldValue")
                $baseMethod.Invoke($this, @($item, $field, $value))
            }
        }
        
        # Recalculate total
        $entry.Total = $entry.Monday + $entry.Tuesday + $entry.Wednesday + $entry.Thursday + $entry.Friday
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
            "DEBUG: About to render time entries... TimeFlatList.Count = $($this.FlatList.Count) $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
            $startRow = 4
            $maxRows = $this.Height - 6
            $endIndex = [Math]::Min($this.ScrollTop + $maxRows, $this.FlatList.Count)
            
            for ($i = $this.ScrollTop; $i -lt $endIndex; $i++) {
                "DEBUG: Rendering entry $i of $($this.FlatList.Count) $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
                $row = $startRow + ($i - $this.ScrollTop)
                $item = $this.FlatList[$i]
                if (-not $item) {
                    "DEBUG: Item $i is null! $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
                    continue
                }
                $entry = $item.Entry
                if (-not $entry) {
                    "DEBUG: Entry for item $i is null! $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
                    continue
                }
                $isSelected = ($i -eq $this.SelectedIndex)
                
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
        $this.RenderTimeDayColumn($sb, $entry, "Monday", $entry.Monday, $this.MonCol, $isSelected -and $this.EditingField -eq "Monday")
        "DEBUG: Monday rendered $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        $this.RenderTimeDayColumn($sb, $entry, "Tuesday", $entry.Tuesday, $this.TueCol, $isSelected -and $this.EditingField -eq "Tuesday")
        "DEBUG: Tuesday rendered $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        $this.RenderTimeDayColumn($sb, $entry, "Wednesday", $entry.Wednesday, $this.WedCol, $isSelected -and $this.EditingField -eq "Wednesday")
        "DEBUG: Wednesday rendered $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        $this.RenderTimeDayColumn($sb, $entry, "Thursday", $entry.Thursday, $this.ThuCol, $isSelected -and $this.EditingField -eq "Thursday")
        "DEBUG: Thursday rendered $(Get-Date)" | Out-File -FilePath "./debug-timeentry.log" -Append
        $this.RenderTimeDayColumn($sb, $entry, "Friday", $entry.Friday, $this.FriCol, $isSelected -and $this.EditingField -eq "Friday")
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
            [void]$sb.Append("[$($this.EditingValue)]".PadRight($colWidth))
            [void]$sb.Append([AppThemeManager]::GetColor("Selection"))
        } else {
            [void]$sb.Append($display.PadRight($colWidth))
        }
    }
    
    [void] PositionTimeEntryCursor([System.Text.StringBuilder]$sb) {
        if ($this.EditingIndex -ne -1 -and $this.EditingField) {
            $row = 4 + ($this.EditingIndex - $this.ScrollTop)
            $col = $this.NameCol + $this.ID1Col + $this.ID2Col + 1
            
            # Calculate column position based on field
            switch ($this.EditingField.ToLower()) {
                "monday" { $col += 0 }
                "tuesday" { $col += $this.MonCol }
                "wednesday" { $col += $this.MonCol + $this.TueCol }
                "thursday" { $col += $this.MonCol + $this.TueCol + $this.WedCol }
                "friday" { $col += $this.MonCol + $this.TueCol + $this.WedCol + $this.ThuCol }
            }
            
            [void]$sb.Append([VT]::MoveTo($col + $this.EditingValue.Length, $row - 1))
        }
    }
    
    # Override HandleInput to integrate with BaseListScreen editing while preserving time entry logic
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # If BaseListScreen is handling editing, let it handle the input
        if ($this.EditingItem -ne $null) {
            return $this.HandleInput($key)
        }
        
        # Handle navigation keys specific to TimeEntryScreen
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
        if ($this.FlatList.Count -eq 0) {
            return $true  # Nothing to do
        }
        
        # Handle editing mode
        if ($this.EditingIndex -ne -1) {
            return $this.HandleTimeEditingInput($key)
        }
        
        # Use KeyMappingService for time entry navigation and commands
        if ($this.KeyService.MatchesAction($key, "MoveUp")) {
            if ($this.SelectedIndex -gt 0) {
                $this.SelectedIndex--
                $this.EnsureTimeEntryVisible()
            }
            return $true
        }
        
        if ($this.KeyService.MatchesAction($key, "MoveDown")) {
            if ($this.SelectedIndex -lt $this.FlatList.Count - 1) {
                $this.SelectedIndex++
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
                if ($this.EditingValue.Length -gt 0) {
                    $this.EditingValue = $this.EditingValue.Substring(0, $this.EditingValue.Length - 1)
                }
                return $true
            }
            ([System.ConsoleKey]::Tab) {
                $this.CommitTimeEdit()
                # Move to next day
                $days = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
                $currentIndex = $days.IndexOf($this.EditingField)
                if ($currentIndex -ne -1 -and $currentIndex -lt $days.Count - 1) {
                    $this.StartTimeEditForField($days[$currentIndex + 1])
                } else {
                    $this.IsNewItem = $false
                    $this.EditingIndex = -1
                }
                return $true
            }
            default {
                # Handle numeric input for time values
                $char = $key.KeyChar
                if ([char]::IsDigit($char) -or $char -eq '.' -or $char -eq ',') {
                    if ($char -eq ',') { $char = '.' }  # Convert comma to decimal point
                    
                    # Validate time format (allow up to 99.9 hours)
                    $newValue = $this.EditingValue + $char
                    if ([decimal]::TryParse($newValue, [ref]$null) -and [decimal]$newValue -le 99.9) {
                        $this.EditingValue = $newValue
                    }
                }
                return $true
            }
        }
        return $true  # Default case
    }
    
    [void] StartTimeEntryEdit() {
        if ($this.FlatList.Count -eq 0 -or $this.SelectedIndex -ge $this.FlatList.Count) {
            return
        }
        
        $item = $this.FlatList[$this.SelectedIndex]
        if (-not $item -or -not $item.Entry) {
            return
        }
        
        $this.EditingItem = $item.Entry
        $this.EditingIndex = $this.SelectedIndex
        $this.StartTimeEditForField("Monday")
        $this.IsNewItem = $false
    }
    
    [void] StartTimeEditForField([string]$field) {
        $this.EditingField = $field
        $this.EditingValue = ""
        
        # Pre-populate with existing value
        switch ($field.ToLower()) {
            "monday" { if ($this.EditingItem.Monday -gt 0) { $this.EditingValue = [string]$this.EditingItem.Monday } }
            "tuesday" { if ($this.EditingItem.Tuesday -gt 0) { $this.EditingValue = [string]$this.EditingItem.Tuesday } }
            "wednesday" { if ($this.EditingItem.Wednesday -gt 0) { $this.EditingValue = [string]$this.EditingItem.Wednesday } }
            "thursday" { if ($this.EditingItem.Thursday -gt 0) { $this.EditingValue = [string]$this.EditingItem.Thursday } }
            "friday" { if ($this.EditingItem.Friday -gt 0) { $this.EditingValue = [string]$this.EditingItem.Friday } }
        }
    }
    
    [void] StartProjectTimeEntry() {
        if ($this.FlatList.Count -eq 0 -or $this.SelectedIndex -ge $this.FlatList.Count) {
            return
        }
        
        $item = $this.FlatList[$this.SelectedIndex]
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
            for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
                if ($this.FlatList[$i].Entry.ProjectCode -eq $newEntry.ProjectCode) {
                    $this.SelectedIndex = $i
                    $item = $this.FlatList[$i]
                    break
                }
            }
        }
        
        $this.EditingItem = $item.Entry
        $this.EditingIndex = $this.SelectedIndex
        $this.StartTimeEditForField("Monday")
        $this.IsNewItem = $true
    }
    
    [void] CommitTimeEdit() {
        if ($this.EditingItem -and $this.EditingField) {
            $this.SetTimeEntryDayValue($this.EditingField, $this.EditingValue)
            
            try {
                if ($this.EditingItem.Id -eq [guid]::Empty -or $this.IsNewItem) {
                    # New entry
                    $this.TimeService.AddTimeEntry($this.EditingItem)
                } else {
                    # Update existing
                    $this.TimeService.UpdateTimeEntry($this.EditingItem)
                }
                
                # Refresh and maintain selection if possible
                if ($this.IsNewItem) {
                    $this.LoadTimeEntries()
                    # Try to find and select the updated entry
                    for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
                        if ($this.FlatList[$i].Entry.ProjectCode -eq $this.EditingItem.ProjectCode) {
                            $this.SelectedIndex = $i
                            break
                        }
                    }
                }
            } catch {
                $this.StatusMessage = "Error saving time entry: $_"
                $this.StatusMessageTime = [DateTime]::Now
            }
        }
        
        if ($this.IsNewItem) {
            # For new entries, don't clear editing state yet - let tab/enter cycle through days
        } else {
            $this.CancelTimeEdit()
        }
    }
    
    [void] CancelTimeEdit() {
        $this.EditingIndex = -1
        $this.EditingField = ""
        $this.EditingValue = ""
        $this.EditingItem = $null
        $this.IsNewItem = $false
    }
    
    [void] DeleteTimeEntry() {
        if ($this.FlatList.Count -eq 0 -or $this.SelectedIndex -ge $this.FlatList.Count) {
            return
        }
        
        $item = $this.FlatList[$this.SelectedIndex]
        if ($item -and $item.Entry -and $item.Entry.Id -ne [guid]::Empty) {
            try {
                $this.TimeService.DeleteTimeEntry($item.Entry.Id)
                $this.LoadTimeEntries()
                $this.StatusMessage = "Time entry deleted"
                $this.StatusMessageTime = [DateTime]::Now
                
                # Adjust selection if needed
                if ($this.SelectedIndex -ge $this.FlatList.Count) {
                    $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
                }
            } catch {
                $this.StatusMessage = "Error deleting entry: $_"
                $this.StatusMessageTime = [DateTime]::Now
            }
        }
    }
    
    [void] SetTimeEntryDayValue([string]$dayName, [string]$value) {
        if (-not $this.EditingItem) {
            return
        }
        
        $decimalValue = 0
        if ([decimal]::TryParse($value, [ref]$decimalValue)) {
            switch ($dayName.ToLower()) {
                "monday" { $this.EditingItem.Monday = $decimalValue }
                "tuesday" { $this.EditingItem.Tuesday = $decimalValue }
                "wednesday" { $this.EditingItem.Wednesday = $decimalValue }
                "thursday" { $this.EditingItem.Thursday = $decimalValue }
                "friday" { $this.EditingItem.Friday = $decimalValue }
            }
            
            # Recalculate total
            $this.EditingItem.Total = $this.EditingItem.Monday + 
                                          $this.EditingItem.Tuesday + 
                                          $this.EditingItem.Wednesday + 
                                          $this.EditingItem.Thursday + 
                                          $this.EditingItem.Friday
        }
    }
    
    [void] EnsureTimeEntryVisible() {
        $maxRows = $this.Height - 6
        
        # Adjust scroll if selection is above visible area
        if ($this.SelectedIndex -lt $this.ScrollTop) {
            $this.ScrollTop = $this.SelectedIndex
        }
        
        # Adjust scroll if selection is below visible area
        if ($this.SelectedIndex -ge $this.ScrollTop + $maxRows) {
            $this.ScrollTop = $this.SelectedIndex - $maxRows + 1
        }
        
        # Ensure scroll doesn't go negative
        $this.ScrollTop = [Math]::Max(0, $this.ScrollTop)
    }
    
    # Override GetFieldScreenPosition for time entry fields
    [hashtable] GetFieldScreenPosition([string]$field, [int]$cursor, [object]$item) {
        # Simple implementation for time entry screen
        # Y position at row 10 (approximate), different X positions for different fields
        switch ($field) {
            "Description" { return @{ X = 5 + $cursor; Y = 10 } }
            "Monday" { return @{ X = 30 + $cursor; Y = 10 } }
            "Tuesday" { return @{ X = 40 + $cursor; Y = 10 } }
            "Wednesday" { return @{ X = 50 + $cursor; Y = 10 } }
            "Thursday" { return @{ X = 60 + $cursor; Y = 10 } }
            "Friday" { return @{ X = 70 + $cursor; Y = 10 } }
            default { return @{ X = 5 + $cursor; Y = 10 } }
        }
        # Explicit return to satisfy PowerShell
        return @{ X = 5 + $cursor; Y = 10 }
    }
}