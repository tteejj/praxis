# ProjectsScreen.ps1 - Project management screen using DataGrid component

class ProjectsScreen : Screen {
    [DataGrid]$ProjectGrid
    [Button]$NewButton
    [Button]$ViewButton
    [Button]$EditButton
    [Button]$DeleteButton
    [ProjectService]$ProjectService
    [EventBus]$EventBus
    hidden [hashtable]$EventSubscriptions = @{}
    
    # Layout
    hidden [int]$ButtonHeight = 3
    hidden [int]$ButtonSpacing = 2
    
    ProjectsScreen() : base() {
        $this.Title = "Projects"
    }
    
    [void] OnInitialize() {
        # Get services
        $this.ProjectService = $global:ServiceContainer.GetService("ProjectService")
        $this.EventBus = $global:ServiceContainer.GetService('EventBus')
        
        # Subscribe to events
        if ($this.EventBus) {
            # Capture reference to this screen instance
            $screen = $this
            
            # Subscribe to project created events with explicit closure
            $this.EventSubscriptions['ProjectCreated'] = $this.EventBus.Subscribe('project.created', {
                param($sender, $eventData)
                $screen.RefreshProjects()
                # Select the new project if provided
                if ($eventData.Project) {
                    for ($i = 0; $i -lt $screen.ProjectGrid.Items.Count; $i++) {
                        if ($screen.ProjectGrid.Items[$i].Id -eq $eventData.Project.Id) {
                            $screen.ProjectGrid.SelectIndex($i)
                            break
                        }
                    }
                }
            }.GetNewClosure())
            
            # Subscribe to command events for this screen
            $this.EventSubscriptions['CommandExecuted'] = $this.EventBus.Subscribe('command.executed', {
                param($sender, $eventData)
                if ($eventData.Target -eq 'ProjectsScreen') {
                    switch ($eventData.Command) {
                        'EditProject' { $screen.EditProject() }
                        'DeleteProject' { $screen.DeleteProject() }
                    }
                }
            }.GetNewClosure())
            
            # Subscribe to project updated events
            $this.EventSubscriptions['ProjectUpdated'] = $this.EventBus.Subscribe('project.updated', {
                param($sender, $eventData)
                $screen.RefreshProjects()
            }.GetNewClosure())
            
            # Subscribe to project deleted events
            $this.EventSubscriptions['ProjectDeleted'] = $this.EventBus.Subscribe('project.deleted', {
                param($sender, $eventData)
                $screen.RefreshProjects()
            }.GetNewClosure())
        }
        
        # Create DataGrid with columns
        $this.ProjectGrid = [DataGrid]::new()
        $this.ProjectGrid.Title = "Projects"
        $this.ProjectGrid.ShowBorder = $true
        $this.ProjectGrid.ShowGridLines = $true
        
        # Define columns with proper formatting
        $columns = @(
            @{
                Name = "Status"
                Header = "Sts"
                Width = 3
                Getter = {
                    param($project)
                    if ($project.ClosedDate -ne [DateTime]::MinValue) { "[✓]" } else { "[ ]" }
                }
            },
            @{
                Name = "FullProjectName"
                Header = "Project Name"
                Width = 0  # Flexible width - will auto-size
            },
            @{
                Name = "ID1"
                Header = "ID1"
                Width = 5
            },
            @{
                Name = "ID2"
                Header = "ID2"
                Width = 9
            },
            @{
                Name = "DateAssigned"
                Header = "Assigned"
                Width = 10
                Formatter = {
                    param($value)
                    if ($value -is [DateTime] -and $value -ne [DateTime]::MinValue) {
                        $value.ToString("yyyy-MM-dd")
                    } else {
                        "          "
                    }
                }
            },
            @{
                Name = "DateDue"
                Header = "Due"
                Width = 10
                Formatter = {
                    param($value)
                    if ($value -is [DateTime] -and $value -ne [DateTime]::MinValue) {
                        $value.ToString("yyyy-MM-dd")
                    } else {
                        "          "
                    }
                }
            }
        )
        
        $this.ProjectGrid.SetColumns($columns)
        $this.ProjectGrid.Initialize($global:ServiceContainer)
        $this.AddChild($this.ProjectGrid)
        
        # Create buttons
        $screen = $this  # Capture reference for closures
        
        $this.NewButton = [Button]::new("New Project")
        $this.NewButton.IsDefault = $true
        $this.NewButton.OnClick = { 
            if ($global:Logger) {
                $global:Logger.Debug("New Project button clicked")
            }
            $screen.NewProject() 
        }.GetNewClosure()
        $this.NewButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.NewButton)
        
        $this.ViewButton = [Button]::new("View Details")
        $this.ViewButton.OnClick = { $screen.ViewProjectDetails() }.GetNewClosure()
        $this.ViewButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.ViewButton)
        
        $this.EditButton = [Button]::new("Edit")
        $this.EditButton.OnClick = { $screen.EditProject() }.GetNewClosure()
        $this.EditButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.EditButton)
        
        $this.DeleteButton = [Button]::new("Delete")
        $this.DeleteButton.OnClick = { $screen.DeleteProject() }.GetNewClosure()
        $this.DeleteButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.DeleteButton)
        
        # Load projects
        $this.LoadProjects()
        
        # Register screen-specific shortcuts with ShortcutManager
        $this.RegisterShortcuts()
    }
    
    [void] RegisterShortcuts() {
        $shortcutManager = $this.ServiceContainer.GetService('ShortcutManager')
        if (-not $shortcutManager) { 
            if ($global:Logger) {
                $global:Logger.Warning("ProjectsScreen: ShortcutManager not found in ServiceContainer")
            }
            return 
        }
        
        # Register screen-specific shortcuts
        $screen = $this
        
        $shortcutManager.RegisterShortcut(@{
            Id = "projects.new"
            Name = "New Project"
            Description = "Create a new project"
            KeyChar = 'n'
            Scope = [ShortcutScope]::Screen
            ScreenType = "ProjectsScreen"
            Priority = 50
            Action = { $screen.NewProject() }.GetNewClosure()
        })
        
        $shortcutManager.RegisterShortcut(@{
            Id = "projects.edit"
            Name = "Edit Project"
            Description = "Edit the selected project"
            KeyChar = 'e'
            Scope = [ShortcutScope]::Screen
            ScreenType = "ProjectsScreen"
            Priority = 50
            Action = { $screen.EditProject() }.GetNewClosure()
        })
        
        $shortcutManager.RegisterShortcut(@{
            Id = "projects.delete"
            Name = "Delete Project"
            Description = "Delete the selected project"
            KeyChar = 'd'
            Scope = [ShortcutScope]::Screen
            ScreenType = "ProjectsScreen"
            Priority = 50
            Action = { $screen.DeleteProject() }.GetNewClosure()
        })
        
        $shortcutManager.RegisterShortcut(@{
            Id = "projects.refresh"
            Name = "Refresh"
            Description = "Refresh the project list"
            Key = [System.ConsoleKey]::F5
            Scope = [ShortcutScope]::Screen
            ScreenType = "ProjectsScreen"
            Priority = 50
            Action = { $screen.LoadProjects() }.GetNewClosure()
        })
        
        if ($global:Logger) {
            $global:Logger.Debug("ProjectsScreen.RegisterShortcuts: Registered shortcuts for 'n', 'e', 'd', etc.")
        }
    }
    
    
    [void] OnActivated() {
        # Call base to manage focus scope and shortcuts
        ([Screen]$this).OnActivated()
        
        if ($global:Logger) {
            $global:Logger.Debug("ProjectsScreen.OnActivated: Screen activated with new focus system")
        }
        
        # Add defensive null checks
        try {
            # Focus the grid if it has items, otherwise the New button
            if ($global:Logger) {
                $projectGridNull = ($this.ProjectGrid -eq $null)
                $itemsCount = if ($this.ProjectGrid -and $this.ProjectGrid.Items) { $this.ProjectGrid.Items.Count } else { 0 }
                $newButtonNull = ($this.NewButton -eq $null)
                $global:Logger.Debug("ProjectsScreen focus check: ProjectGrid=$(!$projectGridNull), Items=$itemsCount, NewButton=$(!$newButtonNull)")
            }
            
            if ($this.ProjectGrid -and $this.ProjectGrid.Items -and $this.ProjectGrid.Items.Count -gt 0) {
                $this.ProjectGrid.Focus()
            } elseif ($this.NewButton) {
                $this.NewButton.Focus()
            } else {
                if ($global:Logger) {
                    $global:Logger.Debug("ProjectsScreen: No focusable element found!")
                }
            }
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("ProjectsScreen.OnActivated: Error during focus - $_")
                $global:Logger.Error("Stack trace: $($_.ScriptStackTrace)")
            }
        }
    }
    
    [void] OnBoundsChanged() {
        # Debug
        if ($global:Logger) {
            $global:Logger.Debug("ProjectsScreen.OnBoundsChanged: Bounds=($($this.X),$($this.Y),$($this.Width),$($this.Height))")
        }
        
        # Layout: Grid takes most space, buttons at bottom
        $buttonAreaHeight = $this.ButtonHeight + 2
        $gridHeight = $this.Height - $buttonAreaHeight
        
        # Project grid
        $this.ProjectGrid.SetBounds(
            $this.X, 
            $this.Y,
            $this.Width,
            $gridHeight
        )
        
        # Buttons (horizontally arranged) - now 4 buttons
        $maxButtonWidth = 20  # Reduced button width to fit 4 buttons
        $totalButtonWidth = ($maxButtonWidth * 4) + ($this.ButtonSpacing * 3)
        
        # Center buttons if screen is wide enough
        if ($this.Width -gt $totalButtonWidth) {
            $buttonStartX = $this.X + [int](($this.Width - $totalButtonWidth) / 2)
            $buttonWidth = $maxButtonWidth
        } else {
            $buttonStartX = $this.X
            $buttonWidth = [int](($this.Width - ($this.ButtonSpacing * 3)) / 4)
        }
        
        # Position buttons at bottom of screen bounds
        $buttonY = $this.Y + $this.Height - $this.ButtonHeight - 1
        
        $this.NewButton.SetBounds(
            $buttonStartX,
            $buttonY,
            $buttonWidth,
            $this.ButtonHeight
        )
        
        $this.ViewButton.SetBounds(
            $buttonStartX + $buttonWidth + $this.ButtonSpacing,
            $buttonY,
            $buttonWidth,
            $this.ButtonHeight
        )
        
        $this.EditButton.SetBounds(
            $buttonStartX + ($buttonWidth + $this.ButtonSpacing) * 2,
            $buttonY,
            $buttonWidth,
            $this.ButtonHeight
        )
        
        $this.DeleteButton.SetBounds(
            $buttonStartX + ($buttonWidth + $this.ButtonSpacing) * 3,
            $buttonY,
            $buttonWidth,
            $this.ButtonHeight
        )
    }
    
    [void] LoadProjects() {
        $projects = $this.ProjectService.GetAllProjects()
        
        # Filter out deleted projects
        $activeProjects = $projects | Where-Object { -not $_.Deleted }
        
        # Sort by due date
        $sorted = $activeProjects | Sort-Object DateDue
        
        $this.ProjectGrid.SetItems($sorted)
    }
    
    [void] RefreshProjects() {
        # Reload projects and update display
        $this.LoadProjects()
        $this.Invalidate()
    }
    
    [void] NewProject() {
        if ($global:Logger) {
            $global:Logger.Debug("ProjectsScreen.NewProject() called")
        }
        # Create new project dialog
        $dialog = [NewProjectDialog]::new()
        
        # EventBus will handle project creation and dialog closing
        # Legacy callbacks are only set as fallback for non-EventBus scenarios
        if (-not $this.EventBus) {
            # Capture the screen reference
            $screen = $this
            $dialog.OnCreate = {
                param($projectData)
                
                # Create nickname from name
                # Create project using single-parameter constructor
                $project = $screen.ProjectService.AddProject($projectData.Name)
                $screen.LoadProjects()
                
                # Select the new project
                for ($i = 0; $i -lt $screen.ProjectGrid.Items.Count; $i++) {
                    if ($screen.ProjectGrid.Items[$i].Id -eq $project.Id) {
                        $screen.ProjectGrid.SelectIndex($i)
                        break
                    }
                }
                
                # Don't call Pop() - BaseDialog handles that
            }.GetNewClosure()
            
            # Don't need OnCancel - BaseDialog handles ESC by default
        }
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] EditProject() {
        $selected = $this.ProjectGrid.GetSelectedItem()
        if (-not $selected) { return }
        
        # Create edit project dialog
        $dialog = [EditProjectDialog]::new($selected)
        # Capture references
        $screen = $this
        $project = $selected
        $dialog.OnPrimary = {
            # Get the data from the dialog
            $projectData = @{
                FullProjectName = $dialog.NameBox.Text
                Nickname = $dialog.NicknameBox.Text
                Note = $dialog.NoteBox.Text
                DateDue = $dialog.DueDateBox.Text
            }
            
            # Update the project
            $project.FullProjectName = $projectData.FullProjectName
            $project.Nickname = $projectData.Nickname
            $project.Note = $projectData.Note
            $project.DateDue = $projectData.DateDue
            
            # Save through service
            $screen.ProjectService.UpdateProject($project)
            
            # Publish project updated event
            if ($screen.EventBus) {
                $screen.EventBus.Publish([EventNames]::ProjectUpdated, @{ Project = $project })
            } else {
                # Fallback if EventBus not available
                $screen.LoadProjects()
            }
            
            # Don't call Pop() - BaseDialog handles that
        }.GetNewClosure()
        
        # Don't need OnCancel - BaseDialog handles ESC by default
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] DeleteProject() {
        $selected = $this.ProjectGrid.GetSelectedItem()
        if ($selected) {
            # Show confirmation dialog
            $message = "Are you sure you want to delete project '$($selected.FullProjectName)'?"
            $dialog = [ConfirmationDialog]::new($message)
            
            $screen = $this
            $projectId = $selected.Id
            $dialog.OnConfirm = {
                # Delete the project
                $screen.ProjectService.DeleteProject($projectId)
                
                # Publish project deleted event
                if ($screen.EventBus) {
                    $screen.EventBus.Publish([EventNames]::ProjectDeleted, @{ ProjectId = $projectId })
                } else {
                    # Fallback if EventBus not available
                    $screen.LoadProjects()
                }
                
                # Don't call Pop() - BaseDialog handles that
            }.GetNewClosure()
            
            # Don't need OnCancel - BaseDialog handles ESC by default
            
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
            }
        }
    }
    
    [void] ViewProjectDetails() {
        if ($global:Logger) {
            $global:Logger.Debug("ProjectsScreen.ViewProjectDetails() called")
        }
        $selected = $this.ProjectGrid.GetSelectedItem()
        if ($selected) {
            # Create and show project detail screen
            $detailScreen = [ProjectDetailScreen]::new($selected)
            
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($detailScreen)
            }
        }
    }
    
    # Using parent-delegated focus model - Tab handled by ScreenManager/Container
    
    # Override HandleScreenInput instead of HandleInput to work with base Screen class
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        if ($global:Logger) {
            $global:Logger.Debug("ProjectsScreen.HandleScreenInput: Key=$($key.Key) Char='$($key.KeyChar)'")
        }
        
        # Screen-specific shortcuts - only called as fallback by base Screen class
        switch ($key.Key) {
            ([System.ConsoleKey]::N) {
                if (-not $key.Modifiers) {
                    if ($global:Logger) {
                        $global:Logger.Debug("ProjectsScreen: 'N' key pressed, calling NewProject")
                    }
                    $this.NewProject()
                    return $true
                }
            }
            ([System.ConsoleKey]::E) {
                if (-not $key.Modifiers) {
                    if ($global:Logger) {
                        $global:Logger.Debug("ProjectsScreen: 'E' key pressed, calling EditProject")
                    }
                    $this.EditProject()
                    return $true
                }
            }
            ([System.ConsoleKey]::Enter) {
                $this.ViewProjectDetails()
                return $true
            }
            ([System.ConsoleKey]::V) {
                if (-not $key.Modifiers -and ($key.KeyChar -eq 'V' -or $key.KeyChar -eq 'v')) {
                    $this.ViewProjectDetails()
                    return $true
                }
            }
            ([System.ConsoleKey]::D) {
                if (-not $key.Modifiers -and ($key.KeyChar -eq 'D' -or $key.KeyChar -eq 'd')) {
                    $this.DeleteProject()
                    return $true
                }
            }
            ([System.ConsoleKey]::R) {
                if (-not $key.Modifiers -and ($key.KeyChar -eq 'R' -or $key.KeyChar -eq 'r')) {
                    $this.LoadProjects()
                    return $true
                }
            }
            ([System.ConsoleKey]::Q) {
                if (-not $key.Modifiers -and ($key.KeyChar -eq 'Q' -or $key.KeyChar -eq 'q')) {
                    $this.Active = $false
                    return $true
                }
            }
        }
        
        # If no shortcut matched, return false (let base Screen handle it)
        return $false
    }
}