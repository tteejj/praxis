# QuickTimeEntryDialog - Fast time entry for projects and non-project codes

class QuickTimeEntryDialog : BaseDialog {
    [DateTime]$WeekFriday
    [TimeEntry]$ExistingEntry
    [ListBox]$ProjectList
    [TextBox]$ID2Input
    [TextBox]$MondayInput
    [TextBox]$TuesdayInput
    [TextBox]$WednesdayInput
    [TextBox]$ThursdayInput
    [TextBox]$FridayInput
    [Button]$SaveButton
    [Button]$CancelButton
    [bool]$IsProjectMode = $true
    [TimeTrackingService]$TimeService
    [ProjectService]$ProjectService
    [string]$SelectedID2
    
    QuickTimeEntryDialog([DateTime]$weekFriday) : base() {
        $this.Title = "Quick Time Entry"
        $this.WeekFriday = $weekFriday
        $this.Width = 60
        $this.Height = 20
    }
    
    QuickTimeEntryDialog([DateTime]$weekFriday, [TimeEntry]$entry) : base() {
        $this.Title = "Edit Time Entry"
        $this.WeekFriday = $weekFriday
        $this.ExistingEntry = $entry
        $this.Width = 60
        $this.Height = 20
    }
    
    [void] OnInitialize() {
        ([BaseDialog]$this).OnInitialize()
        
        # Get services
        $this.TimeService = $this.ServiceContainer.GetService("TimeTrackingService")
        $this.ProjectService = $this.ServiceContainer.GetService("ProjectService")
        
        $y = 2
        
        # Mode toggle instruction
        $modeLabel = "Tab: Toggle between Project/Non-Project mode"
        $this.AddText($modeLabel, 2, $y)
        $y += 2
        
        # Project list (for project mode)
        $this.ProjectList = [ListBox]::new()
        $this.ProjectList.Title = "Select Project (or Tab for ID2 entry)"
        $this.ProjectList.ShowBorder = $true
        $this.ProjectList.Height = 6
        $this.ProjectList.Width = $this.Width - 4
        $this.ProjectList.SetPosition(2, $y)
        
        # Load projects
        $projects = $this.ProjectService.GetAllProjects() | Where-Object { -not $_.Deleted -and $_.ID2 } | Sort-Object Nickname
        $this.ProjectList.SetItems($projects)
        $this.ProjectList.ItemRenderer = {
            param($project)
            return "$($project.Nickname) - $($project.ID2)"
        }
        
        # Pre-select if editing existing project entry
        if ($this.ExistingEntry -and $this.ExistingEntry.IsProjectEntry()) {
            for ($i = 0; $i -lt $this.ProjectList.Items.Count; $i++) {
                if ($this.ProjectList.Items[$i].ID2 -eq $this.ExistingEntry.ID2) {
                    $this.ProjectList.SelectIndex($i)
                    break
                }
            }
        }
        
        $this.AddChild($this.ProjectList)
        
        # ID2 input (for non-project mode)
        $this.ID2Input = [TextBox]::new()
        $this.ID2Input.Width = 10
        $this.ID2Input.Placeholder = "ID2 Code"
        $this.ID2Input.SetPosition(2, $y)
        $this.ID2Input.IsVisible = $false  # Hidden initially
        
        # Pre-fill if editing existing non-project entry
        if ($this.ExistingEntry -and -not $this.ExistingEntry.IsProjectEntry()) {
            $this.ID2Input.Text = $this.ExistingEntry.ID2
            $this.IsProjectMode = $false
        }
        
        $this.AddChild($this.ID2Input)
        
        $y += 7
        
        # Week display
        $monday = $this.WeekFriday.AddDays(-4)
        $weekLabel = "Week: $($monday.ToString('MM/dd')) - $($this.WeekFriday.ToString('MM/dd/yyyy'))"
        $this.AddText($weekLabel, 2, $y)
        $y += 2
        
        # Day inputs
        $inputY = $y
        $inputX = 2
        $dayWidth = 10
        
        # Monday
        $this.AddText("Monday", $inputX, $inputY)
        $this.MondayInput = [TextBox]::new()
        $this.MondayInput.Width = 6
        $this.MondayInput.SetPosition($inputX, $inputY + 1)
        if ($this.ExistingEntry) { $this.MondayInput.Text = $this.ExistingEntry.Monday.ToString() }
        $this.AddChild($this.MondayInput)
        $inputX += $dayWidth
        
        # Tuesday
        $this.AddText("Tuesday", $inputX, $inputY)
        $this.TuesdayInput = [TextBox]::new()
        $this.TuesdayInput.Width = 6
        $this.TuesdayInput.SetPosition($inputX, $inputY + 1)
        if ($this.ExistingEntry) { $this.TuesdayInput.Text = $this.ExistingEntry.Tuesday.ToString() }
        $this.AddChild($this.TuesdayInput)
        $inputX += $dayWidth
        
        # Wednesday
        $this.AddText("Wednesday", $inputX, $inputY)
        $this.WednesdayInput = [TextBox]::new()
        $this.WednesdayInput.Width = 6
        $this.WednesdayInput.SetPosition($inputX, $inputY + 1)
        if ($this.ExistingEntry) { $this.WednesdayInput.Text = $this.ExistingEntry.Wednesday.ToString() }
        $this.AddChild($this.WednesdayInput)
        $inputX += $dayWidth
        
        # Thursday
        $this.AddText("Thursday", $inputX, $inputY)
        $this.ThursdayInput = [TextBox]::new()
        $this.ThursdayInput.Width = 6
        $this.ThursdayInput.SetPosition($inputX, $inputY + 1)
        if ($this.ExistingEntry) { $this.ThursdayInput.Text = $this.ExistingEntry.Thursday.ToString() }
        $this.AddChild($this.ThursdayInput)
        $inputX += $dayWidth
        
        # Friday
        $this.AddText("Friday", $inputX, $inputY)
        $this.FridayInput = [TextBox]::new()
        $this.FridayInput.Width = 6
        $this.FridayInput.SetPosition($inputX, $inputY + 1)
        if ($this.ExistingEntry) { $this.FridayInput.Text = $this.ExistingEntry.Friday.ToString() }
        $this.AddChild($this.FridayInput)
        
        $y = $inputY + 3
        
        # Buttons
        $buttonY = $this.Height - 4
        $dialog = $this
        
        $this.SaveButton = [Button]::new("Save")
        $this.SaveButton.SetPosition($this.Width - 20, $buttonY)
        $this.SaveButton.OnClick = { $dialog.Save() }.GetNewClosure()
        $this.AddChild($this.SaveButton)
        
        $this.CancelButton = [Button]::new("Cancel") 
        $this.CancelButton.SetPosition($this.Width - 10, $buttonY)
        $this.CancelButton.OnClick = { $dialog.Cancel() }.GetNewClosure()
        $this.AddChild($this.CancelButton)
        
        # Set initial visibility based on mode
        $this.UpdateModeVisibility()
        
        # Focus appropriate field based on today
        $today = [DateTime]::Now
        if ($today.Date -le $this.WeekFriday.Date -and $today.Date -ge $this.WeekFriday.AddDays(-4).Date) {
            # Current week - focus today's input
            switch ($today.DayOfWeek) {
                Monday { $this.MondayInput.Focus() }
                Tuesday { $this.TuesdayInput.Focus() }
                Wednesday { $this.WednesdayInput.Focus() }
                Thursday { $this.ThursdayInput.Focus() }
                Friday { $this.FridayInput.Focus() }
                default { 
                    if ($this.IsProjectMode) { $this.ProjectList.Focus() }
                    else { $this.ID2Input.Focus() }
                }
            }
        } else {
            # Different week - focus project/ID2 selection
            if ($this.IsProjectMode) { $this.ProjectList.Focus() }
            else { $this.ID2Input.Focus() }
        }
        
        # Key bindings
        $this.AddKeyBinding([ConsoleKey]::Tab, { $this.ToggleMode() })
        $this.AddKeyBinding([ConsoleKey]::Enter, { $this.Save() })
        $this.AddKeyBinding([ConsoleKey]::Escape, { $this.Cancel() })
    }
    
    [void] ToggleMode() {
        $this.IsProjectMode = -not $this.IsProjectMode
        $this.UpdateModeVisibility()
        
        if ($this.IsProjectMode) {
            $this.ProjectList.Focus()
        } else {
            $this.ID2Input.Focus()
        }
    }
    
    [void] UpdateModeVisibility() {
        $this.ProjectList.IsVisible = $this.IsProjectMode
        $this.ID2Input.IsVisible = -not $this.IsProjectMode
        $this.Invalidate()
    }
    
    [decimal] ParseHours([string]$text) {
        if ([string]::IsNullOrWhiteSpace($text)) { return 0 }
        $hours = 0
        if ([decimal]::TryParse($text, [ref]$hours)) {
            return $hours
        }
        return 0
    }
    
    [void] Save() {
        # Determine ID2
        if ($this.IsProjectMode) {
            $selected = $this.ProjectList.GetSelectedItem()
            if (-not $selected) {
                $this.ServiceContainer.GetService('ScreenManager').ShowMessage("Please select a project", "Error")
                return
            }
            $this.SelectedID2 = $selected.ID2
        } else {
            $this.SelectedID2 = $this.ID2Input.Text.Trim().ToUpper()
            if ([string]::IsNullOrWhiteSpace($this.SelectedID2)) {
                $this.ServiceContainer.GetService('ScreenManager').ShowMessage("Please enter an ID2 code", "Error")
                return
            }
            if ($this.SelectedID2.Length -lt 3 -or $this.SelectedID2.Length -gt 5) {
                $this.ServiceContainer.GetService('ScreenManager').ShowMessage("ID2 code must be 3-5 characters", "Error")
                return
            }
            
            # Add to time codes if new
            $this.TimeService.AddTimeCode($this.SelectedID2)
        }
        
        # Parse hours
        $data = @{
            WeekEndingFriday = $this.WeekFriday.ToString("yyyyMMdd")
            ID2 = $this.SelectedID2
            Monday = $this.ParseHours($this.MondayInput.Text)
            Tuesday = $this.ParseHours($this.TuesdayInput.Text)
            Wednesday = $this.ParseHours($this.WednesdayInput.Text)
            Thursday = $this.ParseHours($this.ThursdayInput.Text)
            Friday = $this.ParseHours($this.FridayInput.Text)
        }
        
        # Call save callback
        if ($this.OnSave) {
            & $this.OnSave $data
        }
    }
    
    [void] Cancel() {
        if ($this.OnCancel) {
            & $this.OnCancel
        }
    }
    
    [void] AddText([string]$text, [int]$x, [int]$y) {
        # Helper to add static text to dialog
        # This would be rendered in OnRender()
    }
}