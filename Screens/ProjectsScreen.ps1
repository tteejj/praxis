# ProjectsScreen.ps1 - Project management screen using fast components

class ProjectsScreen : Screen {
    [ListBox]$ProjectList
    [Button]$NewButton
    [Button]$EditButton
    [Button]$DeleteButton
    [ProjectService]$ProjectService
    
    # Layout
    hidden [int]$ButtonHeight = 3
    hidden [int]$ButtonSpacing = 2
    
    ProjectsScreen() : base() {
        $this.Title = "Projects"
    }
    
    [void] OnInitialize() {
        # Get project service
        $this.ProjectService = $global:ServiceContainer.GetService("ProjectService")
        
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
        $buttonWidth = [int](($this.Width - ($this.ButtonSpacing * 2)) / 3)
        $buttonY = $this.Y + $listHeight + 1
        
        $this.NewButton.SetBounds(
            $this.X,
            $buttonY,
            $buttonWidth,
            $this.ButtonHeight
        )
        
        $this.EditButton.SetBounds(
            $this.X + $buttonWidth + $this.ButtonSpacing,
            $buttonY,
            $buttonWidth,
            $this.ButtonHeight
        )
        
        $this.DeleteButton.SetBounds(
            $this.X + ($buttonWidth + $this.ButtonSpacing) * 2,
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
    
    [void] NewProject() {
        # TODO: Show dialog to create new project
        # For now, create a test project
        $name = "Test Project " + (Get-Date -Format "HHmmss")
        $project = $this.ProjectService.AddProject($name, "TEST" + (Get-Random -Maximum 999))
        $this.LoadProjects()
        
        # Select the new project
        for ($i = 0; $i -lt $this.ProjectList.Items.Count; $i++) {
            if ($this.ProjectList.Items[$i].Id -eq $project.Id) {
                $this.ProjectList.SelectIndex($i)
                break
            }
        }
    }
    
    [void] EditProject() {
        $selected = $this.ProjectList.GetSelectedItem()
        if ($selected) {
            # TODO: Show edit dialog
            # For now, just show a message
            Write-Host "Edit project: $($selected.FullProjectName)" -ForegroundColor Yellow
        }
    }
    
    [void] DeleteProject() {
        $selected = $this.ProjectList.GetSelectedItem()
        if ($selected) {
            # TODO: Show confirmation dialog
            # For now, just mark as deleted
            $this.ProjectService.DeleteProject($selected.Id)
            $this.LoadProjects()
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