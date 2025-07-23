# ProjectsScreen.ps1 - Project management screen using fast components

class ProjectsScreen : Screen {
    [ListBox]$ProjectList
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
            $this.EventSubscriptions['ProjectCreated'] = $this.EventBus.Subscribe([EventNames]::ProjectCreated, {
                param($sender, $eventData)
                $screen.RefreshProjects()
                # Select the new project if provided
                if ($eventData.Project) {
                    for ($i = 0; $i -lt $screen.ProjectList.Items.Count; $i++) {
                        if ($screen.ProjectList.Items[$i].Id -eq $eventData.Project.Id) {
                            $screen.ProjectList.SelectIndex($i)
                            break
                        }
                    }
                }
            }.GetNewClosure())
            
            # Subscribe to command events for this screen
            $this.EventSubscriptions['CommandExecuted'] = $this.EventBus.Subscribe([EventNames]::CommandExecuted, {
                param($sender, $eventData)
                if ($eventData.Target -eq 'ProjectsScreen') {
                    switch ($eventData.Command) {
                        'EditProject' { $screen.EditProject() }
                        'DeleteProject' { $screen.DeleteProject() }
                    }
                }
            }.GetNewClosure())
            
            # Subscribe to project updated events
            $this.EventSubscriptions['ProjectUpdated'] = $this.EventBus.Subscribe([EventNames]::ProjectUpdated, {
                param($sender, $eventData)
                $screen.RefreshProjects()
            }.GetNewClosure())
            
            # Subscribe to project deleted events
            $this.EventSubscriptions['ProjectDeleted'] = $this.EventBus.Subscribe([EventNames]::ProjectDeleted, {
                param($sender, $eventData)
                $screen.RefreshProjects()
            }.GetNewClosure())
        }
        
        # Create components
        $this.ProjectList = [ListBox]::new()
        $this.ProjectList.Title = "Projects"
        $this.ProjectList.ShowBorder = $true
        $this.ProjectList.ItemRenderer = {
            param($project)
            $status = if ($project.ClosedDate -ne [DateTime]::MinValue) { "[✓]" } else { "[ ]" }
            $daysLeft = ($project.DateDue - [DateTime]::Now).Days
            $dueStatus = if ($daysLeft -lt 0) { "OVERDUE" } elseif ($daysLeft -lt 7) { "DUE SOON" } else { "$daysLeft days" }
            return "$status $($project.Nickname) - $dueStatus"
        }
        $this.ProjectList.Initialize($global:ServiceContainer)
        $this.AddChild($this.ProjectList)
        
        # Create buttons
        $this.NewButton = [Button]::new("New Project")
        $this.NewButton.IsDefault = $true
        $this.NewButton.OnClick = { $this.NewProject() }
        $this.NewButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.NewButton)
        
        $this.ViewButton = [Button]::new("View Details")
        $this.ViewButton.OnClick = { $this.ViewProjectDetails() }
        $this.ViewButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.ViewButton)
        
        $this.EditButton = [Button]::new("Edit")
        $this.EditButton.OnClick = { $this.EditProject() }
        $this.EditButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.EditButton)
        
        $this.DeleteButton = [Button]::new("Delete")
        $this.DeleteButton.OnClick = { $this.DeleteProject() }
        $this.DeleteButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.DeleteButton)
        
        # Load projects
        $this.LoadProjects()
        
        # Key bindings now handled by GetShortcutBindings() method
        # Initial focus will be handled by FocusManager when screen is activated
    }
    
    
    [void] OnActivated() {
        # Call base to manage focus scope and shortcuts
        ([Screen]$this).OnActivated()
        
        if ($global:Logger) {
            $global:Logger.Debug("ProjectsScreen.OnActivated: Screen activated with new focus system")
        }
    }
    
    [void] OnBoundsChanged() {
        # Debug
        if ($global:Logger) {
            $global:Logger.Debug("ProjectsScreen.OnBoundsChanged: Bounds=($($this.X),$($this.Y),$($this.Width),$($this.Height))")
        }
        
        # Layout: List takes most space, buttons at bottom
        $buttonAreaHeight = $this.ButtonHeight + 2
        $listHeight = $this.Height - $buttonAreaHeight
        
        # Project list
        $this.ProjectList.SetBounds(
            $this.X, 
            $this.Y,
            $this.Width,
            $listHeight
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
        
        $this.ProjectList.SetItems($sorted)
    }
    
    [void] RefreshProjects() {
        # Reload projects and update display
        $this.LoadProjects()
        $this.Invalidate()
    }
    
    [void] NewProject() {
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
                for ($i = 0; $i -lt $screen.ProjectList.Items.Count; $i++) {
                    if ($screen.ProjectList.Items[$i].Id -eq $project.Id) {
                        $screen.ProjectList.SelectIndex($i)
                        break
                    }
                }
                
                if ($global:ScreenManager) {
                    $global:ScreenManager.Pop()
                }
            }.GetNewClosure()
            
            $dialog.OnCancel = {
                if ($global:ScreenManager) {
                    $global:ScreenManager.Pop()
                }
            }
        }
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] EditProject() {
        $selected = $this.ProjectList.GetSelectedItem()
        if (-not $selected) { return }
        
        # Create edit project dialog
        $dialog = [EditProjectDialog]::new($selected)
        # Capture references
        $screen = $this
        $project = $selected
        $dialog.OnSave = {
            param($projectData)
            
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
            
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }.GetNewClosure()
        
        $dialog.OnCancel = {
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] DeleteProject() {
        $selected = $this.ProjectList.GetSelectedItem()
        if ($selected) {
            # Show confirmation dialog
            $message = "Are you sure you want to delete project '$($selected.Nickname)'?"
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
                
                if ($global:ScreenManager) {
                    $global:ScreenManager.Pop()
                }
            }.GetNewClosure()
            
            $dialog.OnCancel = {
                if ($global:ScreenManager) {
                    $global:ScreenManager.Pop()
                }
            }
            
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
            }
        }
    }
    
    [void] ViewProjectDetails() {
        $selected = $this.ProjectList.GetSelectedItem()
        if ($selected) {
            # Create and show project detail screen
            $detailScreen = [ProjectDetailScreen]::new($selected)
            
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($detailScreen)
            }
        }
    }
    
    # FocusNext method removed - Tab navigation now handled by FocusManager service
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Handle screen-specific shortcuts FIRST (before passing to children)
        switch ($key.Key) {
            ([System.ConsoleKey]::N) {
                if (-not $key.Modifiers -and ($key.KeyChar -eq 'N' -or $key.KeyChar -eq 'n')) {
                    $this.NewProject()
                    return $true
                }
            }
            ([System.ConsoleKey]::E) {
                if (-not $key.Modifiers -and ($key.KeyChar -eq 'E' -or $key.KeyChar -eq 'e')) {
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
        
        # Let base Screen class handle other keys (like Tab navigation)
        if (([Screen]$this).HandleInput($key)) {
            return $true
        }
        
        # Finally, pass unhandled input to focused child
        return ([Container]$this).HandleInput($key)
    }
}