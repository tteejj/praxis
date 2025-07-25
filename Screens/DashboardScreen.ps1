# DashboardScreen.ps1 - Ultra-complex dashboard to stress-test layout system
# Layout: Main HorizontalSplit -> Left: Project overview, Right: VerticalSplit -> Top: Task metrics, Bottom: GridPanel with action buttons

class DashboardScreen : Screen {
    # Main layout structure
    [HorizontalSplit]$MainLayout
    [VerticalSplit]$RightLayout
    [GridPanel]$ActionGrid
    [HorizontalSplit]$TopRightLayout
    [VerticalSplit]$MetricsLayout
    
    # Left pane components (Project Overview)
    [ListBox]$ProjectList
    [ListBox]$RecentActivity
    [VerticalSplit]$LeftLayout
    
    # Top-right pane components (Task Metrics & Charts)
    [ListBox]$TaskList
    [ListBox]$PriorityBreakdown
    [ListBox]$StatusChart
    [GridPanel]$MetricBoxes
    
    # Bottom-right pane (Action buttons)
    [Button]$NewProjectBtn
    [Button]$NewTaskBtn
    [Button]$ExportBtn
    [Button]$SettingsBtn
    [Button]$RefreshBtn
    [Button]$HelpBtn
    [Button]$ReportsBtn
    [Button]$ArchiveBtn
    
    # Services
    [ProjectService]$ProjectService
    [TaskService]$TaskService
    [EventBus]$EventBus
    
    # Data for complex displays
    hidden [array]$_projectStats
    hidden [array]$_taskMetrics
    hidden [array]$_recentActivities
    hidden [bool]$_isLoading = $false
    hidden [hashtable]$_loadingProgress = @{
        Projects = 0
        Tasks = 0
        Activity = 0
        Metrics = 0
    }
    
    DashboardScreen() : base() {
        $this.Title = "PRAXIS Dashboard"
    }
    
    [void] OnInitialize() {
        Write-Host "Initializing ultra-complex dashboard..."
        
        # Get services
        $this.ProjectService = $global:ServiceContainer.GetService("ProjectService")
        $this.TaskService = $global:ServiceContainer.GetService("TaskService")
        $this.EventBus = $global:ServiceContainer.GetService('EventBus')
        
        # Subscribe to data loading events for background updates
        $this.SetupEventHandlers()
        
        # Create the incredibly complex nested layout structure
        $this.BuildMasterLayout()
        $this.BuildLeftPane()
        $this.BuildRightPane()
        
        # Show initial loading state
        $this.ShowLoadingState()
        
        # Start background data loading (non-blocking)
        $this.StartBackgroundDataLoad()
        
        Write-Host "Dashboard initialized with maximum complexity!"
    }
    
    [void] BuildMasterLayout() {
        Write-Host "Building master layout structure..."
        
        # Main horizontal split: 40% left (projects), 60% right (tasks & actions)
        $this.MainLayout = [HorizontalSplit]::new()
        $this.MainLayout.SetSplitRatio(40)
        $this.MainLayout.ShowBorder = $false
        $this.MainLayout.Initialize($global:ServiceContainer)
        $this.AddChild($this.MainLayout)
        
        # Left side: Vertical split for project list + recent activity
        $this.LeftLayout = [VerticalSplit]::new()
        $this.LeftLayout.SetSplitRatio(65)  # 65% project list, 35% recent activity
        $this.LeftLayout.ShowBorder = $false
        $this.LeftLayout.Initialize($global:ServiceContainer)
        $this.MainLayout.SetLeftPane($this.LeftLayout)
        
        # Right side: Vertical split for task metrics + action buttons
        $this.RightLayout = [VerticalSplit]::new()
        $this.RightLayout.SetSplitRatio(75)  # 75% metrics, 25% buttons
        $this.RightLayout.ShowBorder = $false
        $this.RightLayout.Initialize($global:ServiceContainer)
        $this.MainLayout.SetRightPane($this.RightLayout)
    }
    
    [void] BuildLeftPane() {
        Write-Host "Building left pane with project overview..."
        
        # Top-left: Project List with statistics
        $this.ProjectList = [ListBox]::new()
        $this.ProjectList.Title = "📊 Project Overview"
        $this.ProjectList.ShowBorder = $true
        $this.ProjectList.ItemRenderer = {
            param($project)
            $status = if ($project.ClosedDate -ne [DateTime]::MinValue) { "✅" } else { "🚧" }
            $daysLeft = ($project.DateDue - [DateTime]::Now).Days
            $urgency = if ($daysLeft -lt 0) { "🔥 OVERDUE" } elseif ($daysLeft -lt 7) { "⚠️  DUE SOON" } elseif ($daysLeft -lt 30) { "📅 $daysLeft days" } else { "📈 $daysLeft days" }
            return "$status $($project.Nickname) - $urgency"
        }
        $this.ProjectList.Initialize($global:ServiceContainer)
        $this.LeftLayout.SetTopPane($this.ProjectList)
        
        # Bottom-left: Recent Activity Feed
        $this.RecentActivity = [ListBox]::new()
        $this.RecentActivity.Title = "📈 Recent Activity"
        $this.RecentActivity.ShowBorder = $true
        $this.RecentActivity.ItemRenderer = {
            param($activity)
            $icon = switch ($activity.Type) {
                "ProjectCreated" { "🆕" }
                "TaskCompleted" { "✅" }
                "TaskCreated" { "📝" }
                "ProjectUpdated" { "📝" }
                default { "ℹ️" }
            }
            return "$icon $($activity.Message) - $($activity.Time)"
        }
        $this.RecentActivity.Initialize($global:ServiceContainer)
        $this.LeftLayout.SetBottomPane($this.RecentActivity)
    }
    
    [void] BuildRightPane() {
        Write-Host "Building right pane with metrics and controls..."
        
        # Top-right: Another horizontal split for task metrics
        $this.TopRightLayout = [HorizontalSplit]::new()
        $this.TopRightLayout.SetSplitRatio(50)  # Equal split for metrics
        $this.TopRightLayout.ShowBorder = $false
        $this.TopRightLayout.Initialize($global:ServiceContainer)
        
        # Nested vertical split in the left side of top-right
        $this.MetricsLayout = [VerticalSplit]::new()
        $this.MetricsLayout.SetSplitRatio(50)
        $this.MetricsLayout.ShowBorder = $false
        $this.MetricsLayout.Initialize($global:ServiceContainer)
        $this.TopRightLayout.SetLeftPane($this.MetricsLayout)
        
        # Task List (top of metrics)
        $this.TaskList = [ListBox]::new()
        $this.TaskList.Title = "🎯 Active Tasks"
        $this.TaskList.ShowBorder = $true
        $this.TaskList.ItemRenderer = {
            param($task)
            $priority = switch ($task.Priority) {
                "High" { "🔴" }
                "Medium" { "🟡" }
                "Low" { "🟢" }
                default { "⚪" }
            }
            $status = switch ($task.Status) {
                "InProgress" { "⚡" }
                "Done" { "✅" }
                "Blocked" { "🚫" }
                default { "📋" }
            }
            return "$priority $status $($task.Title) [$($task.Progress)%]"
        }
        $this.TaskList.Initialize($global:ServiceContainer)
        $this.MetricsLayout.SetTopPane($this.TaskList)
        
        # Priority Breakdown (bottom of metrics)
        $this.PriorityBreakdown = [ListBox]::new()
        $this.PriorityBreakdown.Title = "📊 Priority Distribution"
        $this.PriorityBreakdown.ShowBorder = $true
        $this.PriorityBreakdown.Initialize($global:ServiceContainer)
        $this.MetricsLayout.SetBottomPane($this.PriorityBreakdown)
        
        # Status Chart (right side of top-right)
        $this.StatusChart = [ListBox]::new()
        $this.StatusChart.Title = "📈 Status Overview"
        $this.StatusChart.ShowBorder = $true
        $this.StatusChart.Initialize($global:ServiceContainer)
        $this.TopRightLayout.SetRightPane($this.StatusChart)
        
        # Set the complex top layout
        $this.RightLayout.SetTopPane($this.TopRightLayout)
        
        # Bottom-right: Action button grid (4x2 = 8 buttons)
        $this.ActionGrid = [GridPanel]::new(4)  # 4 columns
        $this.ActionGrid.ShowBorder = $true
        $this.ActionGrid.CellSpacing = 1
        $this.ActionGrid.Initialize($global:ServiceContainer)
        
        # Create all the action buttons with cool icons and actions
        $this.CreateActionButtons()
        
        $this.RightLayout.SetBottomPane($this.ActionGrid)
    }
    
    [void] CreateActionButtons() {
        Write-Host "Creating interactive action buttons..."
        
        # Capture $this reference for use in button handlers
        $dashboardRef = $this
        
        # Button 1: New Project
        $this.NewProjectBtn = [Button]::new("🆕 New Project")
        $this.NewProjectBtn.OnClick = { 
            if ($global:Logger) {
                $global:Logger.Info("Dashboard: New Project button clicked")
            }
            # Create new project dialog
            $dialog = [NewProjectDialog]::new()
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
            }
        }.GetNewClosure()
        $this.NewProjectBtn.Initialize($global:ServiceContainer)
        $this.ActionGrid.AddChild($this.NewProjectBtn)
        
        # Button 2: New Task
        $this.NewTaskBtn = [Button]::new("📝 New Task")
        $this.NewTaskBtn.OnClick = { 
            if ($global:Logger) {
                $global:Logger.Info("Dashboard: New Task button clicked")
            }
            # Create new task dialog
            $dialog = [NewTaskDialog]::new()
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
            }
        }.GetNewClosure()
        $this.NewTaskBtn.Initialize($global:ServiceContainer)
        $this.ActionGrid.AddChild($this.NewTaskBtn)
        
        # Button 3: Export Data
        $this.ExportBtn = [Button]::new("📤 Export")
        $this.ExportBtn.OnClick = { 
            Write-Host "Dashboard: Exporting data..."
            # TODO: Implement export functionality
        }.GetNewClosure()
        $this.ExportBtn.Initialize($global:ServiceContainer)
        $this.ActionGrid.AddChild($this.ExportBtn)
        
        # Button 4: Settings
        $this.SettingsBtn = [Button]::new("⚙️  Settings")
        $this.SettingsBtn.OnClick = { 
            Write-Host "Dashboard: Opening settings..."
            # TODO: Switch to settings screen
        }.GetNewClosure()
        $this.SettingsBtn.Initialize($global:ServiceContainer)
        $this.ActionGrid.AddChild($this.SettingsBtn)
        
        # Button 5: Refresh Data
        $this.RefreshBtn = [Button]::new("🔄 Refresh")
        $this.RefreshBtn.OnClick = { 
            if ($global:Logger) {
                $global:Logger.Info("Dashboard: Refresh button clicked - reloading all data")
            }
            $dashboardRef.ShowLoadingState()
            $dashboardRef.StartBackgroundDataLoad()
        }.GetNewClosure()
        $this.RefreshBtn.Initialize($global:ServiceContainer)
        $this.ActionGrid.AddChild($this.RefreshBtn)
        
        # Button 6: Help
        $this.HelpBtn = [Button]::new("❓ Help")
        $helpBtnRef = $this.HelpBtn
        $this.HelpBtn.OnClick = { 
            if ($global:Logger) {
                $global:Logger.Info("Dashboard: Help button clicked")
            }
            # Change button text to show it was clicked
            $helpBtnRef.Text = "✅ Clicked!"
            $helpBtnRef.Invalidate()
            # TODO: Show help dialog
        }.GetNewClosure()
        $this.HelpBtn.Initialize($global:ServiceContainer)
        $this.ActionGrid.AddChild($this.HelpBtn)
        
        # Button 7: Reports
        $this.ReportsBtn = [Button]::new("📊 Reports")
        $this.ReportsBtn.OnClick = { 
            Write-Host "Dashboard: Generating reports..."
            # TODO: Generate analytics reports
        }.GetNewClosure()
        $this.ReportsBtn.Initialize($global:ServiceContainer)
        $this.ActionGrid.AddChild($this.ReportsBtn)
        
        # Button 8: Archive
        $this.ArchiveBtn = [Button]::new("📦 Archive")
        $this.ArchiveBtn.OnClick = { 
            Write-Host "Dashboard: Managing archives..."
            # TODO: Archive management
        }.GetNewClosure()
        $this.ArchiveBtn.Initialize($global:ServiceContainer)
        $this.ActionGrid.AddChild($this.ArchiveBtn)
    }
    
    [void] LoadAllData() {
        Write-Host "Loading complex dashboard data..."
        
        # Load project data with statistics
        $projects = @()
        if ($this.ProjectService) {
            $allProjects = $this.ProjectService.GetAllProjects()
            $projects = $allProjects | Where-Object { -not $_.Deleted } | Sort-Object DateDue
        }
        
        # Add some demo projects if empty
        if ($projects.Count -eq 0) {
            $projects = @(
                @{ Nickname = "PRAXIS Framework"; ClosedDate = [DateTime]::MinValue; DateDue = [DateTime]::Now.AddDays(30) }
                @{ Nickname = "Dashboard System"; ClosedDate = [DateTime]::MinValue; DateDue = [DateTime]::Now.AddDays(7) }
                @{ Nickname = "Layout Components"; ClosedDate = [DateTime]::Now; DateDue = [DateTime]::Now.AddDays(-5) }
                @{ Nickname = "Testing Framework"; ClosedDate = [DateTime]::MinValue; DateDue = [DateTime]::Now.AddDays(45) }
            )
        }
        
        $this.ProjectList.SetItems($projects)
        
        # Load task data with complex metrics
        $tasks = @()
        if ($this.TaskService) {
            $allTasks = $this.TaskService.GetAllTasks()
            $tasks = $allTasks | Where-Object { $_.Status -ne "Done" } | Sort-Object Priority, Title
        }
        
        # Add demo tasks if empty
        if ($tasks.Count -eq 0) {
            $tasks = @(
                @{ Title = "Implement HorizontalSplit"; Priority = "High"; Status = "Done"; Progress = 100 }
                @{ Title = "Create Dashboard Screen"; Priority = "High"; Status = "InProgress"; Progress = 75 }
                @{ Title = "Add visual styling"; Priority = "Medium"; Status = "InProgress"; Progress = 25 }
                @{ Title = "Fix layout bugs"; Priority = "High"; Status = "Pending"; Progress = 0 }
                @{ Title = "Write documentation"; Priority = "Low"; Status = "Pending"; Progress = 0 }
                @{ Title = "Performance optimization"; Priority = "Medium"; Status = "Blocked"; Progress = 10 }
            )
        }
        
        $this.TaskList.SetItems($tasks)
        
        # Generate priority breakdown with visual charts
        $priorityStats = @(
            "🔴 High Priority: $(@($tasks | Where-Object { $_.Priority -eq 'High' }).Count) tasks"
            "🟡 Medium Priority: $(@($tasks | Where-Object { $_.Priority -eq 'Medium' }).Count) tasks"
            "🟢 Low Priority: $(@($tasks | Where-Object { $_.Priority -eq 'Low' }).Count) tasks"
            ""
            "Progress Overview:"
            "▓▓▓▓▓▓░░░░ 60% Complete"
            "Active: $(@($tasks | Where-Object { $_.Status -eq 'InProgress' }).Count) tasks"
            "Pending: $(@($tasks | Where-Object { $_.Status -eq 'Pending' }).Count) tasks"
        )
        $this.PriorityBreakdown.SetItems($priorityStats)
        
        # Create status chart with ASCII visualization
        $completedTasks = if ($this.TaskService) { 
            @($this.TaskService.GetAllTasks() | Where-Object { $_.Status -eq "Done" }).Count
        } else { 8 }
        
        $totalTasks = $completedTasks + $tasks.Count
        $completionRate = if ($totalTasks -gt 0) { [int](($completedTasks / $totalTasks) * 100) } else { 0 }
        
        $statusData = @(
            "📊 Project Health Dashboard"
            ""
            "Completion Rate: $completionRate%"
            "[$('█' * [int]($completionRate/10))$('░' * (10 - [int]($completionRate/10)))]"
            ""
            "✅ Completed: $completedTasks"
            "⚡ In Progress: $(@($tasks | Where-Object { $_.Status -eq 'InProgress' }).Count)"
            "📋 Pending: $(@($tasks | Where-Object { $_.Status -eq 'Pending' }).Count)"
            "🚫 Blocked: $(@($tasks | Where-Object { $_.Status -eq 'Blocked' }).Count)"
            ""
            "🎯 Productivity Score: $(Get-Random -Minimum 75 -Maximum 98)%"
        )
        $this.StatusChart.SetItems($statusData)
        
        # Create realistic recent activity feed
        $this.LoadRecentActivity()
        
        Write-Host "Dashboard data loaded successfully!"
    }
    
    [void] LoadRecentActivity() {
        $activities = @(
            @{ Type = "TaskCompleted"; Message = "Completed 'Layout Components'"; Time = "2 min ago" }
            @{ Type = "ProjectCreated"; Message = "Started 'Dashboard System'"; Time = "15 min ago" }
            @{ Type = "TaskCreated"; Message = "Added 'Fix layout bugs'"; Time = "1 hour ago" }
            @{ Type = "ProjectUpdated"; Message = "Updated PRAXIS Framework"; Time = "2 hours ago" }
            @{ Type = "TaskCompleted"; Message = "Finished HorizontalSplit tests"; Time = "4 hours ago" }
            @{ Type = "TaskCreated"; Message = "Created performance task"; Time = "1 day ago" }
            @{ Type = "ProjectCreated"; Message = "Initialized Testing Framework"; Time = "2 days ago" }
        )
        
        $this.RecentActivity.SetItems($activities)
    }
    
    [void] SetupEventHandlers() {
        # Subscribe to background data loading completion events
        $dashboardRef = $this
        
        $this.EventBus.Subscribe('dashboard.data.projects.loaded', {
            param($sender, $data)
            if ($data.Projects) {
                $dashboardRef.ProjectList.SetItems($data.Projects)
                $dashboardRef._loadingProgress.Projects = 100
                $dashboardRef.UpdateLoadingStatus()
            }
        }.GetNewClosure())
        
        $this.EventBus.Subscribe('dashboard.data.tasks.loaded', {
            param($sender, $data)
            if ($data.Tasks) {
                $dashboardRef.TaskList.SetItems($data.Tasks)
                $dashboardRef._loadingProgress.Tasks = 100
                $dashboardRef.UpdateLoadingStatus()
            }
        }.GetNewClosure())
        
        $this.EventBus.Subscribe('dashboard.data.activity.loaded', {
            param($sender, $data)
            if ($data.Activities) {
                $dashboardRef.RecentActivity.SetItems($data.Activities)
                $dashboardRef._loadingProgress.Activity = 100
                $dashboardRef.UpdateLoadingStatus()
            }
        }.GetNewClosure())
        
        $this.EventBus.Subscribe('dashboard.data.metrics.loaded', {
            param($sender, $data)
            if ($data.PriorityStats) {
                $dashboardRef.PriorityBreakdown.SetItems($data.PriorityStats)
            }
            if ($data.StatusData) {
                $dashboardRef.StatusChart.SetItems($data.StatusData)
            }
            $dashboardRef._loadingProgress.Metrics = 100
            $dashboardRef.UpdateLoadingStatus()
        }.GetNewClosure())
    }
    
    [void] ShowLoadingState() {
        # Display loading indicators in each component
        $loadingProjects = @(
            "⏳ Loading project data...",
            "   Please wait..."
        )
        $this.ProjectList.SetItems($loadingProjects)
        
        $loadingTasks = @(
            "⏳ Loading task list...",
            "   Fetching from database..."
        )
        $this.TaskList.SetItems($loadingTasks)
        
        $loadingActivity = @(
            "⏳ Loading recent activity...",
            "   Analyzing events..."
        )
        $this.RecentActivity.SetItems($loadingActivity)
        
        $loadingMetrics = @(
            "⏳ Calculating metrics...",
            "   Processing data..."
        )
        $this.PriorityBreakdown.SetItems($loadingMetrics)
        $this.StatusChart.SetItems($loadingMetrics)
    }
    
    [void] StartBackgroundDataLoad() {
        if ($this._isLoading) {
            Write-Host "Data loading already in progress"
            return
        }
        
        $this._isLoading = $true
        $this._loadingProgress = @{
            Projects = 0
            Tasks = 0
            Activity = 0
            Metrics = 0
        }
        
        # Use PowerShell jobs for true background loading
        $projService = $this.ProjectService
        $taskSvc = $this.TaskService
        $evtBus = $this.EventBus
        
        # Load projects in background
        $projectJob = Start-Job -ScriptBlock {
            param($service, $evtBus)
            
            # Simulate loading delay
            Start-Sleep -Milliseconds 800
            
            $projects = @()
            if ($service) {
                $allProjects = $service.GetAllProjects()
                $projects = $allProjects | Where-Object { -not $_.Deleted } | Sort-Object DateDue
            }
            
            if ($projects.Count -eq 0) {
                $projects = @(
                    @{ Nickname = "PRAXIS Framework"; ClosedDate = [DateTime]::MinValue; DateDue = [DateTime]::Now.AddDays(30) }
                    @{ Nickname = "Dashboard System"; ClosedDate = [DateTime]::MinValue; DateDue = [DateTime]::Now.AddDays(7) }
                    @{ Nickname = "Layout Components"; ClosedDate = [DateTime]::Now; DateDue = [DateTime]::Now.AddDays(-5) }
                    @{ Nickname = "Testing Framework"; ClosedDate = [DateTime]::MinValue; DateDue = [DateTime]::Now.AddDays(45) }
                )
            }
            
            # Process projects
            foreach ($project in $projects) {
                $project.ClosedDate = if ($project.ClosedDate) { $project.ClosedDate } else { [DateTime]::MinValue }
                $project.DateDue = if ($project.DateDue) { $project.DateDue } else { [DateTime]::Now.AddDays(30) }
            }
            
            return $projects
        } -ArgumentList $projService, $evtBus
        
        # Load tasks in background
        $taskJob = Start-Job -ScriptBlock {
            param($service)
            
            # Simulate loading delay
            Start-Sleep -Milliseconds 1200
            
            $tasks = @()
            if ($service) {
                $allTasks = $service.GetAllTasks()
                $tasks = $allTasks | Where-Object { $_.Status -ne "Done" } | Sort-Object Priority, Title
            }
            
            if ($tasks.Count -eq 0) {
                $tasks = @(
                    @{ Title = "Implement HorizontalSplit"; Priority = "High"; Status = "Done"; Progress = 100 }
                    @{ Title = "Create Dashboard Screen"; Priority = "High"; Status = "InProgress"; Progress = 75 }
                    @{ Title = "Add visual styling"; Priority = "Medium"; Status = "InProgress"; Progress = 25 }
                    @{ Title = "Fix layout bugs"; Priority = "High"; Status = "Pending"; Progress = 0 }
                    @{ Title = "Write documentation"; Priority = "Low"; Status = "Pending"; Progress = 0 }
                    @{ Title = "Performance optimization"; Priority = "Medium"; Status = "Blocked"; Progress = 10 }
                )
            }
            
            return $tasks
        } -ArgumentList $taskSvc
        
        # Monitor jobs and publish events when complete
        $monitorJob = Start-Job -ScriptBlock {
            param($projectJob, $taskJob, $evtBus)
            
            # Wait for project job
            $projects = Receive-Job -Job $projectJob -Wait
            $evtBus.Publish('dashboard.data.projects.loaded', @{ Projects = $projects })
            
            # Wait for task job
            $tasks = Receive-Job -Job $taskJob -Wait
            $evtBus.Publish('dashboard.data.tasks.loaded', @{ Tasks = $tasks })
            
            # Generate metrics based on loaded data
            Start-Sleep -Milliseconds 500
            
            $priorityStats = @(
                "🔴 High Priority: $(@($tasks | Where-Object { $_.Priority -eq 'High' }).Count) tasks"
                "🟡 Medium Priority: $(@($tasks | Where-Object { $_.Priority -eq 'Medium' }).Count) tasks"
                "🟢 Low Priority: $(@($tasks | Where-Object { $_.Priority -eq 'Low' }).Count) tasks"
                ""
                "Progress Overview:"
                "▓▓▓▓▓▓░░░░ 60% Complete"
            )
            
            $completedTasks = @($tasks | Where-Object { $_.Status -eq "Done" }).Count
            $totalTasks = $tasks.Count + $completedTasks
            $completionRate = if ($totalTasks -gt 0) { [int](($completedTasks / $totalTasks) * 100) } else { 0 }
            
            $statusData = @(
                "📊 Project Health Dashboard"
                ""
                "Completion Rate: $completionRate%"
                "[$('█' * [int]($completionRate/10))$('░' * (10 - [int]($completionRate/10)))]"
                ""
                "✅ Completed: $completedTasks"
                "⚡ In Progress: $(@($tasks | Where-Object { $_.Status -eq 'InProgress' }).Count)"
                "📋 Pending: $(@($tasks | Where-Object { $_.Status -eq 'Pending' }).Count)"
                "🚫 Blocked: $(@($tasks | Where-Object { $_.Status -eq 'Blocked' }).Count)"
            )
            
            $evtBus.Publish('dashboard.data.metrics.loaded', @{ 
                PriorityStats = $priorityStats
                StatusData = $statusData 
            })
            
            # Load activity data
            Start-Sleep -Milliseconds 300
            $activities = @(
                @{ Type = "TaskCompleted"; Message = "Completed 'Layout Components'"; Time = "2 min ago" }
                @{ Type = "ProjectCreated"; Message = "Started 'Dashboard System'"; Time = "15 min ago" }
                @{ Type = "TaskCreated"; Message = "Added 'Fix layout bugs'"; Time = "1 hour ago" }
                @{ Type = "ProjectUpdated"; Message = "Updated PRAXIS Framework"; Time = "2 hours ago" }
                @{ Type = "TaskCompleted"; Message = "Finished HorizontalSplit tests"; Time = "4 hours ago" }
            )
            
            $evtBus.Publish('dashboard.data.activity.loaded', @{ Activities = $activities })
            
            # Clean up jobs
            Remove-Job -Job $projectJob -Force
            Remove-Job -Job $taskJob -Force
            
        } -ArgumentList $projectJob, $taskJob, $evtBus
        
        # Set up item renderers that will be used when data loads
        $this.ProjectList.ItemRenderer = {
            param($project)
            $status = if ($project.ClosedDate -ne [DateTime]::MinValue) { "✅" } else { "🚧" }
            $daysLeft = ($project.DateDue - [DateTime]::Now).Days
            $urgency = if ($daysLeft -lt 0) { "🔥 OVERDUE" } elseif ($daysLeft -lt 7) { "⚠️  DUE SOON" } elseif ($daysLeft -lt 30) { "📅 $daysLeft days" } else { "📈 $daysLeft days" }
            return "$status $($project.Nickname) - $urgency"
        }
        
        $this.TaskList.ItemRenderer = {
            param($task)
            $priority = switch ($task.Priority) {
                "High" { "🔴" }
                "Medium" { "🟡" }
                "Low" { "🟢" }
                default { "⚪" }
            }
            $status = switch ($task.Status) {
                "InProgress" { "⚡" }
                "Done" { "✅" }
                "Blocked" { "🚫" }
                default { "📋" }
            }
            return "$priority $status $($task.Title) [$($task.Progress)%]"
        }
        
        $this.RecentActivity.ItemRenderer = {
            param($activity)
            $icon = switch ($activity.Type) {
                "ProjectCreated" { "🆕" }
                "TaskCompleted" { "✅" }
                "TaskCreated" { "📝" }
                "ProjectUpdated" { "📝" }
                default { "ℹ️" }
            }
            return "$icon $($activity.Message) - $($activity.Time)"
        }
    }
    
    [void] UpdateLoadingStatus() {
        # Check if all data has loaded
        $totalProgress = ($this._loadingProgress.Projects + $this._loadingProgress.Tasks + 
                         $this._loadingProgress.Activity + $this._loadingProgress.Metrics) / 4
        
        if ($totalProgress -eq 100) {
            $this._isLoading = $false
            Write-Host "Dashboard data fully loaded!"
        }
    }
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        # Set initial focus to ProjectList
        if ($this.ProjectList) {
            $this.ProjectList.Focus()
        }
    }
    
    [void] OnBoundsChanged() {
        # Update the main layout to fill the entire screen
        if ($this.MainLayout) {
            $this.MainLayout.SetBounds($this.X, $this.Y, $this.Width, $this.Height)
        }
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        # Handle dashboard-specific shortcuts
        switch ($key.Key) {
            ([System.ConsoleKey]::F5) {
                $this.ShowLoadingState()
                $this.StartBackgroundDataLoad()
                Write-Host "Dashboard refresh started!"
                return $true
            }
            ([System.ConsoleKey]::R) {
                if (-not $key.Modifiers -and ($key.KeyChar -eq 'R' -or $key.KeyChar -eq 'r')) {
                    $this.ShowLoadingState()
                    $this.StartBackgroundDataLoad()
                    Write-Host "Dashboard data reload started!"
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
        
        return $false
    }
    
}