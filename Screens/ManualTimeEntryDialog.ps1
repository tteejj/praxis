# ManualTimeEntryDialog - Dialog for manual ID2 time entry

class ManualTimeEntryDialog : BaseDialog {
    [MinimalTextBox]$ID2TextBox
    [MinimalTextBox]$NameTextBox
    [MinimalTextBox]$DateTextBox
    [MinimalTextBox]$HoursTextBox
    [MinimalTextBox]$DescriptionTextBox
    [TimeTrackingService]$TimeService
    [scriptblock]$OnSave = {}
    
    ManualTimeEntryDialog() : base("Manual Time Entry") {
        $this.DialogWidth = 50
        $this.DialogHeight = 20
        $this.PrimaryButtonText = "Save"
        $this.SecondaryButtonText = "Cancel"
    }
    
    [void] InitializeContent() {
        # Get TimeTrackingService
        $this.TimeService = $this.ServiceContainer.GetService("TimeTrackingService")
        
        # Create input fields
        $this.ID2TextBox = [MinimalTextBox]::new()
        $this.ID2TextBox.ShowBorder = $false
        $this.ID2TextBox.Placeholder = "ID2 (e.g., ADM, TRN, VAC)"
        $this.ID2TextBox.Height = 1
        $this.AddContentControl($this.ID2TextBox, 1)
        
        $this.NameTextBox = [MinimalTextBox]::new()
        $this.NameTextBox.ShowBorder = $false
        $this.NameTextBox.Placeholder = "Description (e.g., Administrative, Training)"
        $this.NameTextBox.Height = 1
        $this.AddContentControl($this.NameTextBox, 2)
        
        $this.DateTextBox = [MinimalTextBox]::new()
        $this.DateTextBox.ShowBorder = $false
        $this.DateTextBox.Placeholder = "Date (MM/DD/YYYY)"
        $this.DateTextBox.Height = 1
        $this.DateTextBox.Text = (Get-Date).ToString("MM/dd/yyyy")
        $this.AddContentControl($this.DateTextBox, 3)
        
        $this.HoursTextBox = [MinimalTextBox]::new()
        $this.HoursTextBox.ShowBorder = $false
        $this.HoursTextBox.Placeholder = "Hours (e.g., 8.5)"
        $this.HoursTextBox.Height = 1
        $this.AddContentControl($this.HoursTextBox, 4)
        
        $this.DescriptionTextBox = [MinimalTextBox]::new()
        $this.DescriptionTextBox.ShowBorder = $false
        $this.DescriptionTextBox.Placeholder = "Notes (optional)"
        $this.DescriptionTextBox.Height = 3
        $this.AddContentControl($this.DescriptionTextBox, 5)
        
        # Set up primary action
        $dialog = $this
        $this.OnPrimary = {
            if ($global:Logger) {
                $global:Logger.Debug("ManualTimeEntryDialog.OnPrimary: Save button clicked")
            }
            
            # Validate inputs
            if (-not $dialog.ID2TextBox.Text -or -not $dialog.HoursTextBox.Text) {
                if ($global:Logger) {
                    $global:Logger.Warning("ManualTimeEntryDialog.OnPrimary: Validation failed - missing ID2 or Hours")
                }
                return
            }
            
            if ($global:Logger) {
                $global:Logger.Debug("ManualTimeEntryDialog.OnPrimary: Validation passed - ID2='$($dialog.ID2TextBox.Text)', Hours='$($dialog.HoursTextBox.Text)'")
            }
            
            # Parse date and hours
            try {
                $date = [DateTime]::Parse($dialog.DateTextBox.Text)
                $hours = [decimal]::Parse($dialog.HoursTextBox.Text)
                
                if ($hours -le 0 -or $hours -gt 24) {
                    if ($global:Logger) {
                        $global:Logger.Warning("ManualTimeEntryDialog.OnPrimary: Hours validation failed - $hours not between 0 and 24")
                    }
                    return
                }
                
                if ($global:Logger) {
                    $global:Logger.Debug("ManualTimeEntryDialog.OnPrimary: Parsed date=$($date.ToString('yyyy-MM-dd')), hours=$hours")
                }
                
                # Create time entry
                $timeEntry = [PSCustomObject]@{
                    Id = [Guid]::NewGuid().ToString()
                    ProjectId = $dialog.ID2TextBox.Text.ToUpper()
                    ProjectName = if ($dialog.NameTextBox.Text) { $dialog.NameTextBox.Text } else { $dialog.ID2TextBox.Text }
                    Date = $date
                    Hours = $hours
                    Description = $dialog.DescriptionTextBox.Text
                    CreatedAt = [DateTime]::Now
                    UpdatedAt = [DateTime]::Now
                }
                
                if ($global:Logger) {
                    $global:Logger.Debug("ManualTimeEntryDialog.OnPrimary: Created time entry object - ProjectId='$($timeEntry.ProjectId)'")
                }
                
                # Save using TimeTrackingService
                if ($dialog.TimeService) {
                    if ($global:Logger) {
                        $global:Logger.Debug("ManualTimeEntryDialog.OnPrimary: Calling TimeService.AddTimeEntry")
                    }
                    $dialog.TimeService.AddTimeEntry($timeEntry)
                    if ($global:Logger) {
                        $global:Logger.Info("ManualTimeEntryDialog.OnPrimary: TimeService.AddTimeEntry completed")
                    }
                } else {
                    if ($global:Logger) {
                        $global:Logger.Error("ManualTimeEntryDialog.OnPrimary: TimeService is null!")
                    }
                }
                
                # Call callback if set
                if ($dialog.OnSave) {
                    if ($global:Logger) {
                        $global:Logger.Debug("ManualTimeEntryDialog.OnPrimary: Calling OnSave callback")
                    }
                    & $dialog.OnSave $timeEntry
                }
                
                # Publish event
                if ($dialog.EventBus) {
                    if ($global:Logger) {
                        $global:Logger.Debug("ManualTimeEntryDialog.OnPrimary: Publishing timeentry.created event")
                    }
                    $dialog.EventBus.Publish('timeentry.created', @{ 
                        TimeEntry = $timeEntry 
                    })
                }
            }
            catch {
                # Invalid input - could show error dialog
                if ($global:Logger) {
                    $global:Logger.Error("ManualTimeEntryDialog.OnPrimary: Exception during save: $_")
                }
                return
            }
        }.GetNewClosure()
    }
    
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        $controlWidth = $this.DialogWidth - ($this.DialogPadding * 2)
        $currentY = $dialogY + 2
        
        # ID2 field
        $this.ID2TextBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 1)
        $currentY += 2
        
        # Name field
        $this.NameTextBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 1)
        $currentY += 2
        
        # Date field
        $this.DateTextBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 1)
        $currentY += 2
        
        # Hours field
        $this.HoursTextBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 1)
        $currentY += 2
        
        # Description field (taller)
        $this.DescriptionTextBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 3)
    }
}