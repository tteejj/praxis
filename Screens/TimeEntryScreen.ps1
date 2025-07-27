# TimeEntryScreen.ps1 - Time entry screen based on working ProjectsScreen

class TimeEntryScreen : Screen {
    [MinimalDataGrid]$TimeGrid
    [DateTime]$CurrentWeekFriday
    [TimeTrackingService]$TimeService
    [ProjectService]$ProjectService
    [EventBus]$EventBus
    hidden [hashtable]$EventSubscriptions = @{}
    
    TimeEntryScreen() : base() {
        $this.Title = "Time Entry"
    }
    
    [void] OnInitialize() {
        # Get services
        $this.TimeService = $this.ServiceContainer.GetService("TimeTrackingService")
        $this.ProjectService = $this.ServiceContainer.GetService("ProjectService")
        $this.EventBus = $this.ServiceContainer.GetService('EventBus')
        
        # Set to last week to show sample data (temporary for testing)
        # TODO: Remove this and use current week when we have current week data
        $this.CurrentWeekFriday = $this.TimeService.GetCurrentWeekFriday().AddDays(-7)
        
        # Subscribe to events
        if ($this.EventBus) {
            $screen = $this
            
            # Subscribe to time entry updates
            $this.EventSubscriptions['TimeEntryUpdated'] = $this.EventBus.Subscribe('timeentry.updated', {
                param($sender, $eventData)
                $screen.RefreshGrid()
            }.GetNewClosure())
        }
        
        # Create MinimalDataGrid with columns
        $this.TimeGrid = [MinimalDataGrid]::new()
        $this.TimeGrid.Title = $this.GetWeekTitle()
        $this.TimeGrid.ShowBorder = $false  # MainScreen draws the border
        $this.TimeGrid.BorderType = [BorderType]::None
        
        # Initialize the TimeGrid with ServiceContainer to get theme
        $this.TimeGrid.Initialize($this.ServiceContainer)
        
        # Get current day of week for highlighting
        $today = [DateTime]::Today
        $currentDayOfWeek = $today.DayOfWeek
        $isCurrentWeek = $this.IsCurrentWeek()
        
        # Define columns for time entry grid with day highlighting
        $columns = @(
            @{ Name = "Name"; Header = "Name"; Width = 30; Getter = { param($item) $item.Name } }
            @{ Name = "ID1"; Header = "ID1"; Width = 10; Getter = { param($item) $item.ID1 } }
            @{ Name = "ID2"; Header = "ID2"; Width = 15; Getter = { param($item) $item.ID2 } }
            @{ 
                Name = "Monday"
                Header = if ($isCurrentWeek -and $currentDayOfWeek -eq [DayOfWeek]::Monday) { "▸Mon" } else { "Mon" }
                Width = 6
                Getter = { param($item) if ($item.Monday -gt 0) { $item.Monday.ToString("F1") } else { "" } }
            }
            @{ 
                Name = "Tuesday"
                Header = if ($isCurrentWeek -and $currentDayOfWeek -eq [DayOfWeek]::Tuesday) { "▸Tue" } else { "Tue" }
                Width = 6
                Getter = { param($item) if ($item.Tuesday -gt 0) { $item.Tuesday.ToString("F1") } else { "" } }
            }
            @{ 
                Name = "Wednesday"
                Header = if ($isCurrentWeek -and $currentDayOfWeek -eq [DayOfWeek]::Wednesday) { "▸Wed" } else { "Wed" }
                Width = 6
                Getter = { param($item) if ($item.Wednesday -gt 0) { $item.Wednesday.ToString("F1") } else { "" } }
            }
            @{ 
                Name = "Thursday"
                Header = if ($isCurrentWeek -and $currentDayOfWeek -eq [DayOfWeek]::Thursday) { "▸Thu" } else { "Thu" }
                Width = 6
                Getter = { param($item) if ($item.Thursday -gt 0) { $item.Thursday.ToString("F1") } else { "" } }
            }
            @{ 
                Name = "Friday"
                Header = if ($isCurrentWeek -and $currentDayOfWeek -eq [DayOfWeek]::Friday) { "▸Fri" } else { "Fri" }
                Width = 6
                Getter = { param($item) if ($item.Friday -gt 0) { $item.Friday.ToString("F1") } else { "" } }
            }
            @{ Name = "Total"; Header = "Total"; Width = 7; Getter = { param($item) $item.Total.ToString("F1") } }
        )
        $this.TimeGrid.SetColumns($columns)
        $this.AddChild($this.TimeGrid)
        
        # Load initial data
        $this.RefreshGrid()
        
        # Register shortcuts
        $this.RegisterShortcuts()
    }
    
    [void] OnBoundsChanged() {
        if (-not $this.TimeGrid) { return }
        
        if ($global:Logger) {
            $global:Logger.Debug("TimeEntryScreen.OnBoundsChanged: Bounds=($($this.X),$($this.Y),$($this.Width),$($this.Height))")
        }
        
        # Grid uses full height now that buttons are removed
        $this.TimeGrid.SetBounds($this.X, $this.Y, $this.Width, $this.Height)
    }
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        
        # Refresh data when activated
        $this.RefreshGrid()
        if ($this.TimeGrid) {
            $this.TimeGrid.Focus()
        }
    }
    
    [string] GetWeekTitle() {
        $monday = $this.CurrentWeekFriday.AddDays(-4)
        $weekText = "Week of $($monday.ToString('MM/dd/yyyy')) to $($this.CurrentWeekFriday.ToString('MM/dd/yyyy'))"
        if ($this.IsCurrentWeek()) {
            $weekText += " (Current)"
        }
        return "Time Entry - $weekText"
    }
    
    [bool] IsCurrentWeek() {
        $currentFriday = $this.TimeService.GetCurrentWeekFriday()
        return $this.CurrentWeekFriday.Date -eq $currentFriday.Date
    }
    
    [void] RefreshGrid() {
        if ($global:Logger) {
            $global:Logger.Debug("TimeEntryScreen.RefreshGrid: Starting refresh for week $($this.CurrentWeekFriday.ToString('yyyyMMdd'))")
        }
        
        # Update title
        $this.TimeGrid.Title = $this.GetWeekTitle()
        
        # Update column headers to reflect current day
        $this.UpdateColumnHeaders()
        
        # Get entries for current week
        $weekString = $this.CurrentWeekFriday.ToString("yyyyMMdd")
        $entries = $this.TimeService.GetWeekEntries($weekString)
        
        if ($global:Logger) {
            $global:Logger.Debug("TimeEntryScreen.RefreshGrid: Got $($entries.Count) entries")
            if ($entries.Count -gt 0) {
                $global:Logger.Debug("TimeEntryScreen.RefreshGrid: First entry: Name=$($entries[0].Name) ID2=$($entries[0].ID2)")
            }
        }
        
        # Sort by: Projects first (by name), then non-projects (by ID2)
        $sorted = $entries | Sort-Object @(
            @{Expression = {if ($_.ID1 -eq "Internal") {1} else {0}}},
            @{Expression = {$_.Name}},
            @{Expression = {$_.ID2}}
        )
        
        if ($global:Logger) {
            $global:Logger.Debug("TimeEntryScreen.RefreshGrid: TimeGrid exists: $($this.TimeGrid -ne $null)")
            $global:Logger.Debug("TimeEntryScreen.RefreshGrid: TimeGrid bounds: ($($this.TimeGrid.X),$($this.TimeGrid.Y),$($this.TimeGrid.Width),$($this.TimeGrid.Height))")
        }
        
        # Clear and repopulate grid using proper DataGrid method
        $this.TimeGrid.SetItems($sorted)
        
        if ($global:Logger) {
            $global:Logger.Debug("TimeEntryScreen.RefreshGrid: After SetItems, TimeGrid.Items.Count = $($this.TimeGrid.Items.Count)")
        }
        
        $this.TimeGrid.Invalidate()
        $this.Invalidate()
        
        if ($global:Logger) {
            $global:Logger.Debug("TimeEntryScreen.RefreshGrid: Refresh complete, invalidated grid and screen")
        }
    }
    
    [void] ShowQuickEntry() {
        if ($global:Logger) {
            $global:Logger.Debug("TimeEntryScreen.ShowQuickEntry: Starting quick entry")
        }
        
        try {
            # Create quick entry dialog
            if ($global:Logger) {
                $global:Logger.Debug("TimeEntryScreen.ShowQuickEntry: CurrentWeekFriday = $($this.CurrentWeekFriday)")
                $global:Logger.Debug("TimeEntryScreen.ShowQuickEntry: QuickTimeEntryDialog type exists: $([QuickTimeEntryDialog] -as [type] -ne $null)")
            }
            
            # Try explicit casting
            $weekFriday = [DateTime]$this.CurrentWeekFriday
            if ($global:Logger) {
                $global:Logger.Debug("TimeEntryScreen.ShowQuickEntry: weekFriday type = $($weekFriday.GetType().Name), value = $weekFriday")
            }
            
            # Try workaround - create via Invoke-Expression or reflection
            if ($global:Logger) {
                $global:Logger.Debug("TimeEntryScreen.ShowQuickEntry: Attempting workaround creation")
            }
            
            # Workaround attempt
            $dialog = New-Object QuickTimeEntryDialog -ArgumentList $weekFriday
            
            # Initialize dialog with ServiceContainer for theme
            $dialog.Initialize($this.ServiceContainer)
            
            if ($global:Logger) {
                $global:Logger.Debug("TimeEntryScreen.ShowQuickEntry: Dialog created successfully")
            }
            
            $screen = $this
            $dialog.OnSave = {
                param($timeEntry)
                # Save the entry
                $screen.TimeService.UpdateTimeEntry($timeEntry)
                $screen.RefreshGrid()
            }.GetNewClosure()
            
            # Show dialog
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
                if ($global:Logger) {
                    $global:Logger.Debug("TimeEntryScreen.ShowQuickEntry: Dialog pushed to ScreenManager")
                }
            }
        }
        catch {
            if ($global:Logger) {
                $global:Logger.Error("TimeEntryScreen.ShowQuickEntry: Error creating dialog: $_")
            }
        }
    }
    
    [void] EditSelectedEntry() {
        $selected = $this.TimeGrid.GetSelectedItem()
        if (-not $selected) { return }
        
        # Create a project object from the selected entry
        $project = [PSCustomObject]@{
            Id = $selected.ID2
            Name = $selected.Name
            ID1 = $selected.ID1
            ID2 = $selected.ID2
        }
        
        # Create edit dialog with project
        $dialog = [TimeEntryDialog]::new($project)
        $dialog.Title = "Edit Time Entry - $($selected.Name)"
        
        # Pre-populate with current week's data if available
        # For now, just use the dialog for new entries on this project
        $screen = $this
        $dialog.OnSave = {
            param($timeEntry)
            # The dialog should handle saving via TimeTrackingService
            $screen.RefreshGrid()
        }.GetNewClosure()
        
        # Show dialog
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [string] OnRender() {
        if ($global:Logger) {
            $global:Logger.Debug("TimeEntryScreen.OnRender: Starting render, Children.Count = $($this.Children.Count)")
            $global:Logger.Debug("TimeEntryScreen.OnRender: TimeGrid exists = $($this.TimeGrid -ne $null)")
            if ($this.TimeGrid) {
                $global:Logger.Debug("TimeEntryScreen.OnRender: TimeGrid.Items.Count = $($this.TimeGrid.Items.Count)")
                $global:Logger.Debug("TimeEntryScreen.OnRender: TimeGrid bounds = ($($this.TimeGrid.X),$($this.TimeGrid.Y),$($this.TimeGrid.Width),$($this.TimeGrid.Height))")
            }
        }
        
        $result = ([Screen]$this).OnRender()
        
        if ($global:Logger) {
            $global:Logger.Debug("TimeEntryScreen.OnRender: Rendered content length = $($result.Length)")
        }
        return $result
    }
    
    [void] RegisterShortcuts() {
        $shortcutManager = $this.ServiceContainer.GetService('ShortcutManager')
        if ($shortcutManager) {
            $screen = $this
            
            # Q - Quick entry
            $quickAction = { $screen.ShowQuickEntry() }.GetNewClosure()
            
            $shortcutManager.RegisterShortcut(@{
                Id = "time.quick"
                Name = "Quick Entry"
                Description = "Quick time entry"
                KeyChar = 'q'
                Scope = [ShortcutScope]::Screen
                ScreenType = "TimeEntryScreen"
                Priority = 50
                Action = $quickAction
            })
            
            # E - Edit entry
            $shortcutManager.RegisterShortcut(@{
                Id = "time.edit"
                Name = "Edit Entry"
                Description = "Edit time entry"
                KeyChar = 'e'
                Scope = [ShortcutScope]::Screen
                ScreenType = "TimeEntryScreen"
                Priority = 50
                Action = { $screen.EditSelectedEntry() }.GetNewClosure()
            })
            
            # Left/Right arrows for week navigation
            $shortcutManager.RegisterShortcut(@{
                Id = "time.prevweek"
                Name = "Previous Week"
                Description = "Navigate to previous week"
                Key = [System.ConsoleKey]::LeftArrow
                Scope = [ShortcutScope]::Screen
                ScreenType = "TimeEntryScreen"
                Priority = 50
                Action = {
                    $screen.CurrentWeekFriday = $screen.CurrentWeekFriday.AddDays(-7)
                    $screen.RefreshGrid()
                }.GetNewClosure()
            })
            
            $shortcutManager.RegisterShortcut(@{
                Id = "time.nextweek"
                Name = "Next Week"
                Description = "Navigate to next week"
                Key = [System.ConsoleKey]::RightArrow
                Scope = [ShortcutScope]::Screen
                ScreenType = "TimeEntryScreen"
                Priority = 50
                Action = {
                    $screen.CurrentWeekFriday = $screen.CurrentWeekFriday.AddDays(7)
                    $screen.RefreshGrid()
                }.GetNewClosure()
            })
            
            $shortcutManager.RegisterShortcut(@{
                Id = "time.currentweek"
                Name = "Current Week"
                Description = "Navigate to current week"
                KeyChar = 'c'
                Scope = [ShortcutScope]::Screen
                ScreenType = "TimeEntryScreen"
                Priority = 50
                Action = {
                    $screen.CurrentWeekFriday = $screen.TimeService.GetCurrentWeekFriday()
                    $screen.RefreshGrid()
                }.GetNewClosure()
            })
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
                if ($global:Logger) {
                    $global:Logger.Debug("TimeEntryScreen.HandleInput: Q key detected, calling ShowQuickEntry()")
                }
                $this.ShowQuickEntry()
                return $true
            }
            ([ConsoleKey]::E) {
                $this.EditSelectedEntry()
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
            ([ConsoleKey]::C) {
                $this.CurrentWeekFriday = $this.TimeService.GetCurrentWeekFriday()
                $this.RefreshGrid()
                return $true
            }
        }
        
        return $false
    }
    
    [void] UpdateColumnHeaders() {
        # Update column headers to show current day indicator
        $today = [DateTime]::Today
        $currentDayOfWeek = $today.DayOfWeek
        $isCurrentWeek = $this.IsCurrentWeek()
        
        # Get current columns
        $columns = $this.TimeGrid.Columns
        
        # Update day column headers
        foreach ($col in $columns) {
            switch ($col.Name) {
                "Monday" { 
                    $col.Header = if ($isCurrentWeek -and $currentDayOfWeek -eq [DayOfWeek]::Monday) { "▸Mon" } else { "Mon" }
                }
                "Tuesday" { 
                    $col.Header = if ($isCurrentWeek -and $currentDayOfWeek -eq [DayOfWeek]::Tuesday) { "▸Tue" } else { "Tue" }
                }
                "Wednesday" { 
                    $col.Header = if ($isCurrentWeek -and $currentDayOfWeek -eq [DayOfWeek]::Wednesday) { "▸Wed" } else { "Wed" }
                }
                "Thursday" { 
                    $col.Header = if ($isCurrentWeek -and $currentDayOfWeek -eq [DayOfWeek]::Thursday) { "▸Thu" } else { "Thu" }
                }
                "Friday" { 
                    $col.Header = if ($isCurrentWeek -and $currentDayOfWeek -eq [DayOfWeek]::Friday) { "▸Fri" } else { "Fri" }
                }
            }
        }
        
        # Force header rebuild
        $this.TimeGrid._headerInvalid = $true
    }
}