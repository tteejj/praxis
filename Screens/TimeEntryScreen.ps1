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
        $this.TimeGrid.ShowBorder = $true   # Component responsible for own visual boundaries
        $this.TimeGrid.BorderType = [BorderType]::Rounded
        
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
        
        # Add as child first, then configure
        $this.AddChild($this.TimeGrid)
        $this.TimeGrid.SetColumns($columns)
        
        # Load initial data
        $this.RefreshGrid()
        
        # Register shortcuts
        $this.RegisterShortcuts()
    }
    
    [void] OnBoundsChanged() {
        if (-not $this.TimeGrid) { return }
        # Grid uses full screen area  
        $this.TimeGrid.SetBounds($this.X, $this.Y, $this.Width, $this.Height)
    }
    
    [void] OnActivated() {
        # Call base - this now handles focus via FocusFirst()
        ([Screen]$this).OnActivated()
        
        # Refresh data when activated (this will also select first item via SetItems)
        $this.RefreshGrid()
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
        # Update title
        $this.TimeGrid.Title = $this.GetWeekTitle()
        
        # Update column headers to reflect current day
        $this.UpdateColumnHeaders()
        
        # Get entries for current week
        $weekString = $this.CurrentWeekFriday.ToString("yyyyMMdd")
        $entries = $this.TimeService.GetWeekEntries($weekString)
        
        # Sort by: Projects first (by name), then non-projects (by ID2)
        $sorted = $entries | Sort-Object @(
            @{Expression = {if ($_.ID1 -eq "Internal") {1} else {0}}},
            @{Expression = {$_.Name}},
            @{Expression = {$_.ID2}}
        )
        # Clear and repopulate grid using proper DataGrid method
        $this.TimeGrid.SetItems($sorted)
        $this.TimeGrid.Invalidate()
        $this.Invalidate()
    }
    
    [void] ShowQuickEntry() {
        try {
            # Create quick entry dialog
            $dialog = [QuickTimeEntryDialog]::new($this.CurrentWeekFriday)
            
            # Initialize dialog with ServiceContainer for theme
            $dialog.Initialize($this.ServiceContainer)
            $screen = $this
            $dialog.OnSave = {
                param($timeEntry)
                # The dialog now saves entries directly via TimeService
                $screen.RefreshGrid()
            }.GetNewClosure()
            
            # Show dialog
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
            }
        }
        catch {
            if ($global:Logger) {
                $global:Logger.Error("TimeEntryScreen.ShowQuickEntry: Error creating dialog: $_")
            }
        }
    }
    
    [void] NewTimeEntry() {
        # Show options dialog first
        $optionsDialog = [TimeEntryOptionsDialog]::new()
        $screen = $this
        
        $optionsDialog.OnOptionSelected = {
            param($option)
            
            # Close the options dialog first
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
            
            if ($option.Type -eq "projects") {
                # Show project selection
                $projects = $screen.ProjectService.GetAllProjects() | Where-Object { -not $_.Deleted }
                if ($projects.Count -eq 0) {
                    if ($global:Logger) {
                        $global:Logger.Warning("No projects available for time entry")
                    }
                    return
                }
                
                $dialog = [SelectionDialog]::new("Select Project", "Choose a project for time entry:")
                $dialog.SetItems($projects)
                $dialog.ItemRenderer = { param($p) "$($p.FullProjectName) [$($p.ID2)]" }
                
                $dialog.OnSelect = {
                    param($project)
                    # Close selection dialog
                    if ($global:ScreenManager) {
                        $global:ScreenManager.Pop()
                    }
                    
                    # Create time entry dialog for selected project
                    $entryDialog = [TimeEntryDialog]::new($project)
                    $entryDialog.Title = "New Time Entry - $($project.FullProjectName)"
                    
                    $entryDialog.OnSave = {
                        param($timeEntry)
                        # Add to time service
                        $screen.TimeService.AddTimeEntry($timeEntry)
                        $screen.RefreshGrid()
                    }.GetNewClosure()
                    
                    if ($global:ScreenManager) {
                        $global:ScreenManager.Push($entryDialog)
                    }
                }.GetNewClosure()
                
                if ($global:ScreenManager) {
                    $global:ScreenManager.Push($dialog)
                }
            }
            elseif ($option.Type -eq "manual") {
                # Show manual entry dialog
                $manualDialog = [ManualTimeEntryDialog]::new()
                
                $manualDialog.OnSave = {
                    param($timeEntry)
                    $screen.RefreshGrid()
                }.GetNewClosure()
                
                if ($global:ScreenManager) {
                    $global:ScreenManager.Push($manualDialog)
                }
            }
        }.GetNewClosure()
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($optionsDialog)
        }
    }
    
    [void] DeleteSelectedEntry() {
        $selected = $this.TimeGrid.GetSelectedItem()
        if (-not $selected) { return }
        
        # Show confirmation dialog
        $message = "Delete time entry for $($selected.Name)?`n`nDate: $($selected.Day)`nHours: $($selected.Total)"
        $dialog = [ConfirmationDialog]::new($message)
        
        $screen = $this
        $projectId = $selected.ID2
        $date = $selected.FullDate
        
        $dialog.OnPrimary = {
            # Find and delete the entry
            $entries = $screen.TimeService.GetTimeEntriesByProject($projectId)
            foreach ($entry in $entries) {
                if ($entry.Date.Date -eq $date.Date) {
                    $screen.TimeService.DeleteTimeEntry($entry)
                    break
                }
            }
            $screen.RefreshGrid()
        }.GetNewClosure()
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] EditSelectedEntry() {
        $selected = $this.TimeGrid.GetSelectedItem()
        if (-not $selected) { return }
        
        # For editing, we need to find an actual time entry for a specific day
        # Let's create a simple date selection dialog or use the first day with hours
        $entries = $this.TimeService.GetTimeEntriesByProject($selected.ID2)
        
        # Find entries for current week
        $weekStart = $this.CurrentWeekFriday.AddDays(-4).Date
        $weekEnd = $this.CurrentWeekFriday.Date
        
        $weekEntries = $entries | Where-Object { 
            $_.Date -ge $weekStart -and $_.Date -le $weekEnd 
        }
        
        if ($weekEntries.Count -eq 0) {
            # No entries to edit, create new instead
            $this.NewTimeEntryForProject($selected)
            return
        }
        
        # For now, edit the first entry found
        $entryToEdit = $weekEntries[0]
        
        # Create a project object from the selected entry
        $project = [PSCustomObject]@{
            Id = $selected.ID2
            Name = $selected.Name
            ID1 = $selected.ID1
            ID2 = $selected.ID2
            FullProjectName = $selected.Name
        }
        
        # Create edit dialog with project and existing entry
        $dialog = [TimeEntryDialog]::new($project, $entryToEdit)
        $dialog.Title = "Edit Time Entry - $($selected.Name)"
        
        $screen = $this
        $dialog.OnSave = {
            param($timeEntry)
            # The dialog handles updating via TimeTrackingService
            $screen.RefreshGrid()
        }.GetNewClosure()
        
        # Show dialog
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] NewTimeEntryForProject($selected) {
        # Create a project object from the selected entry
        $project = [PSCustomObject]@{
            Id = $selected.ID2
            Name = $selected.Name
            ID1 = $selected.ID1
            ID2 = $selected.ID2
            FullProjectName = $selected.Name
        }
        
        # Create new entry dialog
        $dialog = [TimeEntryDialog]::new($project)
        $dialog.Title = "New Time Entry - $($selected.Name)"
        
        $screen = $this
        $dialog.OnSave = {
            param($timeEntry)
            # Add to time service
            $screen.TimeService.AddTimeEntry($timeEntry)
            $screen.RefreshGrid()
        }.GetNewClosure()
        
        # Show dialog
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [string] OnRender() {
        $result = ([Screen]$this).OnRender()
        return $result
    }
    
    [void] RegisterShortcuts() {
        $shortcutManager = $this.ServiceContainer.GetService('ShortcutManager')
        if ($shortcutManager) {
            # DO NOT use a temp variable - use $this directly in Actions to avoid closure issues
            
            # Q - Quick entry
            $shortcutManager.RegisterShortcut(@{
                Id = "time.quick"
                Name = "Quick Entry"
                Description = "Quick time entry"
                KeyChar = 'q'
                Scope = [ShortcutScope]::Screen
                ScreenType = "TimeEntryScreen"
                Priority = 50
                Action = { $this.ShowQuickEntry() }.GetNewClosure()
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
                Action = { $this.EditSelectedEntry() }.GetNewClosure()
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
                    $this.CurrentWeekFriday = $this.CurrentWeekFriday.AddDays(-7)
                    $this.RefreshGrid()
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
                    $this.CurrentWeekFriday = $this.CurrentWeekFriday.AddDays(7)
                    $this.RefreshGrid()
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
            
            # N - New entry
            $shortcutManager.RegisterShortcut(@{
                Id = "time.new"
                Name = "New Entry"
                Description = "Add new time entry"
                KeyChar = 'n'
                Scope = [ShortcutScope]::Screen
                ScreenType = "TimeEntryScreen"
                Priority = 50
                Action = { $this.NewTimeEntry() }.GetNewClosure()
            })
            
            # D - Delete entry
            $shortcutManager.RegisterShortcut(@{
                Id = "time.delete"
                Name = "Delete Entry"
                Description = "Delete selected time entry"
                KeyChar = 'd'
                Scope = [ShortcutScope]::Screen
                ScreenType = "TimeEntryScreen"
                Priority = 50
                Action = { $this.DeleteSelectedEntry() }.GetNewClosure()
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
        
        # Force grid rebuild
        $this.TimeGrid.Invalidate()
    }
}