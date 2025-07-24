# ProjectsScreenEnhanced.ps1 - Project management screen with DataGrid

class ProjectsScreenEnhanced : Screen {
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
    
    ProjectsScreenEnhanced() : base() {
        $this.Title = "Projects"
    }
    
    [void] OnInitialize() {
        # Get services
        $this.ProjectService = $global:ServiceContainer.GetService("ProjectService")
        $this.EventBus = $global:ServiceContainer.GetService('EventBus')
        
        # Subscribe to events
        if ($this.EventBus) {
            $screen = $this
            
            # Subscribe to project created events
            $this.EventSubscriptions['ProjectCreated'] = $this.EventBus.Subscribe([EventNames]::ProjectCreated, {
                param($sender, $eventData)
                $screen.RefreshProjects()
                if ($eventData.Project) {
                    for ($i = 0; $i -lt $screen.ProjectGrid.Items.Count; $i++) {
                        if ($screen.ProjectGrid.Items[$i].Id -eq $eventData.Project.Id) {
                            $screen.ProjectGrid.SelectIndex($i)
                            break
                        }
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
        
        # Create project data grid
        $this.ProjectGrid = [DataGrid]::new()
        $this.ProjectGrid.Title = "Project List"
        $this.ProjectGrid.ShowBorder = $true
        $this.ProjectGrid.ShowHeader = $true
        $this.ProjectGrid.IsFocusable = $true
        
        # Define columns
        $columns = @(
            @{ 
                Name = "Status"
                Header = "Status"
                Width = 8
                Getter = { 
                    param($project) 
                    if ($project.ClosedDate -ne [DateTime]::MinValue) { "[Done]" } 
                    else { "[Open]" }
                }
            }
            @{ 
                Name = "Name"
                Header = "Project Name"
                Width = 25
                Getter = { param($project) $project.Nickname }
            }
            @{ 
                Name = "ID1"
                Header = "ID1"
                Width = 10
                Getter = { 
                    param($project) 
                    if ($project.ID1) { $project.ID1 } else { "-" }
                }
            }
            @{ 
                Name = "ID2"
                Header = "ID2"
                Width = 15
                Getter = { 
                    param($project) 
                    if ($project.ID2) { $project.ID2 } else { "-" }
                }
            }
            @{ 
                Name = "Client"
                Header = "Client"
                Width = 20
                Getter = { 
                    param($project) 
                    if ($project.Name) { $project.Name } else { "-" }
                }
            }
            @{ 
                Name = "Assigned"
                Header = "Assigned"
                Width = 10
                Getter = { 
                    param($project) 
                    $project.DateAssigned.ToString("MM/dd/yy")
                }
            }
        )
        
        $this.ProjectGrid.SetColumns($columns)
        $this.ProjectGrid.Initialize($global:ServiceContainer)
        $this.AddChild($this.ProjectGrid)
        
        # Create buttons
        $screen = $this
        
        $this.NewButton = [Button]::new("New Project")
        $this.NewButton.IsDefault = $true
        $this.NewButton.OnClick = { $screen.NewProject() }.GetNewClosure()
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
    }
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        
        # Focus the grid if it has items, otherwise the New button
        if ($this.ProjectGrid -and $this.ProjectGrid.Items.Count -gt 0) {
            $this.ProjectGrid.Focus()
        } elseif ($this.NewButton) {
            $this.NewButton.Focus()
        }
    }
    
    [void] OnDeactivated() {
        ([Screen]$this).OnDeactivated()
    }
    
    [void] OnBoundsChanged() {
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
        
        # Buttons (horizontally arranged)
        $maxButtonWidth = 20
        $totalButtonWidth = ($maxButtonWidth * 4) + ($this.ButtonSpacing * 3)
        
        if ($this.Width -gt $totalButtonWidth) {
            $buttonStartX = $this.X + [int](($this.Width - $totalButtonWidth) / 2)
            $buttonWidth = $maxButtonWidth
        } else {
            $buttonStartX = $this.X
            $buttonWidth = [int](($this.Width - ($this.ButtonSpacing * 3)) / 4)
        }
        
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
        
        # Sort by due date (most urgent first), then by assigned date
        $sorted = $activeProjects | Sort-Object -Property @(
            @{Expression = { $_.ClosedDate -eq [DateTime]::MinValue }; Descending = $true}
            @{Expression = { ($_.DateDue - [DateTime]::Now).Days }}
            @{Expression = { $_.DateAssigned }}
        )
        
        $this.ProjectGrid.SetItems($sorted)
    }
    
    [void] RefreshProjects() {
        $this.LoadProjects()
        $this.Invalidate()
    }
    
    [void] NewProject() {
        $dialog = [NewProjectDialog]::new()
        
        if (-not $this.EventBus) {
            $screen = $this
            $dialog.OnCreate = {
                param($projectData)
                $project = $screen.ProjectService.AddProject($projectData.Name)
                $screen.LoadProjects()
                
                for ($i = 0; $i -lt $screen.ProjectGrid.Items.Count; $i++) {
                    if ($screen.ProjectGrid.Items[$i].Id -eq $project.Id) {
                        $screen.ProjectGrid.SelectIndex($i)
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
        $selected = $this.ProjectGrid.GetSelectedItem()
        if (-not $selected) { return }
        
        $dialog = [EditProjectDialog]::new($selected)
        $screen = $this
        $project = $selected
        
        $dialog.OnSave = {
            param($projectData)
            
            $project.FullProjectName = $projectData.FullProjectName
            $project.Nickname = $projectData.Nickname
            $project.Note = $projectData.Note
            $project.DateDue = $projectData.DateDue
            
            $screen.ProjectService.UpdateProject($project)
            
            if ($screen.EventBus) {
                $screen.EventBus.Publish([EventNames]::ProjectUpdated, @{ Project = $project })
            } else {
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
        $selected = $this.ProjectGrid.GetSelectedItem()
        if ($selected) {
            $message = "Are you sure you want to delete project '$($selected.Nickname)'?"
            $dialog = [ConfirmationDialog]::new($message)
            
            $screen = $this
            $projectId = $selected.Id
            
            $dialog.OnConfirm = {
                $screen.ProjectService.DeleteProject($projectId)
                
                if ($screen.EventBus) {
                    $screen.EventBus.Publish([EventNames]::ProjectDeleted, @{ ProjectId = $projectId })
                } else {
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
        $selected = $this.ProjectGrid.GetSelectedItem()
        if ($selected) {
            $detailScreen = [ProjectDetailScreen]::new($selected)
            
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($detailScreen)
            }
        }
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Enter) {
                $this.ViewProjectDetails()
                return $true
            }
            ([System.ConsoleKey]::N) {
                if (-not $key.Modifiers) {
                    $this.NewProject()
                    return $true
                }
            }
            ([System.ConsoleKey]::E) {
                if (-not $key.Modifiers) {
                    $this.EditProject()
                    return $true
                }
            }
            ([System.ConsoleKey]::D) {
                if (-not $key.Modifiers) {
                    $this.DeleteProject()
                    return $true
                }
            }
            ([System.ConsoleKey]::V) {
                if (-not $key.Modifiers) {
                    $this.ViewProjectDetails()
                    return $true
                }
            }
        }
        
        return $false
    }
}