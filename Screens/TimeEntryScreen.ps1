# TimeEntryScreen - Weekly time entry grid with quick entry

class TimeEntryScreen : Screen {
    [DataGrid]$TimeGrid
    [Button]$PrevWeekButton
    [Button]$NextWeekButton
    [Button]$CurrentWeekButton
    [Button]$QuickEntryButton
    [DateTime]$CurrentWeekFriday
    [TimeTrackingService]$TimeService
    [ProjectService]$ProjectService
    [EventBus]$EventBus
    hidden [hashtable]$EventSubscriptions = @{}
    
    # Layout
    hidden [int]$ButtonHeight = 3
    hidden [int]$StatusBarHeight = 1
    
    TimeEntryScreen() : base() {
        $this.Title = "Time Entry"
    }
    
    [void] OnInitialize() {
        # Get services
        $this.TimeService = $this.ServiceContainer.GetService("TimeTrackingService")
        $this.ProjectService = $this.ServiceContainer.GetService("ProjectService")
        $this.EventBus = $this.ServiceContainer.GetService('EventBus')
        
        # Set current week
        $this.CurrentWeekFriday = $this.TimeService.GetCurrentWeekFriday()
        
        # Subscribe to events
        if ($this.EventBus) {
            $screen = $this
            
            # Subscribe to time entry updates
            $this.EventSubscriptions['TimeEntryUpdated'] = $this.EventBus.Subscribe('timeentry.updated', {
                param($sender, $eventData)
                $screen.RefreshGrid()
            }.GetNewClosure())
        }
        
        # Create time grid
        $this.TimeGrid = [DataGrid]::new()
        $this.TimeGrid.ShowHeader = $true
        $this.TimeGrid.ShowBorder = $true
        $this.TimeGrid.Title = $this.GetWeekTitle()
        $this.TimeGrid.IsFocusable = $true
        
        # Set up columns: Name | ID1 | ID2 | Mon | Tue | Wed | Thu | Fri | Total
        $columns = @(
            @{ Name = "Name"; Header = "Name"; Width = 20; Getter = { param($item) $item.Name } }
            @{ Name = "ID1"; Header = "ID1"; Width = 10; Getter = { param($item) $item.ID1 } }
            @{ Name = "ID2"; Header = "ID2"; Width = 15; Getter = { param($item) $item.ID2 } }
            @{ Name = "Monday"; Header = "Mon"; Width = 6; Getter = { param($item) if ($item.Monday -gt 0) { $item.Monday.ToString("F1") } else { "" } } }
            @{ Name = "Tuesday"; Header = "Tue"; Width = 6; Getter = { param($item) if ($item.Tuesday -gt 0) { $item.Tuesday.ToString("F1") } else { "" } } }
            @{ Name = "Wednesday"; Header = "Wed"; Width = 6; Getter = { param($item) if ($item.Wednesday -gt 0) { $item.Wednesday.ToString("F1") } else { "" } } }
            @{ Name = "Thursday"; Header = "Thu"; Width = 6; Getter = { param($item) if ($item.Thursday -gt 0) { $item.Thursday.ToString("F1") } else { "" } } }
            @{ Name = "Friday"; Header = "Fri"; Width = 6; Getter = { param($item) if ($item.Friday -gt 0) { $item.Friday.ToString("F1") } else { "" } } }
            @{ Name = "Total"; Header = "Total"; Width = 7; Getter = { param($item) $item.Total.ToString("F1") } }
        )
        $this.TimeGrid.SetColumns($columns)
        $this.AddChild($this.TimeGrid)
        
        # Create navigation buttons
        $screen = $this  # Capture reference for closures
        
        $this.PrevWeekButton = [Button]::new("< Prev Week")
        $this.PrevWeekButton.OnClick = { 
            $screen.CurrentWeekFriday = $screen.CurrentWeekFriday.AddDays(-7)
            $screen.RefreshGrid()
        }.GetNewClosure()
        $this.AddChild($this.PrevWeekButton)
        
        $this.CurrentWeekButton = [Button]::new("Current Week")
        $this.CurrentWeekButton.OnClick = { 
            $screen.CurrentWeekFriday = $screen.TimeService.GetCurrentWeekFriday()
            $screen.RefreshGrid()
        }.GetNewClosure()
        $this.AddChild($this.CurrentWeekButton)
        
        $this.NextWeekButton = [Button]::new("Next Week >")
        $this.NextWeekButton.OnClick = { 
            $screen.CurrentWeekFriday = $screen.CurrentWeekFriday.AddDays(7)
            $screen.RefreshGrid()
        }.GetNewClosure()
        $this.AddChild($this.NextWeekButton)
        
        $this.QuickEntryButton = [Button]::new("Quick Entry (Q)")
        $this.QuickEntryButton.IsDefault = $true
        $this.QuickEntryButton.OnClick = { $screen.ShowQuickEntry() }.GetNewClosure()
        $this.AddChild($this.QuickEntryButton)
        
        # Load initial data
        $this.RefreshGrid()
    }
    
    [void] OnBoundsChanged() {
        if (-not $this.TimeGrid) { return }
        
        # Calculate layout
        $gridHeight = $this.Height - $this.ButtonHeight - $this.StatusBarHeight - 1
        
        # Position grid
        $this.TimeGrid.SetBounds($this.X, $this.Y, $this.Width, $gridHeight)
        
        # Position buttons at bottom
        $buttonY = $this.Y + $this.Height - $this.ButtonHeight - $this.StatusBarHeight
        $buttonWidth = 14
        $totalButtonWidth = ($buttonWidth * 4) + 3  # 4 buttons with spacing
        
        # Center buttons
        $buttonStartX = $this.X + [Math]::Floor(($this.Width - $totalButtonWidth) / 2)
        
        $this.PrevWeekButton.SetBounds($buttonStartX, $buttonY, $buttonWidth, $this.ButtonHeight)
        $this.CurrentWeekButton.SetBounds($buttonStartX + $buttonWidth + 1, $buttonY, $buttonWidth, $this.ButtonHeight)
        $this.NextWeekButton.SetBounds($buttonStartX + ($buttonWidth + 1) * 2, $buttonY, $buttonWidth, $this.ButtonHeight)
        $this.QuickEntryButton.SetBounds($buttonStartX + ($buttonWidth + 1) * 3, $buttonY, $buttonWidth, $this.ButtonHeight)
    }
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        
        # Refresh data and focus grid
        $this.RefreshGrid()
        if ($this.TimeGrid) {
            $this.TimeGrid.Focus()
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Let base handle first (for child components)
        if (([Screen]$this).HandleInput($key)) {
            return $true
        }
        
        # Handle screen-specific keys
        switch ($key.Key) {
            ([ConsoleKey]::Q) {
                $this.ShowQuickEntry()
                return $true
            }
            ([ConsoleKey]::LeftArrow) {
                if ($key.Modifiers -eq [ConsoleModifiers]::None) {
                    $this.CurrentWeekFriday = $this.CurrentWeekFriday.AddDays(-7)
                    $this.RefreshGrid()
                    return $true
                }
            }
            ([ConsoleKey]::RightArrow) {
                if ($key.Modifiers -eq [ConsoleModifiers]::None) {
                    $this.CurrentWeekFriday = $this.CurrentWeekFriday.AddDays(7)
                    $this.RefreshGrid()
                    return $true
                }
            }
            ([ConsoleKey]::Enter) {
                $this.EditSelectedEntry()
                return $true
            }
            ([ConsoleKey]::E) {
                $this.EditSelectedEntry()
                return $true
            }
        }
        
        return $false
    }
    
    [string] GetWeekTitle() {
        $monday = $this.CurrentWeekFriday.AddDays(-4)
        return "Time Entry - Week of $($monday.ToString('MM/dd/yyyy')) to $($this.CurrentWeekFriday.ToString('MM/dd/yyyy'))"
    }
    
    [void] RefreshGrid() {
        # Update title
        $this.TimeGrid.Title = $this.GetWeekTitle()
        
        # Get entries for current week
        $weekString = $this.CurrentWeekFriday.ToString("yyyyMMdd")
        $entries = $this.TimeService.GetWeekEntries($weekString)
        
        # Sort by: Projects first (by name), then non-projects (by ID2)
        $sorted = $entries | Sort-Object -Property @(
            @{Expression = { $_.IsProjectEntry() }; Descending = $true},
            @{Expression = { $_.Name }},
            @{Expression = { $_.ID2 }}
        )
        
        $this.TimeGrid.SetItems($sorted)
        $this.Invalidate()
    }
    
    [void] ShowQuickEntry() {
        # Create quick entry dialog
        $dialog = [QuickTimeEntryDialog]::new($this.CurrentWeekFriday)
        
        $screen = $this  # Capture reference for closure
        $dialog.OnSave = {
            param($timeData)
            
            # Add/update time entry
            $entry = $screen.TimeService.GetOrCreateTimeEntry($timeData.WeekEndingFriday, $timeData.ID2)
            
            # Update the specific day's hours
            switch ($timeData.DayOfWeek) {
                Monday { $entry.Monday = $timeData.Hours }
                Tuesday { $entry.Tuesday = $timeData.Hours }
                Wednesday { $entry.Wednesday = $timeData.Hours }
                Thursday { $entry.Thursday = $timeData.Hours }
                Friday { $entry.Friday = $timeData.Hours }
            }
            
            # Save through service
            $screen.TimeService.UpdateTimeEntry($entry)
            
            # Close dialog
            $screenManager = $screen.ServiceContainer.GetService("ScreenManager")
            if ($screenManager) {
                $screenManager.Pop()
            }
        }.GetNewClosure()
        
        $dialog.OnCancel = {
            $screenManager = $screen.ServiceContainer.GetService("ScreenManager")
            if ($screenManager) {
                $screenManager.Pop()
            }
        }.GetNewClosure()
        
        # Show dialog
        $screenManager = $this.ServiceContainer.GetService("ScreenManager")
        if ($screenManager) {
            $screenManager.Push($dialog)
        }
    }
    
    [void] EditSelectedEntry() {
        $selected = $this.TimeGrid.GetSelectedItem()
        if (-not $selected) { return }
        
        # Create edit dialog for the selected entry
        $dialog = [QuickTimeEntryDialog]::new($this.CurrentWeekFriday, $selected)
        
        $screen = $this  # Capture reference for closure
        $dialog.OnSave = {
            param($timeData)
            
            # Update all days for this entry
            $selected.Monday = $timeData.Monday
            $selected.Tuesday = $timeData.Tuesday
            $selected.Wednesday = $timeData.Wednesday
            $selected.Thursday = $timeData.Thursday
            $selected.Friday = $timeData.Friday
            
            # Save through service
            $screen.TimeService.UpdateTimeEntry($selected)
            
            # Close dialog
            $screenManager = $screen.ServiceContainer.GetService("ScreenManager")
            if ($screenManager) {
                $screenManager.Pop()
            }
        }.GetNewClosure()
        
        $dialog.OnCancel = {
            $screenManager = $screen.ServiceContainer.GetService("ScreenManager")
            if ($screenManager) {
                $screenManager.Pop()
            }
        }.GetNewClosure()
        
        # Show dialog
        $screenManager = $this.ServiceContainer.GetService("ScreenManager")
        if ($screenManager) {
            $screenManager.Push($dialog)
        }
    }
    
    [string] OnRender() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Render base screen first
        $null = $sb.Append(([Screen]$this).OnRender())
        
        # Render status bar at bottom
        $statusY = $this.Y + $this.Height - 1
        $null = $sb.Append([VT]::MoveTo($this.X, $statusY))
        
        # Get theme manager
        $theme = $this.ServiceContainer.GetService("ThemeManager")
        if ($theme) {
            $null = $sb.Append($theme.GetColor('border'))
        }
        $null = $sb.Append(' ' * $this.Width)  # Clear line
        
        # Show week totals
        $weekTotal = 0
        if ($this.TimeService) {
            $entries = $this.TimeService.GetWeekEntries($this.CurrentWeekFriday.ToString("yyyyMMdd"))
            foreach ($entry in $entries) {
                $weekTotal += $entry.Total
            }
        }
        
        $statusText = "Week Total: $($weekTotal.ToString('F1')) hours | Q: Quick Entry | E: Edit | ←/→: Navigate Weeks"
        $null = $sb.Append([VT]::MoveTo($this.X + 2, $statusY))
        $null = $sb.Append($statusText)
        $null = $sb.Append([VT]::Reset())
        
        return $sb.ToString()
    }
    
    # Handle special keys
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        # Let base class handle registered key bindings
        return $false
    }
}