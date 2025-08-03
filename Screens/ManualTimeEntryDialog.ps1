# ManualTimeEntryDialog - Dialog for manual ID2 time entry using UnifiedDialog

class ManualTimeEntryDialog : UnifiedDialog {
    ManualTimeEntryDialog() : base("Manual Time Entry", 50, 16) {
        # Add fields using simplified UnifiedDialog API
        $this.AddField("id2", "ID2 (e.g., ADM, TRN, VAC)", "")
        $this.AddField("name", "Description", "")
        $this.AddField("date", "Date (MM/DD/YYYY)", (Get-Date).ToString("MM/dd/yyyy"))
        $this.AddField("hours", "Hours (e.g., 8.5)", "")
        $this.AddField("notes", "Notes", "")
        
        # Set button labels
        $this.SetButtons("Save", "Cancel")
        
        # Set up submit handler with proper closure
        $dialog = $this
        $this.OnSubmit = { $dialog.SaveTimeEntry() }.GetNewClosure()
    }
    
    [void] SaveTimeEntry() {
        # Get field values
        $id2 = $this.GetFieldValue("id2").Trim()
        $hoursText = $this.GetFieldValue("hours").Trim()
        
        # Validate required fields
        if ([string]::IsNullOrWhiteSpace($id2) -or [string]::IsNullOrWhiteSpace($hoursText)) {
            # Show error - for now just return
            return
        }
        
        # Parse date and hours
        try {
            $date = [DateTime]::Parse($this.GetFieldValue("date"))
            $hours = [decimal]::Parse($hoursText)
            
            if ($hours -le 0 -or $hours -gt 24) {
                # Hours validation failed
                return
            }
            
            # Create time entry
            $timeEntry = [PSCustomObject]@{
                Id = [Guid]::NewGuid().ToString()
                ProjectId = $id2.ToUpper()
                ProjectName = if ($this.GetFieldValue("name")) { $this.GetFieldValue("name") } else { $id2 }
                Date = $date
                Hours = $hours
                Description = $this.GetFieldValue("notes")
                CreatedAt = [DateTime]::Now
                UpdatedAt = [DateTime]::Now
            }
            
            # Save using TimeTrackingService
            $timeService = $this.GetService("TimeTrackingService")
            if ($timeService) {
                $timeService.AddTimeEntry($timeEntry)
                
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
            }
        }
        catch {
            # Handle error - for now just log
            if ($global:Logger) {
                $global:Logger.Error("Failed to save manual time entry: $_")
            }
        }
    }
}