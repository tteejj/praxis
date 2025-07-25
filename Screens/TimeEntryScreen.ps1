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
        
        # Initialize the TimeGrid with ServiceContainer to get theme
        $this.TimeGrid.Initialize($this.ServiceContainer)
        
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
        $this.PrevWeekButton.Initialize($this.ServiceContainer)
        $this.AddChild($this.PrevWeekButton)
        
        $this.CurrentWeekButton = [Button]::new("Current Week")
        $this.CurrentWeekButton.OnClick = { 
            $screen.CurrentWeekFriday = $screen.TimeService.GetCurrentWeekFriday()
            $screen.RefreshGrid()
        }.GetNewClosure()
        $this.CurrentWeekButton.Initialize($this.ServiceContainer)
        $this.AddChild($this.CurrentWeekButton)
        
        $this.NextWeekButton = [Button]::new("Next Week >")
        $this.NextWeekButton.OnClick = { 
            $screen.CurrentWeekFriday = $screen.CurrentWeekFriday.AddDays(7)
            $screen.RefreshGrid()
        }.GetNewClosure()
        $this.NextWeekButton.Initialize($this.ServiceContainer)
        $this.AddChild($this.NextWeekButton)
        
        $this.QuickEntryButton = [Button]::new("Quick Entry (Q)")
        $this.QuickEntryButton.IsDefault = $true
        $this.QuickEntryButton.OnClick = { $screen.ShowQuickEntry() }.GetNewClosure()
        $this.QuickEntryButton.Initialize($this.ServiceContainer)
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
        
        # Position grid - use relative positioning within the screen bounds
        $this.TimeGrid.SetBounds(0, 0, $this.Width, $gridHeight)
        
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
        
        # Create edit dialog - TimeEntryDialog expects a Project parameter, not DateTime and ID2
        # For now, use the parameterless constructor
        $dialog = [TimeEntryDialog]::new()
        $dialog.OnSave = {
            $this.RefreshGrid()
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
        }
        
        return $false
    }
}