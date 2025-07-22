# ProjectsScreen.ps1 - Project management screen using fast components

class ProjectsScreen : Screen {
    [ListBox]$ProjectList
    [Button]$NewButton
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
            # Subscribe to project created events
            $this.EventSubscriptions['ProjectCreated'] = $this.EventBus.Subscribe([EventNames]::ProjectCreated, {
                param($sender, $eventData)
                $this.RefreshProjects()
                # Select the new project if provided
                if ($eventData.Project) {
                    for ($i = 0; $i -lt $this.ProjectList.Items.Count; $i++) {
                        if ($this.ProjectList.Items[$i].Id -eq $eventData.Project.Id) {
                            $this.ProjectList.SelectIndex($i)
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
                        'EditProject' { $this.EditProject() }
                        'DeleteProject' { $this.DeleteProject() }
                    }
                }
            }.GetNewClosure())
            
            # Subscribe to project updated events
            $this.EventSubscriptions['ProjectUpdated'] = $this.EventBus.Subscribe([EventNames]::ProjectUpdated, {
                param($sender, $eventData)
                $this.RefreshProjects()
            }.GetNewClosure())
            
            # Subscribe to project deleted events
            $this.EventSubscriptions['ProjectDeleted'] = $this.EventBus.Subscribe([EventNames]::ProjectDeleted, {
                param($sender, $eventData)
                $this.RefreshProjects()
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
        
        # Key bindings
        $this.BindKey('n', { $this.NewProject() })
        $this.BindKey('e', { $this.EditProject() })
        $this.BindKey('d', { $this.DeleteProject() })
        $this.BindKey('r', { $this.LoadProjects() })
        $this.BindKey([System.ConsoleKey]::Enter, { $this.EditProject() })
        $this.BindKey([System.ConsoleKey]::Tab, { $this.FocusNext() })
        $this.BindKey('q', { $this.Active = $false })
        
        # Focus on list
        $this.ProjectList.Focus()
    }
    
    [void] OnActivated() {
        # Call base to trigger render
        ([Screen]$this).OnActivated()
        
        # Make sure list has focus when screen is activated
        if ($this.ProjectList) {
            $this.ProjectList.Focus()
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
        
        # Buttons (horizontally arranged)
        $maxButtonWidth = 25  # Maximum button width
        $totalButtonWidth = ($maxButtonWidth * 3) + ($this.ButtonSpacing * 2)
        
        # Center buttons if screen is wide enough
        if ($this.Width -gt $totalButtonWidth) {
            $buttonStartX = $this.X + [int](($this.Width - $totalButtonWidth) / 2)
            $buttonWidth = $maxButtonWidth
        } else {
            $buttonStartX = $this.X
            $buttonWidth = [int](($this.Width - ($this.ButtonSpacing * 2)) / 3)
        }
        
        # Position buttons at bottom of screen bounds
        $buttonY = $this.Y + $this.Height - $this.ButtonHeight - 1
        
        $this.NewButton.SetBounds(
            $buttonStartX,
            $buttonY,
            $buttonWidth,
            $this.ButtonHeight
        )
        
        $this.EditButton.SetBounds(
            $buttonStartX + $buttonWidth + $this.ButtonSpacing,
            $buttonY,
            $buttonWidth,
            $this.ButtonHeight
        )
        
        $this.DeleteButton.SetBounds(
            $buttonStartX + ($buttonWidth + $this.ButtonSpacing) * 2,
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
                $nickname = $projectData.Name -replace '\s+', ''
                if ($nickname.Length -gt 10) {
                    $nickname = $nickname.Substring(0, 10)
                }
                
                $project = $screen.ProjectService.AddProject($projectData.Name, $nickname)
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
            $dialog = [ConfirmationDialog]::new(
                "Delete Project",
                "Are you sure you want to delete project '$($selected.Nickname)'?"
            )
            
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
    
    [void] FocusNext() {
        $focused = $this.FindFocused()
        
        if ($focused -eq $this.ProjectList) {
            $this.NewButton.Focus()
        } elseif ($focused -eq $this.NewButton) {
            $this.EditButton.Focus()
        } elseif ($focused -eq $this.EditButton) {
            $this.DeleteButton.Focus()
        } else {
            $this.ProjectList.Focus()
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Let base class handle registered keys first
        if (([Screen]$this).HandleInput($key)) {
            return $true
        }
        
        # Pass unhandled input to focused child
        return ([Container]$this).HandleInput($key)
    }
}