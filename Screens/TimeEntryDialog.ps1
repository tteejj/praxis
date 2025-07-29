# TimeEntryDialog - Dialog for adding/editing time entries
# Properly integrated with BaseDialog

class TimeEntryDialog : BaseDialog {
    [Project]$Project = $null
    [PSCustomObject]$TimeEntry = $null  # For editing existing entries
    [bool]$IsEditMode = $false
    [TimeTrackingService]$TimeService
    
    # Input fields
    [MinimalTextBox]$DateTextBox
    [MinimalTextBox]$HoursTextBox
    [MinimalTextBox]$DescriptionTextBox
    
    # Callbacks for legacy compatibility
    [scriptblock]$OnSave = {}
    [scriptblock]$OnCancel = {}
    
    TimeEntryDialog() : base("Add Time Entry") {
        $this.DialogWidth = 50
        $this.DialogHeight = 16
    }
    
    TimeEntryDialog([Project]$project) : base("Add Time Entry") {
        $this.Project = $project
        $this.DialogWidth = 50
        $this.DialogHeight = 16
    }
    
    TimeEntryDialog([Project]$project, [PSCustomObject]$timeEntry) : base("Edit Time Entry") {
        $this.Project = $project
        $this.TimeEntry = $timeEntry
        $this.IsEditMode = $true
        $this.DialogWidth = 50
        $this.DialogHeight = 16
    }
    
    [void] InitializeContent() {
        # Get TimeTrackingService
        $this.TimeService = $this.ServiceContainer.GetService("TimeTrackingService")
        
        # Create input fields
        $this.DateTextBox = [MinimalTextBox]::new()
        $this.DateTextBox.ShowBorder = $false  # Dialog provides border
        $this.DateTextBox.Placeholder = "Date (MM/DD/YYYY)"
        $this.DateTextBox.Height = 1
        
        # Set default date to today
        if (-not $this.IsEditMode) {
            $this.DateTextBox.Text = (Get-Date).ToString("MM/dd/yyyy")
        } else {
            # Use the date from time entry if available
            if ($this.TimeEntry.Date) {
                if ($this.TimeEntry.Date -is [DateTime]) {
                    $this.DateTextBox.Text = $this.TimeEntry.Date.ToString("MM/dd/yyyy")
                } else {
                    # Try to parse string date
                    try {
                        $entryDate = [DateTime]::ParseExact($this.TimeEntry.Date, "yyyyMMdd", $null)
                        $this.DateTextBox.Text = $entryDate.ToString("MM/dd/yyyy")
                    } catch {
                        $this.DateTextBox.Text = (Get-Date).ToString("MM/dd/yyyy")
                    }
                }
            }
        }
        $this.AddContentControl($this.DateTextBox, 1)
        
        $this.HoursTextBox = [MinimalTextBox]::new()
        $this.HoursTextBox.ShowBorder = $false
        $this.HoursTextBox.Placeholder = "Hours (e.g., 8.5)"
        $this.HoursTextBox.Height = 1
        
        if ($this.IsEditMode -and $this.TimeEntry.Hours) {
            $this.HoursTextBox.Text = $this.TimeEntry.Hours.ToString()
        }
        $this.AddContentControl($this.HoursTextBox, 2)
        
        $this.DescriptionTextBox = [MinimalTextBox]::new()
        $this.DescriptionTextBox.ShowBorder = $false
        $this.DescriptionTextBox.Placeholder = "Description (optional)"
        $this.DescriptionTextBox.Height = 3
        
        if ($this.IsEditMode -and $this.TimeEntry.Description) {
            $this.DescriptionTextBox.Text = $this.TimeEntry.Description
        }
        $this.AddContentControl($this.DescriptionTextBox, 3)
        
        # Set up primary action
        $dialog = $this
        $this.OnPrimary = {
            # Validate inputs
            $validationError = $dialog.ValidateInputs()
            if ($validationError) {
                # TODO: Show error dialog
                return
            }
            
            # Create time entry data
            $timeEntryData = $dialog.CreateTimeEntryData()
            
            # Save using TimeTrackingService
            if ($dialog.TimeService) {
                if ($dialog.IsEditMode) {
                    $dialog.TimeService.UpdateTimeEntry($timeEntryData)
                } else {
                    $dialog.TimeService.AddTimeEntry($timeEntryData)
                }
            }
            
            # Call legacy callback if set
            if ($dialog.OnSave) {
                & $dialog.OnSave $timeEntryData
            }
            
            # Publish event if EventBus available
            if ($dialog.EventBus) {
                $eventName = if ($dialog.IsEditMode) { 'timeentry.updated' } else { 'timeentry.created' }
                $dialog.EventBus.Publish($eventName, @{ 
                    TimeEntry = $timeEntryData 
                })
            }
        }.GetNewClosure()
        
        # Set up secondary action
        $this.OnSecondary = {
            # Call legacy callback if set
            if ($dialog.OnCancel) {
                & $dialog.OnCancel
            }
        }.GetNewClosure()
    }
    
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        # Custom positioning for time entry fields
        $controlWidth = $this.DialogWidth - ($this.DialogPadding * 2)
        $currentY = $dialogY + 2
        
        # Date field
        $this.DateTextBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 1)
        $currentY += 2
        
        # Hours field
        $this.HoursTextBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 1)
        $currentY += 2
        
        # Description field (taller)
        $this.DescriptionTextBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 3)
    }
    
    [string] ValidateInputs() {
        # Validate date
        if (-not $this.DateTextBox.Text) {
            return "Date is required"
        }
        
        try {
            [DateTime]::Parse($this.DateTextBox.Text) | Out-Null
        } catch {
            return "Invalid date format. Use MM/DD/YYYY"
        }
        
        # Validate hours
        if (-not $this.HoursTextBox.Text) {
            return "Hours are required"
        }
        
        try {
            $hours = [decimal]::Parse($this.HoursTextBox.Text)
            if ($hours -le 0 -or $hours -gt 24) {
                return "Hours must be between 0 and 24"
            }
        } catch {
            return "Invalid hours format. Use a number like 8 or 8.5"
        }
        
        return $null
    }
    
    [PSCustomObject] CreateTimeEntryData() {
        $date = [DateTime]::Parse($this.DateTextBox.Text)
        $hours = [decimal]::Parse($this.HoursTextBox.Text)
        
        if ($this.IsEditMode) {
            # Update existing entry
            $this.TimeEntry.Date = $date
            $this.TimeEntry.Hours = $hours
            $this.TimeEntry.Description = $this.DescriptionTextBox.Text
            return $this.TimeEntry
        } else {
            # Create new entry
            return [PSCustomObject]@{
                Id = [Guid]::NewGuid().ToString()
                ProjectId = $this.Project.Id
                ProjectName = $this.Project.FullProjectName
                Date = $date
                Hours = $hours
                Description = $this.DescriptionTextBox.Text
                CreatedAt = [DateTime]::Now
                UpdatedAt = [DateTime]::Now
            }
        }
    }
}