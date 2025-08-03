# ProjectDetailScreen - Detailed project view with time tracking information
# Simplified version using minimal components

class ProjectDetailScreen : Screen {
    [Project]$Project = $null
    [MinimalDataGrid]$ProjectInfoGrid
    [MinimalDataGrid]$TimeEntriesGrid
    [MinimalStatusBar]$StatusBar
    
    # Services
    [ThemeManager]$ThemeManager
    [EventBus]$EventBus
    [TimeTrackingService]$TimeService
    
    ProjectDetailScreen() : base() {
        $this.Title = "Project Details"
    }
    
    ProjectDetailScreen([Project]$project) : base() {
        $this.Title = "Project Details - $($project.FullProjectName)"
        $this.Project = $project
    }
    
    [void] OnInitialize() {
        # Get services
        $this.ThemeManager = $this.ServiceContainer.GetService('ThemeManager')
        $this.EventBus = $this.ServiceContainer.GetService('EventBus')
        $this.TimeService = $this.ServiceContainer.GetService('TimeTrackingService')
        
        # Create project info grid
        $this.ProjectInfoGrid = [MinimalDataGrid]::new()
        $this.ProjectInfoGrid.Title = "Project Information"
        $this.ProjectInfoGrid.ShowHeader = $false
        # MinimalDataGrid doesn't have SelectionEnabled property
        
        # Set up project info columns
        $infoColumns = @(
            @{
                Name = "Property"
                Header = "Property"
                Width = 20
                Getter = { param($item) $item.Property }
            },
            @{
                Name = "Value"
                Header = "Value"
                Width = 60
                Getter = { param($item) $item.Value }
            }
        )
        $this.ProjectInfoGrid.SetColumns($infoColumns)
        $this.ProjectInfoGrid.Initialize($this.ServiceContainer)
        
        # Create time entries grid
        $this.TimeEntriesGrid = [MinimalDataGrid]::new()
        $this.TimeEntriesGrid.Title = "Time Entries"
        
        # Set up time entries columns
        $timeColumns = @(
            @{
                Name = "Date"
                Header = "Date"
                Width = 12
                Getter = { param($item) $item.Date.ToString("yyyy-MM-dd") }
            },
            @{
                Name = "Hours"
                Header = "Hours"
                Width = 8
                Getter = { param($item) "{0:N2}" -f $item.Hours }
            },
            @{
                Name = "Description"
                Header = "Description"
                Width = 50
                Getter = { param($item) $item.Description }
            }
        )
        $this.TimeEntriesGrid.SetColumns($timeColumns)
        $this.TimeEntriesGrid.Initialize($this.ServiceContainer)
        
        # Create status bar
        $this.StatusBar = [MinimalStatusBar]::new()
        $this.StatusBar.Initialize($this.ServiceContainer)
        
        # Add children
        $this.AddChild($this.ProjectInfoGrid)
        $this.AddChild($this.TimeEntriesGrid)
        $this.AddChild($this.StatusBar)
        
        # Load data
        $this.LoadProjectInfo()
        $this.LoadTimeEntries()
        
        # Register shortcuts
        # $this.RegisterShortcuts()  # Removed - deprecated
    }
    
    [void] RegisterShortcuts() {
        # $shortcutManager = $this.ServiceContainer.GetService('ShortcutManager')  # Removed - deprecated
        # if (-not $shortcutManager) { return }  # Removed - deprecated
        
        # $screen = $this
        
        # ESC: Go back
        # $shortcutManager.RegisterShortcut(@{
        #     Id = "projectdetail.back"
        #     Name = "Go Back"
        #     Description = "Return to projects list"
        #     Key = [System.ConsoleKey]::Escape
        #     ScreenType = "ProjectDetailScreen"
        #     Priority = 50
        #     Action = { 
        #         if ($global:ScreenManager) {
        #             $global:ScreenManager.Pop()
        #         }
        #     }
        # })
        
        # F5: Refresh
        # $shortcutManager.RegisterShortcut(@{
        #     Id = "projectdetail.refresh"
        #     Name = "Refresh"
        #     Description = "Refresh time entries"
        #     Key = [System.ConsoleKey]::F5
        #     ScreenType = "ProjectDetailScreen"
        #     Priority = 50
        #     Action = { 
        #         $screen.LoadProjectInfo()
        #         $screen.LoadTimeEntries()
        #     }
        # })
    }
    
    [void] OnBoundsChanged() {
        if (-not $this.ProjectInfoGrid -or -not $this.TimeEntriesGrid) { return }
        
        # Layout: Project info at top (fixed height), time entries fill rest, status bar at bottom
        $infoHeight = 8
        $statusHeight = 1
        $timeEntriesHeight = $this.Height - $infoHeight - $statusHeight
        
        # Project info grid
        $this.ProjectInfoGrid.SetBounds(
            $this.X,
            $this.Y,
            $this.Width,
            $infoHeight
        )
        
        # Time entries grid
        $this.TimeEntriesGrid.SetBounds(
            $this.X,
            $this.Y + $infoHeight,
            $this.Width,
            $timeEntriesHeight
        )
        
        # Status bar
        if ($this.StatusBar) {
            $this.StatusBar.SetBounds(
                $this.X,
                $this.Y + $this.Height - $statusHeight,
                $this.Width,
                $statusHeight
            )
        }
    }
    
    [void] LoadProjectInfo() {
        if (-not $this.Project) { return }
        
        # Create info items with null checks
        $infoItems = @(
            [PSCustomObject]@{ Property = "Name"; Value = if ($this.Project.FullProjectName) { $this.Project.FullProjectName } else { "Unnamed Project" } }
            [PSCustomObject]@{ Property = "ID"; Value = if ($this.Project.Id) { $this.Project.Id } else { "No ID" } }
            [PSCustomObject]@{ Property = "Created"; Value = if ($this.Project.DateCreated -and $this.Project.DateCreated -ne [DateTime]::MinValue) { $this.Project.DateCreated.ToString("yyyy-MM-dd") } else { "Unknown" } }
            [PSCustomObject]@{ Property = "Due Date"; Value = if ($this.Project.DateDue -and $this.Project.DateDue -ne [DateTime]::MinValue) { $this.Project.DateDue.ToString("yyyy-MM-dd") } else { "Not set" } }
            [PSCustomObject]@{ Property = "Note"; Value = if ($this.Project.Note) { $this.Project.Note } else { "No notes" } }
        )
        
        $this.ProjectInfoGrid.SetItems($infoItems)
    }
    
    [void] LoadTimeEntries() {
        if (-not $this.Project -or -not $this.TimeService) { 
            $this.TimeEntriesGrid.SetItems(@())
            return 
        }
        
        # Get all time entries and filter by project ID2
        $allEntries = $this.TimeService.TimeEntries
        $projectEntries = @()
        
        if ($this.Project.ID2) {
            # Filter entries by project ID2
            $projectEntries = $allEntries | Where-Object { $_.ID2 -eq $this.Project.ID2 }
            
            # Convert to display format with expanded date info
            $displayEntries = @()
            foreach ($entry in $projectEntries) {
                # Parse week ending date
                if ($entry.WeekEndingFriday -match '^(\d{4})(\d{2})(\d{2})$') {
                    $year = [int]$matches[1]
                    $month = [int]$matches[2]
                    $day = [int]$matches[3]
                    $weekDate = [DateTime]::new($year, $month, $day)
                    
                    # Create entries for each day with hours
                    if ($entry.Monday -gt 0) {
                        $displayEntries += [PSCustomObject]@{
                            Date = $weekDate.AddDays(-4)
                            Hours = $entry.Monday
                            Description = "Monday - Week ending $($weekDate.ToString('yyyy-MM-dd'))"
                        }
                    }
                    if ($entry.Tuesday -gt 0) {
                        $displayEntries += [PSCustomObject]@{
                            Date = $weekDate.AddDays(-3)
                            Hours = $entry.Tuesday
                            Description = "Tuesday - Week ending $($weekDate.ToString('yyyy-MM-dd'))"
                        }
                    }
                    if ($entry.Wednesday -gt 0) {
                        $displayEntries += [PSCustomObject]@{
                            Date = $weekDate.AddDays(-2)
                            Hours = $entry.Wednesday
                            Description = "Wednesday - Week ending $($weekDate.ToString('yyyy-MM-dd'))"
                        }
                    }
                    if ($entry.Thursday -gt 0) {
                        $displayEntries += [PSCustomObject]@{
                            Date = $weekDate.AddDays(-1)
                            Hours = $entry.Thursday
                            Description = "Thursday - Week ending $($weekDate.ToString('yyyy-MM-dd'))"
                        }
                    }
                    if ($entry.Friday -gt 0) {
                        $displayEntries += [PSCustomObject]@{
                            Date = $weekDate
                            Hours = $entry.Friday
                            Description = "Friday - Week ending $($weekDate.ToString('yyyy-MM-dd'))"
                        }
                    }
                }
            }
            
            # Sort by date descending
            if ($displayEntries.Count -gt 0) {
                $sorted = $displayEntries | Sort-Object Date -Descending
                $this.TimeEntriesGrid.SetItems($sorted)
            } else {
                $this.TimeEntriesGrid.SetItems(@())
            }
        } else {
            $this.TimeEntriesGrid.SetItems(@())
        }
        
        # Update status bar
        $this.UpdateStatusBar()
    }
    
    [void] UpdateStatusBar() {
        if (-not $this.StatusBar) { return }
        
        $totalHours = 0
        if ($this.TimeEntriesGrid.Items -and $this.TimeEntriesGrid.Items.Count -gt 0) {
            $totalHours = ($this.TimeEntriesGrid.Items | Measure-Object -Property Hours -Sum).Sum
        }
        
        $status = "Total Hours: {0:N2}" -f $totalHours
        if ($this.TimeEntriesGrid.Items) {
            $status += " | Entries: $($this.TimeEntriesGrid.Items.Count)"
        }
        
        # MinimalStatusBar uses properties, not SetStatus method
        $this.StatusBar.LeftText = $status
        $this.StatusBar.Invalidate()
    }
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        
        # Base Screen.OnActivated() already handles focusing first element
        # No additional focus logic needed - let the base implementation handle it
    }
    
    [string] GetHelpText() {
        return @"
Project Details Screen

Shortcuts:
  ESC    - Return to projects list
  F5     - Refresh time entries
  Tab    - Switch between grids
  
Navigation:
  Up/Down arrows to navigate entries
"@
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        # Handle Escape key to exit the detail screen
        if ($keyInfo.Key -eq [System.ConsoleKey]::Escape) {
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
            return $true
        }
        
        # Handle F5 to refresh
        if ($keyInfo.Key -eq [System.ConsoleKey]::F5) {
            $this.LoadProjectInfo()
            $this.LoadTimeEntries()
            return $true
        }
        
        return $false
    }
}