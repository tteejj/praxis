# QuickTimeEntryDialog - Simple time entry dialog using UnifiedDialog

class QuickTimeEntryDialog : UnifiedDialog {
    [DateTime]$WeekFriday
    
    QuickTimeEntryDialog([DateTime]$weekFriday) : base("Quick Time Entry", 60, 16) {
        $this.WeekFriday = $weekFriday
        
        # Calculate week range for display
        $weekStart = $weekFriday.AddDays(-4)
        $weekText = "Week: " + $weekStart.ToString("MM/dd") + " - " + $weekFriday.ToString("MM/dd")
        
        # Add fields using simplified UnifiedDialog API
        $this.AddField("project", "Project ID2", "")
        $this.AddField("monday", "Monday Hours", "")
        $this.AddField("tuesday", "Tuesday Hours", "")
        $this.AddField("wednesday", "Wednesday Hours", "")
        $this.AddField("thursday", "Thursday Hours", "")
        $this.AddField("friday", "Friday Hours", "")
        
        # Set button labels
        $this.SetButtons("Save", "Cancel")
        
        # Set up submit handler with proper closure
        $dialog = $this
        $this.OnSubmit = { $dialog.SaveTimeEntries() }.GetNewClosure()
    }
    
    [void] SaveTimeEntries() {
        # Get project ID
        $projectId = $this.GetFieldValue("project").Trim().ToUpper()
        
        # Validate project ID
        if ([string]::IsNullOrWhiteSpace($projectId)) {
            # Show error - for now just return
            return
        }
        
        # Get services
        $timeService = $this.GetService("TimeTrackingService")
        $projectService = $this.GetService("ProjectService")
        
        if (-not $timeService -or -not $projectService) {
            return
        }
        
        try {
            # Create time entry for each day with hours
            $weekStart = $this.WeekFriday.AddDays(-4)
            $daysAndHours = @(
                @{ Day = $weekStart; Hours = $this.ParseHours($this.GetFieldValue("monday")) },
                @{ Day = $weekStart.AddDays(1); Hours = $this.ParseHours($this.GetFieldValue("tuesday")) },
                @{ Day = $weekStart.AddDays(2); Hours = $this.ParseHours($this.GetFieldValue("wednesday")) },
                @{ Day = $weekStart.AddDays(3); Hours = $this.ParseHours($this.GetFieldValue("thursday")) },
                @{ Day = $weekStart.AddDays(4); Hours = $this.ParseHours($this.GetFieldValue("friday")) }
            )
            
            # Find project details
            $project = $projectService.GetAllProjects() | Where-Object { $_.ID2 -eq $projectId } | Select-Object -First 1
            
            foreach ($dayInfo in $daysAndHours) {
                if ($dayInfo.Hours -gt 0) {
                    $timeEntry = [PSCustomObject]@{
                        Id = [Guid]::NewGuid().ToString()
                        ProjectId = $projectId
                        ProjectName = if ($project) { $project.FullProjectName } else { $projectId }
                        Date = $dayInfo.Day
                        Hours = $dayInfo.Hours
                        Description = ""
                        CreatedAt = [DateTime]::Now
                        UpdatedAt = [DateTime]::Now
                    }
                    
                    # Add to time service
                    $timeService.AddTimeEntry($timeEntry)
                }
            }
            
            # Manually refresh the time tracking screen instead of using events
            # Find the TimeTrackingScreen by type name to avoid loading order issues
            if ($global:ScreenManager -and $global:ScreenManager.Screens.Count -gt 0) {
                foreach ($screen in $global:ScreenManager.Screens) {
                    if ($screen.GetType().Name -eq "TimeTrackingScreen") {
                        $screen.LoadData()
                        break
                    }
                }
            }
            
            # Close dialog
            $this.Close()
            
        } catch {
            # Handle error - for now just log
            if ($global:Logger) {
                $global:Logger.Error("Failed to save time entries: $_")
            }
        }
    }
    
    [decimal] ParseHours([string]$text) {
        if ([string]::IsNullOrWhiteSpace($text)) { return 0 }
        $hours = 0
        if ([decimal]::TryParse($text, [ref]$hours)) {
            return [Math]::Max(0, $hours)
        }
        return 0
    }
}