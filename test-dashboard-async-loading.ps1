#!/usr/bin/env pwsh

# Test for background data loading with progress indicators in DashboardScreen
# This demonstrates how to implement non-blocking data loading

. ./Start.ps1 -NoRun

# Create an enhanced DashboardScreen with background loading
class AsyncDashboardScreen : Screen {
    # Main layout structure (same as original)
    [HorizontalSplit]$MainLayout
    [VerticalSplit]$RightLayout
    [GridPanel]$ActionGrid
    [HorizontalSplit]$TopRightLayout
    [VerticalSplit]$MetricsLayout
    
    # Left pane components
    [ListBox]$ProjectList
    [ListBox]$RecentActivity
    [VerticalSplit]$LeftLayout
    
    # Top-right pane components
    [ListBox]$TaskList
    [ListBox]$PriorityBreakdown
    [ListBox]$StatusChart
    [GridPanel]$MetricBoxes
    
    # Progress indicators for each section
    [ProgressBar]$ProjectProgress
    [ProgressBar]$TaskProgress
    [ProgressBar]$ActivityProgress
    [ProgressBar]$MetricsProgress
    
    # Loading overlays
    [hashtable]$LoadingStates = @{
        Projects = $false
        Tasks = $false
        Activity = $false
        Metrics = $false
    }
    
    # Services
    [ProjectService]$ProjectService
    [TaskService]$TaskService
    [EventBus]$EventBus
    [ThemeManager]$Theme
    
    # Data loading flags
    hidden [bool]$_isLoading = $false
    hidden [System.Collections.Generic.List[string]]$_loadingTasks
    
    AsyncDashboardScreen() : base() {
        $this.Title = "PRAXIS Async Dashboard"
        $this._loadingTasks = [System.Collections.Generic.List[string]]::new()
    }
    
    [void] OnInitialize() {
        Write-Host "Initializing async dashboard..."
        
        # Get services
        $this.ProjectService = $global:ServiceContainer.GetService("ProjectService")
        $this.TaskService = $global:ServiceContainer.GetService("TaskService")
        $this.EventBus = $global:ServiceContainer.GetService('EventBus')
        $this.Theme = $global:ServiceContainer.GetService('ThemeManager')
        
        # Subscribe to data loading events
        $this.SetupEventHandlers()
        
        # Build UI structure immediately
        $this.BuildMasterLayout()
        $this.BuildLeftPane()
        $this.BuildRightPane()
        
        # Show initial empty state with loading indicators
        $this.ShowLoadingState()
        
        # Start background data loading
        $this.StartAsyncDataLoad()
        
        Write-Host "Dashboard UI ready, loading data in background..."
    }
    
    [void] SetupEventHandlers() {
        # Progress update events
        $this.EventBus.Subscribe('dashboard.progress.projects', {
            param($sender, $data)
            if ($this.ProjectProgress) {
                $this.ProjectProgress.SetProgress($data.Progress, $data.Status)
            }
        }.GetNewClosure())
        
        $this.EventBus.Subscribe('dashboard.progress.tasks', {
            param($sender, $data)
            if ($this.TaskProgress) {
                $this.TaskProgress.SetProgress($data.Progress, $data.Status)
            }
        }.GetNewClosure())
        
        $this.EventBus.Subscribe('dashboard.progress.activity', {
            param($sender, $data)
            if ($this.ActivityProgress) {
                $this.ActivityProgress.SetProgress($data.Progress, $data.Status)
            }
        }.GetNewClosure())
        
        $this.EventBus.Subscribe('dashboard.progress.metrics', {
            param($sender, $data)
            if ($this.MetricsProgress) {
                $this.MetricsProgress.SetProgress($data.Progress, $data.Status)
            }
        }.GetNewClosure())
        
        # Data loaded events
        $this.EventBus.Subscribe('dashboard.data.projects', {
            param($sender, $data)
            $this.OnProjectsLoaded($data.Projects)
        }.GetNewClosure())
        
        $this.EventBus.Subscribe('dashboard.data.tasks', {
            param($sender, $data)
            $this.OnTasksLoaded($data.Tasks)
        }.GetNewClosure())
        
        $this.EventBus.Subscribe('dashboard.data.activity', {
            param($sender, $data)
            $this.OnActivityLoaded($data.Activities)
        }.GetNewClosure())
        
        $this.EventBus.Subscribe('dashboard.data.metrics', {
            param($sender, $data)
            $this.OnMetricsLoaded($data.Metrics)
        }.GetNewClosure())
    }
    
    [void] BuildMasterLayout() {
        # Same as original, but with progress bars
        Write-Host "Building master layout structure..."
        
        # Main horizontal split
        $this.MainLayout = [HorizontalSplit]::new()
        $this.MainLayout.SetSplitRatio(40)
        $this.MainLayout.ShowBorder = $false
        $this.MainLayout.Initialize($global:ServiceContainer)
        $this.AddChild($this.MainLayout)
        
        # Left side: Vertical split
        $this.LeftLayout = [VerticalSplit]::new()
        $this.LeftLayout.SetSplitRatio(65)
        $this.LeftLayout.ShowBorder = $false
        $this.LeftLayout.Initialize($global:ServiceContainer)
        $this.MainLayout.SetLeftPane($this.LeftLayout)
        
        # Right side: Vertical split
        $this.RightLayout = [VerticalSplit]::new()
        $this.RightLayout.SetSplitRatio(75)
        $this.RightLayout.ShowBorder = $false
        $this.RightLayout.Initialize($global:ServiceContainer)
        $this.MainLayout.SetRightPane($this.RightLayout)
    }
    
    [void] BuildLeftPane() {
        # Project List with progress bar overlay
        $projectContainer = [VerticalSplit]::new()
        $projectContainer.SetSplitRatio(85)  # 85% list, 15% progress
        $projectContainer.ShowBorder = $false
        $projectContainer.Initialize($global:ServiceContainer)
        
        $this.ProjectList = [ListBox]::new()
        $this.ProjectList.Title = "📊 Project Overview"
        $this.ProjectList.ShowBorder = $true
        $this.ProjectList.Initialize($global:ServiceContainer)
        $projectContainer.SetTopPane($this.ProjectList)
        
        $this.ProjectProgress = [ProgressBar]::new()
        $this.ProjectProgress.Title = "Loading Projects..."
        $this.ProjectProgress.ShowBorder = $false
        $this.ProjectProgress.Height = 3
        $this.ProjectProgress.Initialize($global:ServiceContainer)
        $projectContainer.SetBottomPane($this.ProjectProgress)
        
        $this.LeftLayout.SetTopPane($projectContainer)
        
        # Recent Activity with progress bar
        $activityContainer = [VerticalSplit]::new()
        $activityContainer.SetSplitRatio(80)  # 80% list, 20% progress
        $activityContainer.ShowBorder = $false
        $activityContainer.Initialize($global:ServiceContainer)
        
        $this.RecentActivity = [ListBox]::new()
        $this.RecentActivity.Title = "📈 Recent Activity"
        $this.RecentActivity.ShowBorder = $true
        $this.RecentActivity.Initialize($global:ServiceContainer)
        $activityContainer.SetTopPane($this.RecentActivity)
        
        $this.ActivityProgress = [ProgressBar]::new()
        $this.ActivityProgress.Title = "Loading Activity..."
        $this.ActivityProgress.ShowBorder = $false
        $this.ActivityProgress.Height = 3
        $this.ActivityProgress.Initialize($global:ServiceContainer)
        $activityContainer.SetBottomPane($this.ActivityProgress)
        
        $this.LeftLayout.SetBottomPane($activityContainer)
    }
    
    [void] BuildRightPane() {
        # Top-right: Metrics layout
        $this.TopRightLayout = [HorizontalSplit]::new()
        $this.TopRightLayout.SetSplitRatio(50)
        $this.TopRightLayout.ShowBorder = $false
        $this.TopRightLayout.Initialize($global:ServiceContainer)
        
        # Task metrics with progress
        $taskContainer = [VerticalSplit]::new()
        $taskContainer.SetSplitRatio(85)
        $taskContainer.ShowBorder = $false
        $taskContainer.Initialize($global:ServiceContainer)
        
        $this.MetricsLayout = [VerticalSplit]::new()
        $this.MetricsLayout.SetSplitRatio(50)
        $this.MetricsLayout.ShowBorder = $false
        $this.MetricsLayout.Initialize($global:ServiceContainer)
        
        $this.TaskList = [ListBox]::new()
        $this.TaskList.Title = "🎯 Active Tasks"
        $this.TaskList.ShowBorder = $true
        $this.TaskList.Initialize($global:ServiceContainer)
        $this.MetricsLayout.SetTopPane($this.TaskList)
        
        $this.PriorityBreakdown = [ListBox]::new()
        $this.PriorityBreakdown.Title = "📊 Priority Distribution"
        $this.PriorityBreakdown.ShowBorder = $true
        $this.PriorityBreakdown.Initialize($global:ServiceContainer)
        $this.MetricsLayout.SetBottomPane($this.PriorityBreakdown)
        
        $taskContainer.SetTopPane($this.MetricsLayout)
        
        $this.TaskProgress = [ProgressBar]::new()
        $this.TaskProgress.Title = "Loading Tasks..."
        $this.TaskProgress.ShowBorder = $false
        $this.TaskProgress.Height = 3
        $this.TaskProgress.Initialize($global:ServiceContainer)
        $taskContainer.SetBottomPane($this.TaskProgress)
        
        $this.TopRightLayout.SetLeftPane($taskContainer)
        
        # Status chart with progress
        $statusContainer = [VerticalSplit]::new()
        $statusContainer.SetSplitRatio(85)
        $statusContainer.ShowBorder = $false
        $statusContainer.Initialize($global:ServiceContainer)
        
        $this.StatusChart = [ListBox]::new()
        $this.StatusChart.Title = "📈 Status Overview"
        $this.StatusChart.ShowBorder = $true
        $this.StatusChart.Initialize($global:ServiceContainer)
        $statusContainer.SetTopPane($this.StatusChart)
        
        $this.MetricsProgress = [ProgressBar]::new()
        $this.MetricsProgress.Title = "Calculating Metrics..."
        $this.MetricsProgress.ShowBorder = $false
        $this.MetricsProgress.Height = 3
        $this.MetricsProgress.Initialize($global:ServiceContainer)
        $statusContainer.SetBottomPane($this.MetricsProgress)
        
        $this.TopRightLayout.SetRightPane($statusContainer)
        
        $this.RightLayout.SetTopPane($this.TopRightLayout)
        
        # Action buttons (same as original)
        $this.ActionGrid = [GridPanel]::new(4)
        $this.ActionGrid.ShowBorder = $true
        $this.ActionGrid.CellSpacing = 1
        $this.ActionGrid.Initialize($global:ServiceContainer)
        $this.CreateActionButtons()
        $this.RightLayout.SetBottomPane($this.ActionGrid)
    }
    
    [void] CreateActionButtons() {
        # Create refresh button with async behavior
        $this.RefreshBtn = [Button]::new("🔄 Refresh")
        $dashboardRef = $this
        $this.RefreshBtn.OnClick = { 
            Write-Host "Starting async refresh..."
            $dashboardRef.StartAsyncDataLoad()
        }.GetNewClosure()
        $this.RefreshBtn.Initialize($global:ServiceContainer)
        $this.ActionGrid.AddChild($this.RefreshBtn)
        
        # Add other buttons...
        $otherButtons = @(
            [Button]::new("🆕 New Project"),
            [Button]::new("📝 New Task"),
            [Button]::new("📤 Export"),
            [Button]::new("⚙️  Settings"),
            [Button]::new("❓ Help"),
            [Button]::new("📊 Reports"),
            [Button]::new("📦 Archive")
        )
        
        foreach ($btn in $otherButtons) {
            $btn.Initialize($global:ServiceContainer)
            $this.ActionGrid.AddChild($btn)
        }
    }
    
    [void] ShowLoadingState() {
        # Show loading placeholders
        $this.ProjectList.SetItems(@("⏳ Loading projects..."))
        $this.TaskList.SetItems(@("⏳ Loading tasks..."))
        $this.RecentActivity.SetItems(@("⏳ Loading activity..."))
        $this.PriorityBreakdown.SetItems(@("⏳ Calculating..."))
        $this.StatusChart.SetItems(@("⏳ Analyzing..."))
        
        # Initialize progress bars
        $this.ProjectProgress.SetProgress(0, "Connecting to project service...")
        $this.TaskProgress.SetProgress(0, "Connecting to task service...")
        $this.ActivityProgress.SetProgress(0, "Loading recent activity...")
        $this.MetricsProgress.SetProgress(0, "Preparing metrics...")
    }
    
    [void] StartAsyncDataLoad() {
        if ($this._isLoading) {
            Write-Host "Data load already in progress"
            return
        }
        
        $this._isLoading = $true
        $this.ShowLoadingState()
        
        # Simulate async loading with runspaces
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.Open()
        $runspace.SessionStateProxy.SetVariable('EventBus', $this.EventBus)
        $runspace.SessionStateProxy.SetVariable('ProjectService', $this.ProjectService)
        $runspace.SessionStateProxy.SetVariable('TaskService', $this.TaskService)
        
        $powershell = [powershell]::Create()
        $powershell.Runspace = $runspace
        
        $script = {
            param($EventBus, $ProjectService, $TaskService)
            
            try {
                # Load projects
                $EventBus.Publish('dashboard.progress.projects', @{ Progress = 10; Status = "Fetching project list..." })
                Start-Sleep -Milliseconds 500
                
                $projects = if ($ProjectService) {
                    $ProjectService.GetAllProjects() | Where-Object { -not $_.Deleted }
                } else {
                    @(
                        @{ Nickname = "PRAXIS Framework"; ClosedDate = [DateTime]::MinValue; DateDue = [DateTime]::Now.AddDays(30) }
                        @{ Nickname = "Dashboard System"; ClosedDate = [DateTime]::MinValue; DateDue = [DateTime]::Now.AddDays(7) }
                    )
                }
                
                $EventBus.Publish('dashboard.progress.projects', @{ Progress = 50; Status = "Processing $($projects.Count) projects..." })
                Start-Sleep -Milliseconds 300
                
                # Add computed fields
                foreach ($project in $projects) {
                    $project.DaysLeft = ($project.DateDue - [DateTime]::Now).Days
                    Start-Sleep -Milliseconds 100
                }
                
                $EventBus.Publish('dashboard.progress.projects', @{ Progress = 100; Status = "Projects loaded!" })
                $EventBus.Publish('dashboard.data.projects', @{ Projects = $projects })
                
                # Load tasks
                $EventBus.Publish('dashboard.progress.tasks', @{ Progress = 20; Status = "Querying task database..." })
                Start-Sleep -Milliseconds 400
                
                $tasks = if ($TaskService) {
                    $TaskService.GetAllTasks()
                } else {
                    @(
                        @{ Title = "Implement async loading"; Priority = "High"; Status = "InProgress"; Progress = 75 }
                        @{ Title = "Add progress indicators"; Priority = "High"; Status = "Done"; Progress = 100 }
                        @{ Title = "Test performance"; Priority = "Medium"; Status = "Pending"; Progress = 0 }
                    )
                }
                
                $EventBus.Publish('dashboard.progress.tasks', @{ Progress = 60; Status = "Processing $($tasks.Count) tasks..." })
                Start-Sleep -Milliseconds 300
                
                $EventBus.Publish('dashboard.progress.tasks', @{ Progress = 100; Status = "Tasks loaded!" })
                $EventBus.Publish('dashboard.data.tasks', @{ Tasks = $tasks })
                
                # Load activity
                $EventBus.Publish('dashboard.progress.activity', @{ Progress = 30; Status = "Fetching activity log..." })
                Start-Sleep -Milliseconds 600
                
                $activities = @(
                    @{ Type = "TaskCompleted"; Message = "Async loading implemented"; Time = "Just now" }
                    @{ Type = "ProjectCreated"; Message = "Started performance project"; Time = "5 min ago" }
                    @{ Type = "TaskCreated"; Message = "Added progress indicators"; Time = "1 hour ago" }
                )
                
                $EventBus.Publish('dashboard.progress.activity', @{ Progress = 100; Status = "Activity loaded!" })
                $EventBus.Publish('dashboard.data.activity', @{ Activities = $activities })
                
                # Calculate metrics
                $EventBus.Publish('dashboard.progress.metrics', @{ Progress = 40; Status = "Analyzing data..." })
                Start-Sleep -Milliseconds 800
                
                $metrics = @{
                    PriorityStats = @("High: 3", "Medium: 2", "Low: 1")
                    StatusData = @("Completion: 85%", "Active: 3", "Blocked: 0")
                }
                
                $EventBus.Publish('dashboard.progress.metrics', @{ Progress = 100; Status = "Analysis complete!" })
                $EventBus.Publish('dashboard.data.metrics', @{ Metrics = $metrics })
                
            } catch {
                Write-Host "Error in async load: $_"
            }
        }
        
        $powershell.AddScript($script)
        $powershell.AddArgument($this.EventBus)
        $powershell.AddArgument($this.ProjectService)
        $powershell.AddArgument($this.TaskService)
        
        # Start async execution
        $handle = $powershell.BeginInvoke()
        
        # Store handle for cleanup
        $this._loadingTasks.Add("main-load")
    }
    
    [void] OnProjectsLoaded($projects) {
        # Update project list with loaded data
        $this.ProjectList.ItemRenderer = {
            param($project)
            $status = if ($project.ClosedDate -ne [DateTime]::MinValue) { "✅" } else { "🚧" }
            $urgency = if ($project.DaysLeft -lt 0) { "🔥 OVERDUE" } 
                      elseif ($project.DaysLeft -lt 7) { "⚠️  DUE SOON" } 
                      else { "📅 $($project.DaysLeft) days" }
            return "$status $($project.Nickname) - $urgency"
        }
        $this.ProjectList.SetItems($projects)
        $this.ProjectProgress.SetProgress(100, "✅ Projects loaded")
    }
    
    [void] OnTasksLoaded($tasks) {
        # Update task list
        $this.TaskList.ItemRenderer = {
            param($task)
            $priority = switch ($task.Priority) {
                "High" { "🔴" }; "Medium" { "🟡" }; default { "🟢" }
            }
            $status = switch ($task.Status) {
                "InProgress" { "⚡" }; "Done" { "✅" }; default { "📋" }
            }
            return "$priority $status $($task.Title) [$($task.Progress)%]"
        }
        $activeTasks = $tasks | Where-Object { $_.Status -ne "Done" }
        $this.TaskList.SetItems($activeTasks)
        $this.TaskProgress.SetProgress(100, "✅ Tasks loaded")
        
        # Update priority breakdown
        $highCount = @($tasks | Where-Object { $_.Priority -eq 'High' }).Count
        $medCount = @($tasks | Where-Object { $_.Priority -eq 'Medium' }).Count
        $lowCount = @($tasks | Where-Object { $_.Priority -eq 'Low' }).Count
        
        $this.PriorityBreakdown.SetItems(@(
            "🔴 High Priority: $highCount tasks",
            "🟡 Medium Priority: $medCount tasks",
            "🟢 Low Priority: $lowCount tasks"
        ))
    }
    
    [void] OnActivityLoaded($activities) {
        $this.RecentActivity.ItemRenderer = {
            param($activity)
            $icon = switch ($activity.Type) {
                "TaskCompleted" { "✅" }; "ProjectCreated" { "🆕" }; default { "📝" }
            }
            return "$icon $($activity.Message) - $($activity.Time)"
        }
        $this.RecentActivity.SetItems($activities)
        $this.ActivityProgress.SetProgress(100, "✅ Activity loaded")
    }
    
    [void] OnMetricsLoaded($metrics) {
        $this.StatusChart.SetItems($metrics.StatusData)
        $this.MetricsProgress.SetProgress(100, "✅ Analysis complete")
        $this._isLoading = $false
    }
    
    [void] OnBoundsChanged() {
        if ($this.MainLayout) {
            $this.MainLayout.SetBounds($this.X, $this.Y, $this.Width, $this.Height)
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::F5) {
                $this.StartAsyncDataLoad()
                return $true
            }
            ([System.ConsoleKey]::Q) {
                if (-not $key.Modifiers) {
                    $this.Active = $false
                    return $true
                }
            }
        }
        return ([Screen]$this).HandleInput($key)
    }
}

# Create and run the test
Write-Host "Starting async dashboard demo..." -ForegroundColor Cyan
Write-Host "The dashboard will load immediately with progress indicators" -ForegroundColor Yellow
Write-Host "Data will load in the background without blocking the UI" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press F5 to refresh data, Q to quit" -ForegroundColor Green
Write-Host ""

# Initialize services
$global:ServiceContainer = [ServiceContainer]::new()
$vt = [VT100]::new()
$global:ServiceContainer.RegisterService('VT100', $vt)

$logger = [Logger]::new("$PSScriptRoot/_Logs/async-dashboard.log")
$global:ServiceContainer.RegisterService('Logger', $logger)
$global:Logger = $logger

$theme = [ThemeManager]::new()
$theme.LoadTheme('Dark')
$global:ServiceContainer.RegisterService('ThemeManager', $theme)

$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.RegisterService('EventBus', $eventBus)

$projectService = [ProjectService]::new("$PSScriptRoot/_ProjectData/projects.json")
$global:ServiceContainer.RegisterService('ProjectService', $projectService)

$taskService = [TaskService]::new("$PSScriptRoot/_ProjectData/tasks.json")
$global:ServiceContainer.RegisterService('TaskService', $taskService)

# Create screen manager and run
$screenManager = [ScreenManager]::new()
$screenManager.Initialize($global:ServiceContainer)
$global:ScreenManager = $screenManager

$dashboard = [AsyncDashboardScreen]::new()
$screenManager.Push($dashboard)
$screenManager.Run()

Write-Host "`nAsync dashboard demo completed!" -ForegroundColor Green