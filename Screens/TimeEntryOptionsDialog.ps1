# TimeEntryOptionsDialog - Dialog for choosing time entry method

class TimeEntryOptionsDialog : BaseDialog {
    [MinimalListBox]$OptionsBox
    [scriptblock]$OnOptionSelected = {}
    
    TimeEntryOptionsDialog() : base("New Time Entry") {
        $this.DialogWidth = 60
        $this.DialogHeight = 16
        $this.PrimaryButtonText = "Select"
        $this.SecondaryButtonText = "Cancel"
    }
    
    [void] InitializeContent() {
        # Create options list
        $this.OptionsBox = [MinimalListBox]::new()
        $this.OptionsBox.ShowBorder = $true
        $this.OptionsBox.BorderType = [BorderType]::Rounded
        
        # Store reference to dialog
        $dialog = $this
        
        # Set up options
        $options = @(
            [PSCustomObject]@{
                Type = "projects"
                Display = "Select from existing projects"
                Description = "Choose from your active projects"
            },
            [PSCustomObject]@{
                Type = "manual"
                Display = "Enter ID2 manually"
                Description = "For non-project time (e.g., ADM, TRN, VAC)"
            }
        )
        
        $this.OptionsBox.ItemFormatter = { 
            param($item) 
            "$($item.Display) - $($item.Description)"
        }
        
        $this.OptionsBox.SetItems($options)
        $this.AddContentControl($this.OptionsBox, 1)
        
        # Handle Enter key on list item - this is called by MinimalListBox on Enter
        $this.OptionsBox.OnSelectionChanged = {
            $selectedOption = $dialog.OptionsBox.GetSelectedItem()
            if ($selectedOption -and $dialog.OnOptionSelected) {
                & $dialog.OnOptionSelected $selectedOption
            }
        }.GetNewClosure()
        
        # Configure primary button action
        $this.OnPrimary = {
            $selectedOption = $dialog.OptionsBox.GetSelectedItem()
            if ($selectedOption -and $dialog.OnOptionSelected) {
                & $dialog.OnOptionSelected $selectedOption
            }
        }.GetNewClosure()
    }
    
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        $padding = 2
        $controlWidth = $this.DialogWidth - ($padding * 2)
        $listHeight = $this.DialogHeight - 8  # Leave room for title and buttons
        
        $this.OptionsBox.SetBounds(
            $dialogX + $padding,
            $dialogY + 2,
            $controlWidth,
            $listHeight
        )
    }
    
}