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
        
        # Configure primary button action
        $dialog = $this
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
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        # Handle Enter key for selection when ListBox has focus
        if ($key.Key -eq [System.ConsoleKey]::Enter -and -not $key.Modifiers) {
            $focusManager = $this.ServiceContainer.GetService('FocusManager')
            if ($focusManager) {
                $focused = $focusManager.GetFocused()
                if ($focused -eq $this.OptionsBox) {
                    # ListBox has focus, trigger selection
                    $selectedOption = $this.OptionsBox.GetSelectedItem()
                    if ($selectedOption -and $this.OnOptionSelected) {
                        & $this.OnOptionSelected $selectedOption
                        # Don't close here - let the callback handle navigation
                    }
                    return $true
                }
            }
        }
        
        # Let base class handle other keys
        return ([BaseDialog]$this).HandleScreenInput($key)
    }
}