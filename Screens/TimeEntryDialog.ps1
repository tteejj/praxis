# TimeEntryDialog - Dialog for adding/editing time entries using UnifiedDialog

class TimeEntryDialog : UnifiedDialog {
    [Project]$Project = $null
    [PSCustomObject]$TimeEntry = $null  # For editing existing entries
    [bool]$IsEditMode = $false
    
    TimeEntryDialog() : base("Add Time Entry", 50, 14) {
        $this.InitializeFields()
    }
    
    TimeEntryDialog([Project]$project) : base("Add Time Entry", 50, 14) {
        $this.Project = $project
        $this.InitializeFields()
    }
    
    TimeEntryDialog([Project]$project, [PSCustomObject]$timeEntry) : base("Edit Time Entry", 50, 14) {
        $this.Project = $project
        $this.TimeEntry = $timeEntry
        $this.IsEditMode = $true
        $this.InitializeFields()
    }
    
    [void] InitializeFields() {
        # Set default values based on mode
        $defaultDate = (Get-Date).ToString("MM/dd/yyyy")
        $defaultHours = ""
        $defaultDescription = ""
        
        if ($this.IsEditMode -and $this.TimeEntry) {
            # Use values from existing time entry
            if ($this.TimeEntry.Date) {
                if ($this.TimeEntry.Date -is [DateTime]) {
                    $defaultDate = $this.TimeEntry.Date.ToString("MM/dd/yyyy")
                } else {
                    # Try to parse string date
                    try {
                        $entryDate = [DateTime]::ParseExact($this.TimeEntry.Date, "yyyyMMdd", $null)
                        $defaultDate = $entryDate.ToString("MM/dd/yyyy")
                    } catch {
                        # Keep default
                    }
                }
            }
            if ($this.TimeEntry.Hours) {
                $defaultHours = $this.TimeEntry.Hours.ToString()
            }
            if ($this.TimeEntry.Description) {
                $defaultDescription = $this.TimeEntry.Description
            }
        }
        
        # Add fields using simplified UnifiedDialog API
        $this.AddField("date", "Date (MM/DD/YYYY)", $defaultDate)
        $this.AddField("hours", "Hours (e.g., 8.5)", $defaultHours)
        $this.AddField("description", "Description", $defaultDescription)
        
        # Set button labels
        $this.SetButtons($(if ($this.IsEditMode) { "Update" } else { "Save" }), "Cancel")
        
        # Set up submit handler with proper closure
        $dialog = $this
        $this.OnSubmit = { $dialog.SaveTimeEntry() }.GetNewClosure()
    }
    
    [void] SaveTimeEntry() {
        # Validate inputs
        $validationError = $this.ValidateInputs()
        if ($validationError) {
            # For now just return - could show error dialog in future
            return
        }
        
        # Create time entry data
        $timeEntryData = $this.CreateTimeEntryData()
        
        # Save using TimeTrackingService
        $timeService = $this.GetService("TimeTrackingService")
        if ($timeService) {
            try {
                if ($this.IsEditMode) {
                    $timeService.UpdateTimeEntry($timeEntryData)
                } else {
                    $timeService.AddTimeEntry($timeEntryData)
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
                    $global:Logger.Error("Failed to save time entry: $_")
                }
            }
        }
    }
    
    [string] ValidateInputs() {
        # Validate date
        $dateText = $this.GetFieldValue("date")
        if ([string]::IsNullOrWhiteSpace($dateText)) {
            return "Date is required"
        }
        
        try {
            [DateTime]::Parse($dateText) | Out-Null
        } catch {
            return "Invalid date format. Use MM/DD/YYYY"
        }
        
        # Validate hours
        $hoursText = $this.GetFieldValue("hours")
        if ([string]::IsNullOrWhiteSpace($hoursText)) {
            return "Hours are required"
        }
        
        try {
            $hours = [decimal]::Parse($hoursText)
            if ($hours -le 0 -or $hours -gt 24) {
                return "Hours must be between 0 and 24"
            }
        } catch {
            return "Invalid hours format. Use a number like 8 or 8.5"
        }
        
        return $null
    }
    
    [PSCustomObject] CreateTimeEntryData() {
        $date = [DateTime]::Parse($this.GetFieldValue("date"))
        $hours = [decimal]::Parse($this.GetFieldValue("hours"))
        $description = $this.GetFieldValue("description")
        
        if ($this.IsEditMode) {
            # Update existing entry
            $this.TimeEntry.Date = $date
            $this.TimeEntry.Hours = $hours
            $this.TimeEntry.Description = $description
            $this.TimeEntry.UpdatedAt = [DateTime]::Now
            return $this.TimeEntry
        } else {
            # Create new entry
            return [PSCustomObject]@{
                Id = [Guid]::NewGuid().ToString()
                ProjectId = if ($this.Project -and $this.Project.ID2) { $this.Project.ID2 } elseif ($this.Project -and $this.Project.Id) { $this.Project.Id } else { "UNKNOWN" }
                ProjectName = if ($this.Project) { $this.Project.FullProjectName } else { "Unknown Project" }
                Date = $date
                Hours = $hours
                Description = $description
                CreatedAt = [DateTime]::Now
                UpdatedAt = [DateTime]::Now
            }
        }
    }
}