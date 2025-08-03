# ProjectsScreen.ps1 - Project management screen using CRUDScreen base class

class ProjectsScreen : CRUDScreen {
    ProjectsScreen() : base("ProjectService", "Project") {
        $this.Title = "Projects"
        # Don't set GridColumns - will setup manually to avoid issues
    }
    
    # Override SetupDataGrid to use UnifiedDataGrid
    [void] SetupDataGrid() {
        # Create UnifiedDataGrid - simpler and more focused than UnifiedList
        $this.DataGrid = [UnifiedDataGrid]::new()
        $this.DataGrid.ShowBorder = $false   # No borders since screen has border
        $this.DataGrid.ShowHeader = $true
        $this.DataGrid.ShowRowNumbers = $false
        
        # Define columns with proper formatting - using known working format
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
                Width = 0  # Flexible width
            },
            @{
                Name = "ID1"
                Header = "ID1"
                Width = 8
            },
            @{
                Name = "ID2"
                Header = "ID2"
                Width = 12
            },
            @{
                Name = "DateAssigned"
                Header = "Assigned"
                Width = 12
                Formatter = {
                    param($value)
                    if ($value -is [DateTime] -and $value -ne [DateTime]::MinValue) {
                        $value.ToString("yyyy-MM-dd")
                    } else {
                        ""
                    }
                }
            },
            @{
                Name = "DateDue"
                Header = "Due"
                Width = 12
                Formatter = {
                    param($value)
                    if ($value -is [DateTime] -and $value -ne [DateTime]::MinValue) {
                        $value.ToString("yyyy-MM-dd")
                    } else {
                        ""
                    }
                }
            }
        )
        
        $this.DataGrid.SetColumns($columns)
        $this.DataGrid.Initialize($global:ServiceContainer)
        $this.AddChild($this.DataGrid)
    }
    
    # Override base class methods for project-specific behavior
    [object] GetSelectedItem() {
        return $this.DataGrid.GetSelectedItem()
    }
    
    [void] LoadData() {
        if ($this.DataService) {
            $projects = $this.DataService.GetAllProjects()
            # Filter out deleted projects and sort by due date
            $activeProjects = $projects | Where-Object { -not $_.Deleted } | Sort-Object DateDue
            $this.DataGrid.SetItems($activeProjects)
            $this.DataGrid.Invalidate()  # Force re-render
            $this.Invalidate()  # Force screen re-render
        }
    }
    
    [void] NewItem() {
        $dialog = [NewProjectDialog]::new()
        $global:ScreenManager.Push($dialog)
    }
    
    [void] EditItem() {
        $selectedProject = $this.GetSelectedItem()
        if ($selectedProject) {
            $dialog = [EditProjectDialog]::new($selectedProject)
            $global:ScreenManager.Push($dialog)
        }
    }
    
    # Additional project-specific methods
    [void] ViewProjectDetails() {
        $selectedProject = $this.GetSelectedItem()
        if ($selectedProject) {
            $detailScreen = [ProjectDetailScreen]::new($selectedProject)
            $global:ScreenManager.Push($detailScreen)
        }
    }
    
    # Compatibility methods for MainScreen integration
    [void] NewProject() { $this.NewItem() }
    [void] EditProject() { $this.EditItem() }
    [void] DeleteProject() { $this.DeleteItem() }
    [void] LoadProjects() { $this.LoadData() }
    [void] RefreshProjects() { $this.RefreshItems() }
    
    # Override SetupCustomEventSubscriptions to disable automatic event handling
    [void] SetupCustomEventSubscriptions() {
        # Disable the automatic event subscriptions that are causing issues
        # We'll handle refresh manually through the dialog
    }
    
    # Override input handling to add project-specific shortcuts
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        # Handle project-specific shortcuts first
        if ($keyInfo.KeyChar -eq 'v') {
            $this.ViewProjectDetails()
            return $true
        }
        
        # Let base class handle standard CRUD shortcuts (n/e/d/r)
        return ([CRUDScreen]$this).HandleScreenInput($keyInfo)
    }
}