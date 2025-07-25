# TimeEntryScreen.ps1 - Time entry screen based on working ProjectsScreen

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
    hidden [int]$ButtonSpacing = 2
    
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
        
        # Create DataGrid with columns
        $this.TimeGrid = [DataGrid]::new()
        $this.TimeGrid.Title = $this.GetWeekTitle()
        $this.TimeGrid.ShowBorder = $true
        $this.TimeGrid.ShowGridLines = $true
        
        # Define columns for time entry grid
        $columns = @(
            @{ Name = "Name"; Header = "Name"; Width = 30; Getter = { param($item) $item.Name } }
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
        
        # Focus the grid
        if ($this.TimeGrid.Items.Count -gt 0) {
            $this.TimeGrid.Focus()
        }
        
        # Register shortcuts
        $this.RegisterShortcuts()
    }
    
    [void] OnBoundsChanged() {
        if (-not $this.TimeGrid) { return }
        
        if ($global:Logger) {
            $global:Logger.Debug("TimeEntryScreen.OnBoundsChanged: Bounds=($($this.X),$($this.Y),$($this.Width),$($this.Height))")
        }
        
        # Calculate layout
        $gridHeight = $this.Height - $this.ButtonHeight - 1
        
        # Position grid
        $this.TimeGrid.SetBounds($this.X, $this.Y, $this.Width, $gridHeight)
        
        # Position buttons at bottom
        $buttonY = $this.Y + $this.Height - $this.ButtonHeight - 1
        $buttonWidth = 16
        $totalButtonWidth = ($buttonWidth * 4) + ($this.ButtonSpacing * 3)
        
        # Center buttons
        $buttonX = $this.X + [Math]::Floor(($this.Width - $totalButtonWidth) / 2)
        
        $this.PrevWeekButton.SetBounds($buttonX, $buttonY, $buttonWidth, $this.ButtonHeight)
        $buttonX += $buttonWidth + $this.ButtonSpacing
        
        $this.CurrentWeekButton.SetBounds($buttonX, $buttonY, $buttonWidth, $this.ButtonHeight)
        $buttonX += $buttonWidth + $this.ButtonSpacing
        
        $this.NextWeekButton.SetBounds($buttonX, $buttonY, $buttonWidth, $this.ButtonHeight)
        $buttonX += $buttonWidth + $this.ButtonSpacing
        
        $this.QuickEntryButton.SetBounds($buttonX, $buttonY, $buttonWidth, $this.ButtonHeight)
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
        return "Time Entry - Week of $($monday.ToString('MM/dd/yyyy')) to $($this.CurrentWeekFriday.ToString('MM/dd/yyyy'))"
    }
    
    [void] RefreshGrid() {
        if ($global:Logger) {
            $global:Logger.Debug("TimeEntryScreen.RefreshGrid: Starting refresh for week $($this.CurrentWeekFriday.ToString('yyyyMMdd'))")
        }
        
        # Update title
        $this.TimeGrid.Title = $this.GetWeekTitle()
        
        # Get entries for current week
        $weekString = $this.CurrentWeekFriday.ToString("yyyyMMdd")
        $entries = $this.TimeService.GetWeekEntries($weekString)
        
        if ($global:Logger) {
            $global:Logger.Debug("TimeEntryScreen.RefreshGrid: Got $($entries.Count) entries")
        }
        
        # Sort by: Projects first (by name), then non-projects (by ID2)
        $sorted = $entries | Sort-Object @(
            @{Expression = {if ($_.ID1 -eq "Internal") {1} else {0}}},
            @{Expression = {$_.Name}},
            @{Expression = {$_.ID2}}
        )
        
        # Clear and repopulate grid
        $this.TimeGrid.Items.Clear()
        foreach ($entry in $sorted) {
            $this.TimeGrid.Items.Add($entry)
        }
        
        $this.TimeGrid.Invalidate()
        $this.Invalidate()
    }
    
    [void] ShowQuickEntry() {
        # Create quick entry dialog
        $dialog = [QuickTimeEntryDialog]::new($this.CurrentWeekFriday)
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
        }
    }
    
    [void] EditSelectedEntry() {
        $selected = $this.TimeGrid.GetSelectedItem()
        if (-not $selected) { return }
        
        # Create edit dialog
        $dialog = [TimeEntryDialog]::new($this.CurrentWeekFriday, $selected.ID2)
        $dialog.OnSave = {
            $this.RefreshGrid()
        }.GetNewClosure()
        
        # Show dialog
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [string] OnRender() {
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
            $shortcutManager.RegisterShortcut(@{
                Id = "time.quick"
                Name = "Quick Entry"
                Description = "Quick time entry"
                KeyChar = 'q'
                Scope = [ShortcutScope]::Screen
                ScreenType = "TimeEntryScreen"
                Priority = 50
                Action = { $screen.ShowQuickEntry() }.GetNewClosure()
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
        }
        
        return $false
    }
}