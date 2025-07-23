# ProjectDetailScreen - Detailed project view with time tracking information
# Shows comprehensive project data based on tracker.txt structure

class ProjectDetailScreen : Screen {
    [Project]$Project = $null
    [System.Collections.ArrayList]$TimeEntries
    [System.Collections.ArrayList]$UIComponents
    [int]$ScrollOffset = 0
    [int]$MaxScrollOffset = 0
    [ThemeManager]$ThemeManager
    
    # Display sections
    [bool]$ShowProjectInfo = $true
    [bool]$ShowTimeEntries = $true
    [bool]$ShowWeeklySummary = $true
    
    ProjectDetailScreen() : base() {
        $this.Title = "Project Details"
        $this.TimeEntries = [System.Collections.ArrayList]::new()
        $this.UIComponents = [System.Collections.ArrayList]::new()
    }
    
    ProjectDetailScreen([Project]$project) : base() {
        $this.Title = "Project Details - $($project.Nickname)"
        $this.Project = $project
        $this.TimeEntries = [System.Collections.ArrayList]::new()
        $this.UIComponents = [System.Collections.ArrayList]::new()
    }
    
    [void] OnInitialize() {
        # Get theme service
        if ($this.ServiceContainer) {
            $this.ThemeManager = $this.ServiceContainer.GetService('ThemeManager')
        }
        
        # Load time entries if we have a project
        if ($this.Project) {
            $this.LoadTimeEntries()
        }
        
        # Update title
        if ($this.Project) {
            $this.Title = "Project Details - $($this.Project.Nickname)"
        }
    }
    
    [void] LoadTimeEntries() {
        # This would load time entries from the tracker system
        # For now, creating sample data based on the tracker.txt structure
        $this.TimeEntries.Clear()
        
        # Sample time entries (in production, this would load from actual data)
        $sampleEntries = @(
            @{
                Date = "20241201"
                Nickname = $this.Project.Nickname
                ID1 = "CLIENT1"
                ID2 = "V000123456S"
                MonHours = "8.00"
                TueHours = ""
                WedHours = ""
                ThuHours = ""
                FriHours = ""
                Total = "8.00"
                Description = "Initial project setup and requirements gathering"
            },
            @{
                Date = "20241202"
                Nickname = $this.Project.Nickname
                ID1 = "CLIENT1"
                ID2 = "V000123456S"
                MonHours = ""
                TueHours = "6.50"
                WedHours = ""
                ThuHours = ""
                FriHours = ""
                Total = "6.50"
                Description = "Development work on core features"
            },
            @{
                Date = "20241203"
                Nickname = $this.Project.Nickname
                ID1 = "CLIENT1"
                ID2 = "V000123456S"
                MonHours = ""
                TueHours = ""
                WedHours = "7.25"
                ThuHours = ""
                FriHours = ""
                Total = "7.25"
                Description = "Testing and bug fixes"
            }
        )
        
        foreach ($entry in $sampleEntries) {
            $this.TimeEntries.Add([PSCustomObject]$entry) | Out-Null
        }
    }
    
    [void] CalculateScrollLimits() {
        # Calculate how many lines of content we have
        $contentLines = 0
        
        if ($this.ShowProjectInfo) {
            $contentLines += 15  # Project info section
        }
        
        if ($this.ShowWeeklySummary) {
            $contentLines += 8   # Weekly summary section
        }
        
        if ($this.ShowTimeEntries) {
            $contentLines += 3 + $this.TimeEntries.Count  # Header + entries
        }
        
        $visibleLines = $this.Height - 4  # Account for borders and title
        $this.MaxScrollOffset = [Math]::Max(0, $contentLines - $visibleLines)
    }
    
    [string] OnRender() {
        if (-not $this.Project) {
            return $this.RenderNoProject()
        }
        
        $this.CalculateScrollLimits()
        $sb = [System.Text.StringBuilder]::new()
        
        # Get colors
        $headerColor = if ($this.ThemeManager) { $this.ThemeManager.GetColor("title") } else { "" }
        $normalColor = if ($this.ThemeManager) { $this.ThemeManager.GetColor("normal") } else { "" }
        $accentColor = if ($this.ThemeManager) { $this.ThemeManager.GetColor("accent") } else { "" }
        $warningColor = if ($this.ThemeManager) { $this.ThemeManager.GetColor("warning") } else { "" }
        $successColor = if ($this.ThemeManager) { $this.ThemeManager.GetColor("success") } else { "" }
        
        $currentLine = 0
        $visibleLines = $this.Height - 4
        
        # Project Information Section
        if ($this.ShowProjectInfo) {
            $projectLines = $this.RenderProjectInfo($headerColor, $normalColor, $accentColor, $warningColor, $successColor)
            $linesToShow = $this.GetVisibleLines($projectLines, $currentLine, $visibleLines)
            foreach ($line in $linesToShow) {
                $sb.AppendLine($line)
            }
            $currentLine += $projectLines.Count
        }
        
        # Weekly Summary Section
        if ($this.ShowWeeklySummary -and $currentLine -$this.ScrollOffset -lt $visibleLines) {
            $summaryLines = $this.RenderWeeklySummary($headerColor, $normalColor, $accentColor)
            $linesToShow = $this.GetVisibleLines($summaryLines, $currentLine, $visibleLines)
            foreach ($line in $linesToShow) {
                $sb.AppendLine($line)
            }
            $currentLine += $summaryLines.Count
        }
        
        # Time Entries Section
        if ($this.ShowTimeEntries -and $currentLine - $this.ScrollOffset -lt $visibleLines) {
            $entryLines = $this.RenderTimeEntries($headerColor, $normalColor, $accentColor)
            $linesToShow = $this.GetVisibleLines($entryLines, $currentLine, $visibleLines)
            foreach ($line in $linesToShow) {
                $sb.AppendLine($line)
            }
        }
        
        return $sb.ToString()
    }
    
    [System.Collections.ArrayList] GetVisibleLines([System.Collections.ArrayList]$lines, [int]$currentLine, [int]$visibleLines) {
        $visibleList = [System.Collections.ArrayList]::new()
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $lineIndex = $currentLine + $i
            if ($lineIndex -ge $this.ScrollOffset -and ($lineIndex - $this.ScrollOffset) -lt $visibleLines) {
                $visibleList.Add($lines[$i]) | Out-Null
            }
        }
        
        return $visibleList
    }
    
    [System.Collections.ArrayList] RenderProjectInfo([string]$headerColor, [string]$normalColor, [string]$accentColor, [string]$warningColor, [string]$successColor) {
        $lines = [System.Collections.ArrayList]::new()
        
        # Project header
        $lines.Add("$headerColor=== PROJECT INFORMATION ===$normalColor") | Out-Null
        $lines.Add("") | Out-Null
        
        # Basic info
        $lines.Add("$accentColor  Nickname:$normalColor $($this.Project.Nickname)") | Out-Null
        $lines.Add("$accentColor  Full Name:$normalColor $($this.Project.FullProjectName)") | Out-Null
        
        # IDs
        if ($this.Project.ID1) {
            $lines.Add("$accentColor  Client Code (ID1):$normalColor $($this.Project.ID1)") | Out-Null
        }
        if ($this.Project.ID2) {
            $lines.Add("$accentColor  Engagement Code (ID2):$normalColor $($this.Project.ID2)") | Out-Null
        }
        
        $lines.Add("") | Out-Null
        
        # Dates
        if ($this.Project.DateAssigned) {
            $assignedDate = $this.FormatDate($this.Project.DateAssigned)
            $lines.Add("$accentColor  Date Assigned:$normalColor $assignedDate") | Out-Null
        }
        
        if ($this.Project.DateDue) {
            $dueDate = $this.FormatDate($this.Project.DateDue)
            $statusColor = $this.GetDueDateColor($this.Project.DateDue, $warningColor, $successColor, $normalColor)
            $lines.Add("$accentColor  Due Date:$statusColor $dueDate$normalColor") | Out-Null
        }
        
        if ($this.Project.ClosedDate -and $this.Project.ClosedDate -ne [DateTime]::MinValue) {
            $closedDate = $this.FormatDate($this.Project.ClosedDate)
            $lines.Add("$accentColor  Completed:$successColor $closedDate$normalColor") | Out-Null
        }
        
        $lines.Add("") | Out-Null
        
        # Status and hours
        $status = if ($this.Project.Status) { $this.Project.Status } else { "Active" }
        $statusColor = $this.GetStatusColor($status, $successColor, $warningColor, $normalColor)
        $lines.Add("$accentColor  Status:$statusColor $status$normalColor") | Out-Null
        
        # Calculate total hours from time entries
        $totalHours = $this.CalculateTotalHours()
        $lines.Add("$accentColor  Total Hours:$normalColor $($totalHours.ToString('F2'))") | Out-Null
        
        if ($this.Project.Note) {
            $lines.Add("") | Out-Null
            $lines.Add("$accentColor  Notes:$normalColor") | Out-Null
            $lines.Add("    $($this.Project.Note)") | Out-Null
        }
        
        return $lines
    }
    
    [System.Collections.ArrayList] RenderWeeklySummary([string]$headerColor, [string]$normalColor, [string]$accentColor) {
        $lines = [System.Collections.ArrayList]::new()
        
        $lines.Add("") | Out-Null
        $lines.Add("$headerColor=== WEEKLY HOURS SUMMARY ===$normalColor") | Out-Null
        $lines.Add("") | Out-Null
        
        # Create weekly summary from time entries
        $weeklyData = $this.CalculateWeeklySummary()
        
        # Header row
        $header = "  Week of".PadRight(15) + "Mon".PadLeft(8) + "Tue".PadLeft(8) + "Wed".PadLeft(8) + "Thu".PadLeft(8) + "Fri".PadLeft(8) + "Total".PadLeft(10)
        $lines.Add("$accentColor$header$normalColor") | Out-Null
        $lines.Add("  " + ("-" * 75)) | Out-Null
        
        # Data rows
        foreach ($week in $weeklyData) {
            $weekStr = $week.WeekOf.PadRight(15)
            $monStr = $week.Monday.ToString("F1").PadLeft(8)
            $tueStr = $week.Tuesday.ToString("F1").PadLeft(8)
            $wedStr = $week.Wednesday.ToString("F1").PadLeft(8)
            $thuStr = $week.Thursday.ToString("F1").PadLeft(8)
            $friStr = $week.Friday.ToString("F1").PadLeft(8)
            $totalStr = $week.Total.ToString("F1").PadLeft(10)
            
            $lines.Add("  $weekStr$monStr$tueStr$wedStr$thuStr$friStr$totalStr") | Out-Null
        }
        
        return $lines
    }
    
    [System.Collections.ArrayList] RenderTimeEntries([string]$headerColor, [string]$normalColor, [string]$accentColor) {
        $lines = [System.Collections.ArrayList]::new()
        
        $lines.Add("") | Out-Null
        $lines.Add("$headerColor=== TIME ENTRIES ===$normalColor") | Out-Null
        $lines.Add("  $accentColor[A]$normalColor Add Entry  $accentColor[E]$normalColor Edit  $accentColor[D]$normalColor Delete  $accentColor[R]$normalColor Refresh") | Out-Null
        $lines.Add("") | Out-Null
        
        if ($this.TimeEntries.Count -eq 0) {
            $lines.Add("  No time entries found. Press 'A' to add your first entry.") | Out-Null
            return $lines
        }
        
        # Sort entries by date (most recent first)
        $sortedEntries = $this.TimeEntries | Sort-Object { [DateTime]::ParseExact($_.Date, "yyyyMMdd", $null) } -Descending
        
        foreach ($entry in $sortedEntries) {
            $date = $this.FormatDate($entry.Date)
            $hours = [double]::Parse($entry.Total).ToString("F2")
            $description = if ($entry.Description) { $entry.Description } else { "No description" }
            
            $lines.Add("  $accentColor$date$normalColor - $hours hrs") | Out-Null
            $lines.Add("    $description") | Out-Null
            $lines.Add("") | Out-Null
        }
        
        $lines.Add("  Total Entries: $($sortedEntries.Count)") | Out-Null
        
        return $lines
    }
    
    [string] RenderNoProject() {
        return "No project selected for detailed view."
    }
    
    [string] FormatDate([string]$dateStr) {
        if ([string]::IsNullOrEmpty($dateStr)) {
            return "Not set"
        }
        
        try {
            if ($dateStr.Length -eq 8) {
                # YYYYMMDD format
                $date = [DateTime]::ParseExact($dateStr, "yyyyMMdd", $null)
                return $date.ToString("MM/dd/yyyy")
            } else {
                # Try parsing as DateTime
                $date = [DateTime]::Parse($dateStr)
                return $date.ToString("MM/dd/yyyy")
            }
        } catch {
            return $dateStr
        }
    }
    
    [string] FormatDate([DateTime]$date) {
        if ($date -eq [DateTime]::MinValue) {
            return "Not set"
        }
        return $date.ToString("MM/dd/yyyy")
    }
    
    [string] GetDueDateColor([string]$dueDateStr, [string]$warningColor, [string]$successColor, [string]$normalColor) {
        try {
            if ([string]::IsNullOrEmpty($dueDateStr)) {
                return $normalColor
            }
            
            $dueDate = if ($dueDateStr.Length -eq 8) {
                [DateTime]::ParseExact($dueDateStr, "yyyyMMdd", $null)
            } else {
                [DateTime]::Parse($dueDateStr)
            }
            
            $today = [DateTime]::Now.Date
            $daysUntilDue = ($dueDate.Date - $today).Days
            
            if ($daysUntilDue -lt 0) {
                return $warningColor  # Overdue
            } elseif ($daysUntilDue -le 7) {
                return $warningColor  # Due soon
            } else {
                return $successColor  # On track
            }
        } catch {
            return $normalColor
        }
    }
    
    [string] GetDueDateColor([DateTime]$dueDate, [string]$warningColor, [string]$successColor, [string]$normalColor) {
        if ($dueDate -eq [DateTime]::MinValue) {
            return $normalColor
        }
        
        $today = [DateTime]::Now.Date
        $daysUntilDue = ($dueDate.Date - $today).Days
        
        if ($daysUntilDue -lt 0) {
            return $warningColor  # Overdue
        } elseif ($daysUntilDue -le 7) {
            return $warningColor  # Due soon
        } else {
            return $successColor  # On track
        }
    }
    
    [string] GetStatusColor([string]$status, [string]$successColor, [string]$warningColor, [string]$normalColor) {
        switch ($status.ToLower()) {
            "completed" { return $successColor }
            "closed" { return $successColor }
            "on hold" { return $warningColor }
            "active" { return $normalColor }
            default { return $normalColor }
        }
        return $normalColor  # Explicit fallback
    }
    
    [double] CalculateTotalHours() {
        $total = 0.0
        foreach ($entry in $this.TimeEntries) {
            try {
                $hours = [double]::Parse($entry.Total)
                $total += $hours
            } catch {
                # Skip invalid entries
            }
        }
        return $total
    }
    
    [System.Collections.ArrayList] CalculateWeeklySummary() {
        $weeks = @{}
        
        foreach ($entry in $this.TimeEntries) {
            try {
                $entryDate = [DateTime]::ParseExact($entry.Date, "yyyyMMdd", $null)
                $monday = $entryDate.AddDays(-([int]$entryDate.DayOfWeek - 1))
                $weekKey = $monday.ToString("MM/dd/yyyy")
                
                if (-not $weeks.ContainsKey($weekKey)) {
                    $weeks[$weekKey] = @{
                        WeekOf = $weekKey
                        Monday = 0.0
                        Tuesday = 0.0
                        Wednesday = 0.0
                        Thursday = 0.0
                        Friday = 0.0
                        Total = 0.0
                    }
                }
                
                # Add hours to appropriate day
                $dayOfWeek = $entryDate.DayOfWeek.ToString()
                $hours = [double]::Parse($entry.Total)
                
                switch ($dayOfWeek) {
                    "Monday" { $weeks[$weekKey].Monday += $hours }
                    "Tuesday" { $weeks[$weekKey].Tuesday += $hours }
                    "Wednesday" { $weeks[$weekKey].Wednesday += $hours }
                    "Thursday" { $weeks[$weekKey].Thursday += $hours }
                    "Friday" { $weeks[$weekKey].Friday += $hours }
                }
                
                $weeks[$weekKey].Total += $hours
            } catch {
                # Skip invalid entries
            }
        }
        
        $weeklyData = [System.Collections.ArrayList]::new()
        foreach ($week in $weeks.Values) {
            $weeklyData.Add([PSCustomObject]$week) | Out-Null
        }
        
        # Sort by week date
        return $weeklyData | Sort-Object { [DateTime]::Parse($_.WeekOf) } -Descending
    }
    
    [void] AddTimeEntry() {
        if (-not $this.Project) {
            return
        }
        
        # Create time entry dialog
        $dialog = [TimeEntryDialog]::new($this.Project)
        
        # Set up callback for when entry is saved
        $screen = $this  # Capture reference for closure
        $dialog.OnSave = {
            param($timeEntryData)
            
            # In a full implementation, this would save to actual data store
            # For now, add to our local time entries collection
            $screen.TimeEntries.Add($timeEntryData) | Out-Null
            $screen.Invalidate()
            
            # Close dialog
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }.GetNewClosure()
        
        $dialog.OnCancel = {
            # Close dialog
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }
        
        # Show dialog
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] EditTimeEntry([PSCustomObject]$timeEntry) {
        if (-not $this.Project -or -not $timeEntry) {
            return
        }
        
        # Create edit time entry dialog
        $dialog = [TimeEntryDialog]::new($this.Project, $timeEntry)
        
        # Set up callback for when entry is updated
        $screen = $this  # Capture reference for closure
        $dialog.OnSave = {
            param($timeEntryData)
            
            # In a full implementation, this would update the actual data store
            # For now, find and replace in our local collection
            for ($i = 0; $i -lt $screen.TimeEntries.Count; $i++) {
                if ($screen.TimeEntries[$i].Date -eq $timeEntry.Date -and
                    $screen.TimeEntries[$i].Description -eq $timeEntry.Description) {
                    $screen.TimeEntries[$i] = $timeEntryData
                    break
                }
            }
            $screen.Invalidate()
            
            # Close dialog
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }.GetNewClosure()
        
        $dialog.OnCancel = {
            # Close dialog
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }
        
        # Show dialog
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] DeleteTimeEntry([PSCustomObject]$timeEntry) {
        if (-not $timeEntry) {
            return
        }
        
        # Show confirmation dialog
        $message = "Delete time entry for $($this.FormatDate($timeEntry.Date)) ($($timeEntry.Total) hours)?"
        $dialog = [ConfirmationDialog]::new($message)
        
        $screen = $this  # Capture reference for closure
        $dialog.OnConfirm = {
            # Remove from local collection
            for ($i = $screen.TimeEntries.Count - 1; $i -ge 0; $i--) {
                if ($screen.TimeEntries[$i].Date -eq $timeEntry.Date -and
                    $screen.TimeEntries[$i].Description -eq $timeEntry.Description) {
                    $screen.TimeEntries.RemoveAt($i)
                    break
                }
            }
            $screen.Invalidate()
            
            # Close dialog
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }.GetNewClosure()
        
        $dialog.OnCancel = {
            # Close dialog
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }
        
        # Show dialog
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        switch ($keyInfo.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.ScrollOffset -gt 0) {
                    $this.ScrollOffset--
                    $this.Invalidate()
                    return $true
                }
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.ScrollOffset -lt $this.MaxScrollOffset) {
                    $this.ScrollOffset++
                    $this.Invalidate()
                    return $true
                }
            }
            ([System.ConsoleKey]::PageUp) {
                $pageSize = [Math]::Max(1, ($this.Height - 4) / 2)
                $this.ScrollOffset = [Math]::Max(0, $this.ScrollOffset - $pageSize)
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::PageDown) {
                $pageSize = [Math]::Max(1, ($this.Height - 4) / 2)
                $this.ScrollOffset = [Math]::Min($this.MaxScrollOffset, $this.ScrollOffset + $pageSize)
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::Home) {
                $this.ScrollOffset = 0
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::End) {
                $this.ScrollOffset = $this.MaxScrollOffset
                $this.Invalidate()
                return $true
            }
        }
        
        # Handle character shortcuts
        if ($keyInfo.KeyChar) {
            switch ($keyInfo.KeyChar) {
                'r' {
                    # Refresh/reload data
                    $this.LoadTimeEntries()
                    $this.Invalidate()
                    return $true
                }
                'a' {
                    # Add new time entry
                    $this.AddTimeEntry()
                    return $true
                }
                'e' {
                    # Edit selected time entry (placeholder for now)
                    # In full implementation, would need to track selected entry
                    return $true
                }
                'd' {
                    # Delete selected time entry (placeholder for now)
                    # In full implementation, would need to track selected entry
                    return $true
                }
                '1' {
                    # Toggle project info section
                    $this.ShowProjectInfo = -not $this.ShowProjectInfo
                    $this.Invalidate()
                    return $true
                }
                '2' {
                    # Toggle weekly summary section
                    $this.ShowWeeklySummary = -not $this.ShowWeeklySummary
                    $this.Invalidate()
                    return $true
                }
                '3' {
                    # Toggle time entries section
                    $this.ShowTimeEntries = -not $this.ShowTimeEntries
                    $this.Invalidate()
                    return $true
                }
            }
        }
        
        # Let base class handle other input (like tab switching)
        return $false
    }
}