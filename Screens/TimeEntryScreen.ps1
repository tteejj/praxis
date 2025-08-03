# TimeEntryScreen.ps1 - Time entry screen using CRUDScreen base class

class TimeEntryScreen : CRUDScreen {
    [DateTime]$CurrentWeekFriday
    [ProjectService]$ProjectService
    
    TimeEntryScreen() : base("TimeTrackingService", "TimeEntry") {
        $this.Title = "Time Entry"
    }
    
    # Override OnInitialize to inject additional services and setup
    [void] OnInitialize() {
        # Call base initialization first (handles TimeTrackingService and EventBus)
        ([CRUDScreen]$this).OnInitialize()
        
        # Inject additional services needed by TimeEntryScreen
        $this.ProjectService = $this.GetService("ProjectService")
        
        # Set to last week to show sample data (temporary for testing)
        # TODO: Remove this and use current week when we have current week data
        $this.CurrentWeekFriday = $this.DataService.GetCurrentWeekFriday().AddDays(-7)
    }
    
    # Override SetupDataGrid to use UnifiedList with time entry columns
    [void] SetupDataGrid() {
        # Create UnifiedList in DataGrid mode
        $this.DataGrid = [UnifiedList]::new([UnifiedListMode]::DataGrid)
        $this.DataGrid.Title = $this.GetWeekTitle()
        $this.DataGrid.ShowBorder = $false   # Remove borders per requirements
        $this.DataGrid.ShowHeader = $true
        $this.DataGrid.ShowColumnSeparators = $false
        
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
        
        $this.DataGrid.SetColumns($columns)
        $this.DataGrid.Initialize($global:ServiceContainer)
        $this.AddChild($this.DataGrid)
    }
    
    # Override LoadData to implement time entry specific data loading
    [void] LoadData() {
        # Update title to reflect current week
        $this.DataGrid.Title = $this.GetWeekTitle()
        
        # Update column headers to reflect current day
        $this.UpdateColumnHeaders()
        
        # Get entries for current week
        $weekString = $this.CurrentWeekFriday.ToString("yyyyMMdd")
        $entries = $this.DataService.GetWeekEntries($weekString)
        
        # Sort by: Projects first (by name), then non-projects (by ID2)
        $sorted = $entries | Sort-Object @(
            @{Expression = {if ($_.ID1 -eq "Internal") {1} else {0}}},
            @{Expression = {$_.Name}},
            @{Expression = {$_.ID2}}
        )
        
        $this.DataGrid.SetItems($sorted)
        $this.DataGrid.Invalidate()
        $this.Invalidate()
    }
    
    # Override CRUD operations for time entry specific behavior
    [void] NewItem() {
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
                if ($global:ScreenManager) {
                    $global:ScreenManager.Push($manualDialog)
                }
            }
        }.GetNewClosure()
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($optionsDialog)
        }
    }
    
    [void] EditItem() {
        $selected = $this.GetSelectedItem()
        if (-not $selected) { return }
        
        # For editing, we need to find an actual time entry for a specific day
        # Let's create a simple date selection dialog or use the first day with hours
        $entries = $this.DataService.GetTimeEntriesByProject($selected.ID2)
        
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
        
        # Show dialog
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    # Override PerformDelete for time entry specific behavior
    [void] PerformDelete($itemId) {
        $selected = $this.GetSelectedItem()
        if (-not $selected) { return }
        
        # Find and delete the entry
        $entries = $this.DataService.GetTimeEntriesByProject($selected.ID2)
        
        # Find entries for current week and delete them
        $weekStart = $this.CurrentWeekFriday.AddDays(-4).Date
        $weekEnd = $this.CurrentWeekFriday.Date
        
        $weekEntries = $entries | Where-Object { 
            $_.Date -ge $weekStart -and $_.Date -le $weekEnd 
        }
        
        foreach ($entry in $weekEntries) {
            $this.DataService.DeleteTimeEntry($entry)
        }
    }
    
    # Time entry specific methods
    [string] GetWeekTitle() {
        $monday = $this.CurrentWeekFriday.AddDays(-4)
        $weekText = "Week of $($monday.ToString('MM/dd/yyyy')) to $($this.CurrentWeekFriday.ToString('MM/dd/yyyy'))"
        if ($this.IsCurrentWeek()) {
            $weekText += " (Current)"
        }
        return "Time Entry - $weekText"
    }
    
    [bool] IsCurrentWeek() {
        $currentFriday = $this.DataService.GetCurrentWeekFriday()
        return $this.CurrentWeekFriday.Date -eq $currentFriday.Date
    }
    
    [void] ShowQuickEntry() {
        try {
            # Create quick entry dialog
            $dialog = [QuickTimeEntryDialog]::new($this.CurrentWeekFriday)
            
            # Initialize dialog with ServiceContainer for theme
            $dialog.Initialize($this.ServiceContainer)
            
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
        
        # Show dialog
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] UpdateColumnHeaders() {
        # Update column headers to show current day indicator
        $today = [DateTime]::Today
        $currentDayOfWeek = $today.DayOfWeek
        $isCurrentWeek = $this.IsCurrentWeek()
        
        # Get current columns
        $columns = $this.DataGrid.Columns
        
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
        $this.DataGrid.Invalidate()
    }
    
    # Override custom input handling for time entry specific shortcuts
    [bool] HandleCustomInput([System.ConsoleKeyInfo]$keyInfo) {
        # Time entry specific shortcuts
        switch ($keyInfo.KeyChar) {
            'q' { $this.ShowQuickEntry(); return $true }
            'c' { 
                $this.CurrentWeekFriday = $this.DataService.GetCurrentWeekFriday()
                $this.LoadData()
                return $true
            }
        }
        
        return $false  # Not handled
    }
    
    # Compatibility methods for MainScreen integration
    [void] NewTimeEntry() { $this.NewItem() }
    [void] EditSelectedEntry() { $this.EditItem() }
    [void] DeleteSelectedEntry() { $this.DeleteItem() }
    [void] RefreshGrid() { $this.LoadData() }
}