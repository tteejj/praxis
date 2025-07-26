# CommandPalette.ps1 - Fast command palette overlay

class CommandPalette : Container {
    [string]$SearchText = ""
    [ListBox]$ResultsList
    [System.Collections.ArrayList]$AllCommands
    [System.Collections.ArrayList]$FilteredCommands
    [scriptblock]$OnCommandSelected = {}
    [bool]$IsVisible = $false
    [EventBus]$EventBus
    [ThemeManager]$Theme
    
    # Layout
    hidden [int]$PaletteWidth = 60
    hidden [int]$PaletteHeight = 20
    hidden [int]$MaxResults = 15
    hidden [hashtable]$_colors = @{}
    
    # Version-based change detection
    hidden [int]$_dataVersion = 0
    hidden [int]$_lastRenderedVersion = -1
    hidden [string]$_cachedVersionRender = ""
    
    CommandPalette() : base() {
        $this.AllCommands = [System.Collections.ArrayList]::new()
        $this.FilteredCommands = [System.Collections.ArrayList]::new()
        $this.DrawBackground = $true
        
        # Create results list
        $this.ResultsList = [ListBox]::new()
        $this.ResultsList.ShowBorder = $false
        $this.ResultsList.ShowScrollbar = $true
        $this.ResultsList.ItemRenderer = {
            param($cmd)
            $name = $cmd.Name.PadRight(20)
            $desc = if ($cmd.Description.Length -gt 35) {
                $cmd.Description.Substring(0, 32) + "..."
            } else {
                $cmd.Description
            }
            return "$name $desc"
        }
        $this.AddChild($this.ResultsList)
    }
    
    [void] OnInitialize() {
        # Get services
        $this.EventBus = $this.ServiceContainer.GetService('EventBus')
        $this.Theme = $this.ServiceContainer.GetService('ThemeManager')
        
        # Subscribe to command registration events
        if ($this.EventBus) {
            $this.EventBus.Subscribe('command.registered', {
                param($sender, $eventData)
                if ($eventData.Name -and $eventData.Description -and $eventData.Action) {
                    $this.AddCommand($eventData.Name, $eventData.Description, $eventData.Action)
                }
            }.GetNewClosure())
        }
        
        # Initialize child components
        if ($this.ResultsList) {
            $this.ResultsList.Initialize($this.ServiceContainer)
        }
        
        # Set palette background if theme is available
        if ($this.Theme) {
            $this.Theme.Subscribe({ $this.OnThemeChanged() })
            $this.OnThemeChanged()
        }
        
        # Load default commands
        $this.LoadDefaultCommands()
    }
    
    [void] OnThemeChanged() {
        if ($this.Theme) {
            $this._colors = @{
                'menu.background' = $this.Theme.GetBgColor("menu.background")
                'border.focused' = $this.Theme.GetColor("border.focused")
                'accent' = $this.Theme.GetColor("accent")
                'foreground' = $this.Theme.GetColor("foreground")
                'disabled' = $this.Theme.GetColor("disabled")
            }
            $this.SetBackgroundColor($this._colors['menu.background'])
        }
        $this.Invalidate()
    }
    
    [void] LoadDefaultCommands() {
        # Store reference to this palette for use in scriptblocks
        $palette = $this
        
        # Add some default commands
        $this.AddCommand("new project", "Create a new project", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: Executing new project command")
            }
            
            # Publish event to switch to projects tab
            if ($palette.EventBus) {
                $palette.EventBus.Publish([EventNames]::TabChanged, @{ TabIndex = 0 })
            }
            
            # Create and show the dialog
            $dialog = [NewProjectDialog]::new()
            $dialog.OnCreate = {
                param($project)
                if ($global:Logger) {
                    $global:Logger.Info("Creating project: $($project.Name)")
                }
                # Add project via service
                $projectService = $global:ServiceContainer.GetService("ProjectService")
                if ($projectService) {
                    # Create proper Project object using single-parameter constructor
                    $newProject = $projectService.AddProject($project.Name)
                    
                    # Publish project created event
                    $eventBus = $global:ServiceContainer.GetService('EventBus')
                    if ($eventBus) {
                        $eventBus.Publish([EventNames]::ProjectCreated, @{ Project = $newProject })
                    }
                }
                # Close dialog
                if ($global:ScreenManager) {
                    $global:ScreenManager.Pop()
                }
            }.GetNewClosure()
            
            # Don't set OnCancel - BaseDialog handles ESC and closing automatically
            
            # Push dialog to screen manager
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
            }
        }.GetNewClosure())
        $this.AddCommand("new task", "Create a new task", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: Executing new task command")
            }
            
            # Publish event to switch to tasks tab
            if ($palette.EventBus) {
                $palette.EventBus.Publish([EventNames]::TabChanged, @{ TabIndex = 1 })
            }
            
            # Create and show the dialog directly (same pattern as new project)
            $dialog = [NewTaskDialog]::new()
            $dialog.OnCreate = {
                param($task)
                if ($global:Logger) {
                    $global:Logger.Info("Creating task: $($task.Title)")
                }
                # Create task via service
                $taskService = $global:ServiceContainer.GetService("TaskService")
                if ($taskService) {
                    $newTask = $taskService.CreateTask($task)
                    
                    # Publish task created event
                    $eventBus = $global:ServiceContainer.GetService('EventBus')
                    if ($eventBus) {
                        $eventBus.Publish([EventNames]::TaskCreated, @{ Task = $newTask })
                    }
                }
                # Close dialog
                if ($global:ScreenManager) {
                    $global:ScreenManager.Pop()
                }
            }.GetNewClosure()
            
            # Don't set OnCancel - BaseDialog handles ESC and closing automatically
            
            # Push dialog to screen manager
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
            }
        }.GetNewClosure())
        
        $this.AddCommand("edit project", "Edit selected project", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: Executing edit project command")
            }
            
            # Publish events
            if ($palette.EventBus) {
                $palette.EventBus.Publish([EventNames]::TabChanged, @{ TabIndex = 0 })
                $palette.EventBus.Publish([EventNames]::CommandExecuted, @{ 
                    Command = 'EditProject'
                    Target = 'ProjectsScreen'
                })
            }
        }.GetNewClosure())
        
        $this.AddCommand("edit task", "Edit selected task", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: Executing edit task command")
            }
            
            # Publish events
            if ($palette.EventBus) {
                $palette.EventBus.Publish([EventNames]::TabChanged, @{ TabIndex = 1 })
                $palette.EventBus.Publish([EventNames]::CommandExecuted, @{ 
                    Command = 'EditTask'
                    Target = 'TaskScreen'
                })
            }
        }.GetNewClosure())
        
        $this.AddCommand("delete project", "Delete selected project", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: Executing delete project command")
            }
            
            # Publish events
            if ($palette.EventBus) {
                $palette.EventBus.Publish([EventNames]::TabChanged, @{ TabIndex = 0 })
                $palette.EventBus.Publish([EventNames]::CommandExecuted, @{ 
                    Command = 'DeleteProject'
                    Target = 'ProjectsScreen'
                })
            }
        }.GetNewClosure())
        
        $this.AddCommand("delete task", "Delete selected task", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: Executing delete task command")
            }
            
            # Publish events
            if ($palette.EventBus) {
                $palette.EventBus.Publish([EventNames]::TabChanged, @{ TabIndex = 1 })
                $palette.EventBus.Publish([EventNames]::CommandExecuted, @{ 
                    Command = 'DeleteTask'
                    Target = 'TaskScreen'
                })
            }
        }.GetNewClosure())
        
        $this.AddCommand("time entry", "Go to time entry screen", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: Time entry command executed")
            }
            # Switch to time tab (tab index 2)
            if ($palette.EventBus) {
                $palette.EventBus.Publish([EventNames]::TabChanged, @{ TabIndex = 2 })
            }
        }.GetNewClosure())
        
        $this.AddCommand("quick time entry", "Quick time entry for today", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: Quick time entry command executed")
            }
            
            # Switch to time tab first
            if ($palette.EventBus) {
                $palette.EventBus.Publish([EventNames]::TabChanged, @{ TabIndex = 2 })
            }
            
            # Get current week Friday for time entry
            $timeService = $global:ServiceContainer.GetService("TimeTrackingService")
            $currentWeekFriday = if ($timeService) { 
                $timeService.GetCurrentWeekFriday() 
            } else { 
                # Fallback to current week's Friday
                $today = [DateTime]::Today
                $daysUntilFriday = ([int][DayOfWeek]::Friday - [int]$today.DayOfWeek + 7) % 7
                if ($daysUntilFriday -eq 0 -and $today.DayOfWeek -ne [DayOfWeek]::Friday) {
                    $daysUntilFriday = 7
                }
                $today.AddDays($daysUntilFriday)
            }
            
            # Create and show quick time entry dialog
            $dialog = [QuickTimeEntryDialog]::new($currentWeekFriday)
            $dialog.OnSave = {
                param($timeEntry)
                if ($global:Logger) {
                    $global:Logger.Info("Creating time entry: $($timeEntry.Hours) hours for project $($timeEntry.ProjectId)")
                }
                # Create time entry via service
                $timeService = $global:ServiceContainer.GetService("TimeTrackingService")
                if ($timeService) {
                    $timeService.AddTimeEntry($timeEntry)
                    
                    # Publish time entry created event
                    $eventBus = $global:ServiceContainer.GetService('EventBus')
                    if ($eventBus) {
                        $eventBus.Publish([EventNames]::TimeEntryUpdated, @{ TimeEntry = $timeEntry })
                    }
                }
                # Close dialog
                if ($global:ScreenManager) {
                    $global:ScreenManager.Pop()
                }
            }.GetNewClosure()
            
            # Push dialog to screen manager
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
            }
        }.GetNewClosure())
        
        $this.AddCommand("search", "Search in files", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: Search command executed")
            }
            # Publish search event for current screen to handle
            if ($palette.EventBus) {
                $palette.EventBus.Publish('command.search', $palette, @{})
            }
            $palette.Hide()
        }.GetNewClosure())
        
        $this.AddCommand("files", "Open file browser", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: Files command executed")
            }
            # Switch to files tab (tab index 3 - Projects, Tasks, Time, Files)
            if ($palette.EventBus) {
                $palette.EventBus.Publish([EventNames]::TabChanged, @{ TabIndex = 3 })
            }
        }.GetNewClosure())
        
        $this.AddCommand("text editor", "Open text editor", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: Text editor command executed")
            }
            # Switch to editor tab (tab index 4 - Projects, Tasks, Time, Files, Editor)
            if ($palette.EventBus) {
                $palette.EventBus.Publish([EventNames]::TabChanged, @{ TabIndex = 4 })
            }
        }.GetNewClosure())
        
        $this.AddCommand("editor", "Open text editor tab", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: Editor tab command executed")
            }
            # Switch to editor tab
            if ($palette.EventBus) {
                $palette.EventBus.Publish([EventNames]::TabChanged, @{ TabIndex = 4 })
            }
        }.GetNewClosure())
        
        $this.AddCommand("settings", "Open settings", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: Settings command executed")
            }
            # Switch to settings tab (tab index 5 - Projects, Tasks, Time, Files, Editor, Settings)
            if ($palette.EventBus) {
                $palette.EventBus.Publish([EventNames]::TabChanged, @{ TabIndex = 5 })
            }
        }.GetNewClosure())
        
        $this.AddCommand("eventbus monitor", "Open EventBus monitor", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: EventBus monitor command executed")
            }
            # Open EventBus monitor dialog
            $monitor = [EventBusMonitor]::new()
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($monitor)
            }
        }.GetNewClosure())
        
        $this.AddCommand("reload", "Reload configuration", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: Reload command executed")
            }
            # Publish reload event for services to handle
            if ($palette.EventBus) {
                $palette.EventBus.Publish('command.reload', $palette, @{})
            }
            # Reload configuration service
            $configService = $global:ServiceContainer.GetService('ConfigurationService')
            if ($configService) {
                $configService.LoadConfiguration()
            }
            $palette.Hide()
        }.GetNewClosure())
        
        $this.AddCommand("theme dark", "Switch to dark theme", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: Dark theme command executed")
            }
            if ($palette.Theme) {
                $palette.Theme.SetTheme('default')
            }
            $palette.Hide()
        }.GetNewClosure())
        
        $this.AddCommand("theme matrix", "Switch to matrix theme", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: Matrix theme command executed")
            }
            if ($palette.Theme) {
                $palette.Theme.SetTheme('matrix')
            }
            $palette.Hide()
        }.GetNewClosure())
        $this.AddCommand("quit", "Exit application (Ctrl+Q)", {
            if ($global:Logger) {
                $global:Logger.Debug("CommandPalette: Quit command executed")
            }
            if ($global:ScreenManager) {
                $screen = $global:ScreenManager.GetActiveScreen()
                if ($screen) { 
                    $screen.Active = $false 
                }
            }
        }.GetNewClosure())
    }
    
    [void] AddCommand([string]$name, [string]$description, [scriptblock]$action) {
        $this.AllCommands.Add(@{
            Name = $name
            Description = $description
            Action = $action
        })
    }
    
    [void] Show() {
        $this.IsVisible = $true
        $this.SearchText = ""
        $this.UpdateFilter()
        $this.Invalidate()
        
        # Focus on results
        $this.ResultsList.Focus()
    }
    
    [void] Hide() {
        $this.IsVisible = $false
        $this.Invalidate()
        
        # Return focus to parent's active tab
        if ($this.Parent -and $this.Parent.GetType().Name -eq "MainScreen") {
            $activeTab = $this.Parent.TabContainer.GetActiveTab()
            if ($activeTab -and $activeTab.Content) {
                $activeTab.Content.Focus()
            }
        }
    }
    
    [void] UpdateFilter() {
        $this.FilteredCommands.Clear()
        
        if ([string]::IsNullOrEmpty($this.SearchText)) {
            $this.FilteredCommands.AddRange($this.AllCommands)
        } else {
            # Simple fuzzy search
            $searchLower = $this.SearchText.ToLower()
            foreach ($cmd in $this.AllCommands) {
                if ($cmd.Name.ToLower().Contains($searchLower) -or 
                    $cmd.Description.ToLower().Contains($searchLower)) {
                    $this.FilteredCommands.Add($cmd)
                }
            }
        }
        
        # Update list
        $this.ResultsList.SetItems($this.FilteredCommands.ToArray())
    }
    
    [void] OnBoundsChanged() {
        # Center the palette
        $centerX = [int](($this.Width - $this.PaletteWidth) / 2)
        $centerY = [int](($this.Height - $this.PaletteHeight) / 2)
        
        # Update own bounds to be centered
        $this.X = $centerX
        $this.Y = $centerY
        $this.Width = $this.PaletteWidth
        $this.Height = $this.PaletteHeight
        
        # Layout results list (leave room for search box and border)
        $this.ResultsList.SetBounds(
            $this.X + 2,
            $this.Y + 4,
            $this.Width - 4,
            $this.Height - 6
        )
        
        # Recalculate visible items
        $this.ResultsList.VisibleItems = [Math]::Min($this.MaxResults, $this.Height - 6)
        
        ([Container]$this).OnBoundsChanged()
    }
    
    [string] OnRender() {
        if (-not $this.IsVisible) { return "" }
        
        $sb = Get-PooledStringBuilder 1024
        
        # Draw background first
        $sb.Append(([Container]$this).OnRender())
        
        # Draw border
        $borderColor = $this._colors['border.focused']
        
        # Top border with title
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append($borderColor)
        $sb.Append([VT]::TL() + [StringCache]::GetVTHorizontal(2))
        $accentColor = $this._colors['accent']
        $sb.Append($accentColor)
        $sb.Append(" Command Palette ")
        $sb.Append($borderColor)
        $sb.Append([StringCache]::GetVTHorizontal($this.Width - 19) + [VT]::TR())
        
        # Sides
        for ($y = 1; $y -lt $this.Height - 1; $y++) {
            $sb.Append([VT]::MoveTo($this.X, $this.Y + $y))
            $sb.Append([VT]::V())
            $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $this.Y + $y))
            $sb.Append([VT]::V())
        }
        
        # Bottom border
        $sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 1))
        $sb.Append([VT]::BL() + [StringCache]::GetVTHorizontal($this.Width - 2) + [VT]::BR())
        
        # Search box
        $sb.Append([VT]::MoveTo($this.X + 2, $this.Y + 2))
        $foregroundColor = $this._colors['foreground']
        $sb.Append($foregroundColor)
        $sb.Append("Search: ")
        $sb.Append($accentColor)
        $sb.Append($this.SearchText)
        $sb.Append("_")
        
        # Separator
        $sb.Append([VT]::MoveTo($this.X + 1, $this.Y + 3))
        $sb.Append($borderColor)
        $sb.Append([StringCache]::GetVTHorizontal($this.Width - 2))
        
        # Help text
        $sb.Append([VT]::MoveTo($this.X + 2, $this.Y + $this.Height - 2))
        $disabledColor = $this._colors['disabled']
        $sb.Append($disabledColor)
        $sb.Append("[Enter] Select  [Esc] Cancel")
        
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.IsVisible) { return $false }
        
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) {
                if ($global:Logger) {
                    $global:Logger.Debug("CommandPalette: Escape pressed, hiding palette")
                }
                try {
                    $this.Hide()
                } catch {
                    if ($global:Logger) {
                        $global:Logger.Error("CommandPalette: Error hiding palette: $_")
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                $selected = $this.ResultsList.GetSelectedItem()
                if ($selected) {
                    if ($global:Logger) {
                        $global:Logger.Debug("CommandPalette: Executing command '$($selected.Name)'")
                    }
                    $this.Hide()
                    if ($selected.Action) {
                        try {
                            # Execute in the context of the CommandPalette
                            $selected.Action.Invoke()
                        } catch {
                            if ($global:Logger) {
                                $global:Logger.Error("CommandPalette: Error executing command '$($selected.Name)': $_")
                            }
                        }
                    }
                    if ($this.OnCommandSelected) {
                        & $this.OnCommandSelected $selected
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::Backspace) {
                if ($this.SearchText.Length -gt 0) {
                    $this.SearchText = $this.SearchText.Substring(0, $this.SearchText.Length - 1)
                    $this.UpdateFilter()
                    $this.Invalidate()
                }
                return $true
            }
            default {
                # Let list handle navigation
                if ($this.ResultsList.HandleInput($key)) {
                    return $true
                }
                
                # Add character to search
                if ($key.KeyChar -and [char]::IsLetterOrDigit($key.KeyChar) -or $key.KeyChar -eq ' ') {
                    $this.SearchText += $key.KeyChar
                    $this.UpdateFilter()
                    $this.Invalidate()
                    return $true
                }
            }
        }
        
        return $false
    }
}