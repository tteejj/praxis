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
            # Validate inputs
            if (-not $dialog.ID2TextBox.Text -or -not $dialog.HoursTextBox.Text) {
                return
            }
            
            # Parse date and hours
            try {
                $date = [DateTime]::Parse($dialog.DateTextBox.Text)
                $hours = [decimal]::Parse($dialog.HoursTextBox.Text)
                
                if ($hours -le 0 -or $hours -gt 24) {
                    return
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
                
                # Save using TimeTrackingService
                if ($dialog.TimeService) {
                    $dialog.TimeService.AddTimeEntry($timeEntry)
                }
                
                # Call callback if set
                if ($dialog.OnSave) {
                    & $dialog.OnSave $timeEntry
                }
                
                # Publish event
                if ($dialog.EventBus) {
                    $dialog.EventBus.Publish('timeentry.created', @{ 
                        TimeEntry = $timeEntry 
                    })
                }
            }
            catch {
                # Invalid input - could show error dialog
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