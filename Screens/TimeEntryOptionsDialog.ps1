# TimeEntryOptionsDialog - Dialog for choosing time entry method using UnifiedDialog

class TimeEntryOptionsDialog : UnifiedDialog {
    [MinimalListBox]$OptionsBox
    [scriptblock]$OnOptionSelected = {}
    
    TimeEntryOptionsDialog() : base("New Time Entry", 60, 12) {
        # Create options list manually for more control
        $this.OptionsBox = [MinimalListBox]::new()
        $this.OptionsBox.ShowBorder = $false
        $this.OptionsBox.Height = 6
        
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
        $this.OptionsBox | Add-Member -NotePropertyName "FieldName" -NotePropertyValue "options"
        $this.AddControl($this.OptionsBox)
        
        # Set button labels
        $this.SetButtons("Select", "Cancel")
        
        # Set up submit handler with proper closure
        $dialog = $this
        $this.OnSubmit = { $dialog.SelectOption() }.GetNewClosure()
        
        # Handle Enter key on list item
        $this.OptionsBox.OnSelectionChanged = {
            $selectedOption = $dialog.OptionsBox.GetSelectedItem()
            if ($selectedOption -and $dialog.OnOptionSelected) {
                & $dialog.OnOptionSelected $selectedOption
                $dialog.Close()
            }
        }.GetNewClosure()
    }
    
    [void] SelectOption() {
        $selectedOption = $this.OptionsBox.GetSelectedItem()
        if ($selectedOption -and $this.OnOptionSelected) {
            & $this.OnOptionSelected $selectedOption
        }
        $this.Close()
    }
}