# ProjectsScreenFixed.ps1 - Fixed version of ProjectsScreen using PraxisDev tools
# This should actually work with proper positioning and dialogs

. "$PSScriptRoot/../PraxisDev.ps1"

class ProjectsScreenFixed : Screen {
    [MinimalDataGrid]$ProjectGrid
    [ProjectService]$ProjectService
    [EventBus]$EventBus
    [ProjectCommandHandler]$CommandHandler
    hidden [hashtable]$EventSubscriptions = @{}
    
    ProjectsScreenFixed() : base() {
        $this.Title = "Projects"
    }
    
    [void] OnInitialize() {
        # Get services
        $this.ProjectService = $global:ServiceContainer.GetService("ProjectService")
        $this.EventBus = $global:ServiceContainer.GetService('EventBus')
        $this.CommandHandler = [ProjectCommandHandler]::new($global:ServiceContainer)
        
        # Subscribe to events
        if ($this.EventBus) {
            $screen = $this
            
            $this.EventSubscriptions['ProjectCreated'] = $this.EventBus.Subscribe('project.created', {
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
            
            $this.EventSubscriptions['CommandExecuted'] = $this.EventBus.Subscribe('command.executed', {
                param($sender, $eventData)
                if ($eventData.Target -eq 'ProjectsScreen') {
                    switch ($eventData.Command) {
                        'EditProject' { $screen.EditProject() }
                        'DeleteProject' { $screen.DeleteProject() }
                    }
                }
            }.GetNewClosure())
            
            $this.EventSubscriptions['ProjectUpdated'] = $this.EventBus.Subscribe('project.updated', {
                param($sender, $eventData)
                $screen.RefreshProjects()
            }.GetNewClosure())
            
            $this.EventSubscriptions['ProjectDeleted'] = $this.EventBus.Subscribe('project.deleted', {
                param($sender, $eventData)
                $screen.RefreshProjects()
            }.GetNewClosure())
        }
        
        # Create DataGrid with FIXED positioning
        $this.ProjectGrid = [MinimalDataGrid]::new()
        $this.ProjectGrid.Title = ""
        $this.ProjectGrid.ShowBorder = $true
        $this.ProjectGrid.BorderType = [BorderType]::Rounded
        $this.ProjectGrid.ShowTitle = $false
        $this.ProjectGrid.ShowGridLines = $false
        
        # CRITICAL: Set bounds with proper positioning
        # Leave room for screen title (2 lines) and status bar (1 line)
        $gridX = 2
        $gridY = 3
        $gridWidth = [Console]::WindowWidth - 4
        $gridHeight = [Console]::WindowHeight - 6
        
        $this.ProjectGrid.SetBounds($gridX, $gridY, $gridWidth, $gridHeight)
        
        # Define columns
        $columns = @(
            @{
                Name = "Status"
                Header = "Status"
                Width = 6
                Getter = {
                    param($project)
                    if ($project.ClosedDate -ne [DateTime]::MinValue) { "[✓]" } else { "[ ]" }
                }
            },
            @{
                Name = "FullProjectName"
                Header = "Project Name"
                Width = 0  # Flexible
            },
            @{
                Name = "ID1"
                Header = "ID1"
                Width = 8
            },
            @{
                Name = "ID2"
                Header = "ID2"
                Width = 8
            },
            @{
                Name = "TaskSummary"
                Header = "Tasks"
                Width = 12
                Getter = {
                    param($project)
                    $taskService = $global:ServiceContainer.GetService("TaskService")
                    if ($taskService) {
                        $tasks = $taskService.GetTasksByProjectId($project.Id)
                        $open = ($tasks | Where-Object { -not $_.IsCompleted }).Count
                        $total = $tasks.Count
                        return "$open/$total"
                    }
                    return "0/0"
                }
            }
        )
        
        foreach ($col in $columns) {
            $this.ProjectGrid.AddColumn($col)
        }
        
        $this.AddChild($this.ProjectGrid)
        
        # Fix any positioning issues
        Fix-ChildPositioning $this
        Fix-BorderRendering $this.ProjectGrid
        
        # Load projects
        $this.RefreshProjects()
        
        # Add status bar with keyboard shortcuts
        $this.AddStatusBar()
    }
    
    [void] RefreshProjects() {
        if ($this.ProjectService) {
            $projects = $this.ProjectService.GetAllProjects()
            $this.ProjectGrid.SetItems($projects)
        }
    }
    
    [void] AddStatusBar() {
        # Create status bar at bottom
        $statusBar = [UIElement]::new()
        $statusBar.SetBounds(0, [Console]::WindowHeight - 1, [Console]::WindowWidth, 1)
        
        $statusBar | Add-Member -MemberType ScriptMethod -Name OnRender -Value {
            $theme = $this.ServiceContainer.GetService('ThemeManager')
            $colors = $theme.GetColor("StatusBar")
            $text = " [N]ew Project | [E]dit | [D]elete | [Enter] Select | [Q]uit "
            $clearLine = [StringCache]::GetSpaces([Console]::WindowWidth)
            
            return [VT]::MoveTo(0, [Console]::WindowHeight - 1) + 
                   $colors.ToEscapeSequence() + $clearLine +
                   [VT]::MoveTo(1, [Console]::WindowHeight - 1) + $text + [VT]::Reset
        } -Force
        
        $this.AddChild($statusBar)
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Handle screen-level shortcuts
        switch ($key.Key) {
            ([System.ConsoleKey]::N) {
                $this.NewProject()
                return $true
            }
            ([System.ConsoleKey]::E) {
                $this.EditProject()
                return $true
            }
            ([System.ConsoleKey]::D) {
                $this.DeleteProject()
                return $true
            }
            ([System.ConsoleKey]::Q) {
                # Exit screen
                $screenManager = $global:ServiceContainer.GetService('ScreenManager')
                if ($screenManager) {
                    $screenManager.PopScreen()
                }
                return $true
            }
        }
        
        # Let grid handle other input
        return ([Screen]$this).HandleInput($key)
    }
    
    [void] NewProject() {
        # Use the fixed dialog creation
        $dialog = New-ProjectDialogFixed -ProjectService $this.ProjectService
        
        # Show dialog
        $screenManager = $global:ServiceContainer.GetService('ScreenManager')
        if ($screenManager) {
            $screenManager.ShowModal($dialog)
        }
    }
    
    [void] EditProject() {
        $selected = $this.ProjectGrid.GetSelectedItem()
        if ($selected) {
            # Would create edit dialog here
            Write-Host "Edit project: $($selected.FullProjectName)"
        }
    }
    
    [void] DeleteProject() {
        $selected = $this.ProjectGrid.GetSelectedItem()
        if ($selected) {
            # Confirmation dialog
            $result = Show-EasyDialog -Title "Delete Project" `
                -Message "Delete project '$($selected.FullProjectName)'?" `
                -Buttons @("Delete", "Cancel") `
                -DefaultButton "Cancel"
            
            if ($result -eq "Delete") {
                $this.ProjectService.DeleteProject($selected.Id)
                $this.RefreshProjects()
            }
        }
    }
    
    [void] OnClose() {
        # Unsubscribe from events
        if ($this.EventBus) {
            foreach ($subId in $this.EventSubscriptions.Values) {
                $this.EventBus.Unsubscribe($subId)
            }
        }
        ([Screen]$this).OnClose()
    }
}

# Helper function to create the fixed new project dialog
function New-ProjectDialogFixed {
    param([ProjectService]$ProjectService)
    
    $dialog = New-SimpleDialog -Title "New Project" -Message "" -Fields @(
        @{Name="ProjectName"; Label="Project Name:"; DefaultValue=""}
        @{Name="ID1"; Label="ID1:"; DefaultValue=""}
        @{Name="ID2"; Label="ID2:"; DefaultValue=""}
        @{Name="Notes"; Label="Notes:"; DefaultValue=""}
        @{Name="DueDate"; Label="Due Date (MM/DD/YYYY):"; DefaultValue=([DateTime]::Now.AddDays(42).ToString("MM/dd/yyyy"))}
    ) -Buttons @("Create", "Cancel")
    
    # Override the result handler to create the project
    $createButton = $dialog.Children | Where-Object { $_ -is [MinimalButton] -and $_.Text -eq "Create" } | Select-Object -First 1
    if ($createButton) {
        $createButton | Add-Member -MemberType ScriptMethod -Name HandleInput -Value {
            param([System.ConsoleKeyInfo]$key)
            if ($key.Key -eq [System.ConsoleKey]::Enter -or $key.Key -eq [System.ConsoleKey]::Spacebar) {
                # Get field values
                $root = $this.GetRoot()
                $fields = @{}
                $textboxes = $root.Children | Where-Object { $_ -is [MinimalTextBox] }
                
                foreach ($tb in $textboxes) {
                    switch ($tb.Label) {
                        "Project Name:" { $fields['ProjectName'] = $tb.Text }
                        "ID1:" { $fields['ID1'] = $tb.Text }
                        "ID2:" { $fields['ID2'] = $tb.Text }
                        "Notes:" { $fields['Notes'] = $tb.Text }
                        "Due Date (MM/DD/YYYY):" { $fields['DueDate'] = $tb.Text }
                    }
                }
                
                # Validate required field
                if ([string]::IsNullOrWhiteSpace($fields['ProjectName'])) {
                    # Could show error message
                    return $true
                }
                
                # Create project
                if ($ProjectService) {
                    $newProject = $ProjectService.AddProject($fields['ProjectName'])
                    
                    # Update additional fields
                    $newProject.ID1 = $fields['ID1']
                    $newProject.ID2 = $fields['ID2']
                    $newProject.Note = $fields['Notes']
                    
                    # Parse due date
                    if ($fields['DueDate']) {
                        try {
                            $newProject.DateDue = [DateTime]::Parse($fields['DueDate'])
                        } catch {
                            $newProject.DateDue = [DateTime]::Now.AddDays(42)
                        }
                    }
                    
                    $ProjectService.UpdateProject($newProject)
                }
                
                $root.DialogResult = "Created"
                $root.ShouldClose = $true
                return $true
            }
            return $false
        }.GetNewClosure() -Force
    }
    
    return $dialog
}