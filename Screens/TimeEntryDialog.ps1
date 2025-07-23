# TimeEntryDialog - Dialog for adding/editing time entries
# Based on tracker.txt time tracking structure

class TimeEntryDialog : Screen {
    [Project]$Project = $null
    [PSCustomObject]$TimeEntry = $null  # For editing existing entries
    [bool]$IsEditMode = $false
    
    # Input fields
    [TextBox]$DateTextBox
    [TextBox]$HoursTextBox
    [TextBox]$DescriptionTextBox
    
    # Buttons
    [Button]$SaveButton
    [Button]$CancelButton
    
    # Callbacks
    [scriptblock]$OnSave = {}
    [scriptblock]$OnCancel = {}
    
    TimeEntryDialog() : base() {
        $this.Title = "Add Time Entry"
    }
    
    TimeEntryDialog([Project]$project) : base() {
        $this.Project = $project
        $this.Title = "Add Time Entry - $($project.Nickname)"
    }
    
    TimeEntryDialog([Project]$project, [PSCustomObject]$timeEntry) : base() {
        $this.Project = $project
        $this.TimeEntry = $timeEntry
        $this.IsEditMode = $true
        $this.Title = "Edit Time Entry - $($project.Nickname)"
    }
    
    [void] OnInitialize() {
        # Create input fields
        $this.DateTextBox = [TextBox]::new()
        $this.DateTextBox.Title = "Date (MM/DD/YYYY)"
        $this.DateTextBox.ShowBorder = $true
        
        # Set default date to today
        if (-not $this.IsEditMode) {
            $this.DateTextBox.Text = (Get-Date).ToString("MM/dd/yyyy")
        } else {
            # Convert from YYYYMMDD format to MM/dd/yyyy
            try {
                $entryDate = [DateTime]::ParseExact($this.TimeEntry.Date, "yyyyMMdd", $null)
                $this.DateTextBox.Text = $entryDate.ToString("MM/dd/yyyy")
            } catch {
                $this.DateTextBox.Text = (Get-Date).ToString("MM/dd/yyyy")
            }
        }
        
        $this.HoursTextBox = [TextBox]::new()
        $this.HoursTextBox.Title = "Hours (e.g., 8.5)"
        $this.HoursTextBox.ShowBorder = $true
        
        if ($this.IsEditMode -and $this.TimeEntry.Total) {
            $this.HoursTextBox.Text = $this.TimeEntry.Total
        }
        
        $this.DescriptionTextBox = [TextBox]::new()
        $this.DescriptionTextBox.Title = "Description"
        $this.DescriptionTextBox.ShowBorder = $true
        $this.DescriptionTextBox.IsMultiline = $true
        
        if ($this.IsEditMode -and $this.TimeEntry.Description) {
            $this.DescriptionTextBox.Text = $this.TimeEntry.Description
        }
        
        # Initialize components
        if ($this.ServiceContainer) {
            $this.DateTextBox.Initialize($this.ServiceContainer)
            $this.HoursTextBox.Initialize($this.ServiceContainer)
            $this.DescriptionTextBox.Initialize($this.ServiceContainer)
        }
        
        # Create buttons
        $saveText = if ($this.IsEditMode) { "Update Entry" } else { "Add Entry" }
        $this.SaveButton = [Button]::new($saveText)
        $this.SaveButton.IsDefault = $true
        $this.SaveButton.OnClick = { $this.HandleSave() }
        
        $this.CancelButton = [Button]::new("Cancel")
        $this.CancelButton.OnClick = { $this.HandleCancel() }
        
        if ($this.ServiceContainer) {
            $this.SaveButton.Initialize($this.ServiceContainer)
            $this.CancelButton.Initialize($this.ServiceContainer)
        }
        
        # Add children
        $this.AddChild($this.DateTextBox)
        $this.AddChild($this.HoursTextBox)
        $this.AddChild($this.DescriptionTextBox)
        $this.AddChild($this.SaveButton)
        $this.AddChild($this.CancelButton)
        
        # Set initial focus
        $this.DateTextBox.Focus()
    }
    
    [void] OnBoundsChanged() {
        # Layout: Stack inputs vertically with buttons at bottom
        $margin = 2
        $buttonHeight = 3
        $inputHeight = 3
        $descriptionHeight = 5
        
        $currentY = $this.Y + $margin
        $inputWidth = $this.Width - ($margin * 2)
        
        # Date input
        $this.DateTextBox.SetBounds(
            $this.X + $margin,
            $currentY,
            $inputWidth,
            $inputHeight
        )
        $currentY += $inputHeight + 1
        
        # Hours input
        $this.HoursTextBox.SetBounds(
            $this.X + $margin,
            $currentY,
            $inputWidth,
            $inputHeight
        )
        $currentY += $inputHeight + 1
        
        # Description input (taller)
        $this.DescriptionTextBox.SetBounds(
            $this.X + $margin,
            $currentY,
            $inputWidth,
            $descriptionHeight
        )
        $currentY += $descriptionHeight + 2
        
        # Buttons at bottom
        $buttonWidth = 15
        $buttonSpacing = 4
        $totalButtonWidth = ($buttonWidth * 2) + $buttonSpacing
        $buttonStartX = $this.X + [int](($this.Width - $totalButtonWidth) / 2)
        $buttonY = $this.Y + $this.Height - $buttonHeight - 1
        
        $this.SaveButton.SetBounds(
            $buttonStartX,
            $buttonY,
            $buttonWidth,
            $buttonHeight
        )
        
        $this.CancelButton.SetBounds(
            $buttonStartX + $buttonWidth + $buttonSpacing,
            $buttonY,
            $buttonWidth,
            $buttonHeight
        )
    }
    
    [void] HandleSave() {
        # Validate inputs
        $validationError = $this.ValidateInputs()
        if ($validationError) {
            # In a real implementation, show error dialog
            # For now, just return
            return
        }
        
        # Create time entry data
        $timeEntryData = $this.CreateTimeEntryData()
        
        if ($this.OnSave) {
            & $this.OnSave $timeEntryData
        }
    }
    
    [void] HandleCancel() {
        if ($this.OnCancel) {
            & $this.OnCancel
        }
    }
    
    [string] ValidateInputs() {
        # Validate date
        $dateStr = $this.DateTextBox.Text.Trim()
        if ([string]::IsNullOrEmpty($dateStr)) {
            return "Date is required"
        }
        
        try {
            [DateTime]::Parse($dateStr) | Out-Null
        } catch {
            return "Invalid date format. Use MM/DD/YYYY"
        }
        
        # Validate hours
        $hoursStr = $this.HoursTextBox.Text.Trim()
        if ([string]::IsNullOrEmpty($hoursStr)) {
            return "Hours is required"
        }
        
        $hours = 0.0
        if (-not [double]::TryParse($hoursStr, [ref]$hours) -or $hours -le 0) {
            return "Hours must be a positive number"
        }
        
        return $null  # No validation errors
    }
    
    [PSCustomObject] CreateTimeEntryData() {
        # Parse and format date to YYYYMMDD
        $entryDate = [DateTime]::Parse($this.DateTextBox.Text.Trim())
        $internalDate = $entryDate.ToString("yyyyMMdd")
        
        # Parse hours
        $hours = [double]::Parse($this.HoursTextBox.Text.Trim())
        
        # Get day of week for hour distribution
        $dayOfWeek = $entryDate.DayOfWeek
        
        # Create time entry following tracker.txt structure
        $newTimeEntry = [PSCustomObject]@{
            Date = $internalDate
            Nickname = $this.Project.Nickname
            ID1 = if ($this.Project.ID1) { $this.Project.ID1 } else { "" }
            ID2 = $this.FormatID2($this.Project.ID2)
            MonHours = if ($dayOfWeek -eq "Monday") { $hours.ToString("F2") } else { "" }
            TueHours = if ($dayOfWeek -eq "Tuesday") { $hours.ToString("F2") } else { "" }
            WedHours = if ($dayOfWeek -eq "Wednesday") { $hours.ToString("F2") } else { "" }
            ThuHours = if ($dayOfWeek -eq "Thursday") { $hours.ToString("F2") } else { "" }
            FriHours = if ($dayOfWeek -eq "Friday") { $hours.ToString("F2") } else { "" }
            Total = $hours.ToString("F2")
            Description = $this.DescriptionTextBox.Text.Trim()
        }
        
        return $newTimeEntry
    }
    
    [string] FormatID2([string]$id2) {
        # Format ID2 with V0 prefix, S suffix, padded to 12 characters
        # Following tracker.txt format
        if ([string]::IsNullOrWhiteSpace($id2)) {
            return ""
        }
        
        $id2Text = $id2.Trim()
        $paddingNeeded = 12 - ($id2Text.Length + 2)
        
        if ($paddingNeeded > 0) {
            return "V" + ("0" * $paddingNeeded) + $id2Text + "S"
        } else {
            return "V" + $id2Text + "S"
        }
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        switch ($keyInfo.Key) {
            ([System.ConsoleKey]::Enter) {
                if ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) {
                    $this.HandleSave()
                    return $true
                }
            }
            ([System.ConsoleKey]::Escape) {
                $this.HandleCancel()
                return $true
            }
            ([System.ConsoleKey]::Tab) {
                # Handle tab navigation between fields
                $focused = $this.FindFocused()
                if ($focused -eq $this.DateTextBox) {
                    $this.HoursTextBox.Focus()
                } elseif ($focused -eq $this.HoursTextBox) {
                    $this.DescriptionTextBox.Focus()
                } elseif ($focused -eq $this.DescriptionTextBox) {
                    $this.SaveButton.Focus()
                } else {
                    $this.DateTextBox.Focus()
                }
                return $true
            }
        }
        
        # Let base class handle other input
        return $false
    }
}