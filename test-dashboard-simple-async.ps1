#!/usr/bin/env pwsh

# Simple example of background loading with progress indicators
# Uses timers to simulate async data loading without PowerShell jobs

. ./Start.ps1 -NoRun

# Enhanced DashboardScreen with simulated async loading
class SimpleAsyncDashboardScreen : Screen {
    # Layout components
    [HorizontalSplit]$MainLayout
    [VerticalSplit]$LeftLayout
    [ListBox]$ProjectList
    [ListBox]$TaskList
    [ProgressBar]$LoadingProgress
    
    # Services
    [EventBus]$EventBus
    [ThemeManager]$Theme
    
    # Loading state
    hidden [int]$_loadStep = 0
    hidden [bool]$_isLoading = $false
    hidden [hashtable]$_pendingData = @{}
    
    SimpleAsyncDashboardScreen() : base() {
        $this.Title = "Simple Async Dashboard Demo"
    }
    
    [void] OnInitialize() {
        # Get services
        $this.EventBus = $global:ServiceContainer.GetService('EventBus')
        $this.Theme = $global:ServiceContainer.GetService('ThemeManager')
        
        # Build UI
        $this.BuildLayout()
        
        # Show initial loading state
        $this.ShowLoadingState()
        
        # Start simulated async loading
        $this.StartSimulatedAsyncLoad()
    }
    
    [void] BuildLayout() {
        # Main horizontal split
        $this.MainLayout = [HorizontalSplit]::new()
        $this.MainLayout.SetSplitRatio(50)
        $this.MainLayout.ShowBorder = $false
        $this.MainLayout.Initialize($global:ServiceContainer)
        $this.AddChild($this.MainLayout)
        
        # Left side with progress bar
        $this.LeftLayout = [VerticalSplit]::new()
        $this.LeftLayout.SetSplitRatio(85)  # 85% list, 15% progress
        $this.LeftLayout.ShowBorder = $false
        $this.LeftLayout.Initialize($global:ServiceContainer)
        
        $this.ProjectList = [ListBox]::new()
        $this.ProjectList.Title = "📊 Projects"
        $this.ProjectList.ShowBorder = $true
        $this.ProjectList.Initialize($global:ServiceContainer)
        $this.LeftLayout.SetTopPane($this.ProjectList)
        
        $this.LoadingProgress = [ProgressBar]::new()
        $this.LoadingProgress.Title = "Loading Data..."
        $this.LoadingProgress.ShowBorder = $true
        $this.LoadingProgress.Height = 5
        $this.LoadingProgress.Initialize($global:ServiceContainer)
        $this.LeftLayout.SetBottomPane($this.LoadingProgress)
        
        $this.MainLayout.SetLeftPane($this.LeftLayout)
        
        # Right side
        $this.TaskList = [ListBox]::new()
        $this.TaskList.Title = "🎯 Tasks"
        $this.TaskList.ShowBorder = $true
        $this.TaskList.Initialize($global:ServiceContainer)
        $this.MainLayout.SetRightPane($this.TaskList)
    }
    
    [void] ShowLoadingState() {
        $this.ProjectList.SetItems(@(
            "⏳ Loading projects...",
            "",
            "Please wait while we fetch",
            "your project data..."
        ))
        
        $this.TaskList.SetItems(@(
            "⏳ Loading tasks...",
            "",
            "Task data will appear",
            "here shortly..."
        ))
        
        $this.LoadingProgress.SetProgress(0, "Initializing...")
    }
    
    [void] StartSimulatedAsyncLoad() {
        if ($this._isLoading) {
            return
        }
        
        $this._isLoading = $true
        $this._loadStep = 0
        
        # Simulate loading steps with a timer
        $timer = [System.Timers.Timer]::new(500)  # 500ms intervals
        
        $dashboardRef = $this
        $timer.add_Elapsed({
            $dashboardRef.ProcessLoadStep()
        })
        
        $timer.AutoReset = $true
        $timer.Enabled = $true
        $timer.Start()
        
        # Store timer reference for cleanup
        $this._pendingData['timer'] = $timer
    }
    
    [void] ProcessLoadStep() {
        $this._loadStep++
        
        switch ($this._loadStep) {
            1 {
                # Step 1: Connect to services
                $this.LoadingProgress.SetProgress(10, "Connecting to services...")
            }
            2 {
                # Step 2: Fetch project data
                $this.LoadingProgress.SetProgress(25, "Fetching project data...")
            }
            3 {
                # Step 3: Process projects
                $this.LoadingProgress.SetProgress(40, "Processing projects...")
                
                # Simulate project data
                $projects = @(
                    "🚧 PRAXIS Framework - 📅 30 days",
                    "🚧 Dashboard System - ⚠️  DUE SOON",
                    "✅ Layout Components - 🔥 OVERDUE",
                    "🚧 Testing Framework - 📈 45 days"
                )
                $this.ProjectList.SetItems($projects)
            }
            4 {
                # Step 4: Fetch task data
                $this.LoadingProgress.SetProgress(60, "Fetching task data...")
            }
            5 {
                # Step 5: Process tasks
                $this.LoadingProgress.SetProgress(80, "Processing tasks...")
                
                # Simulate task data
                $tasks = @(
                    "🔴 ⚡ Implement async loading [75%]",
                    "🔴 📋 Fix layout bugs [0%]",
                    "🟡 ⚡ Add visual styling [25%]",
                    "🟡 🚫 Performance optimization [10%]",
                    "🟢 📋 Write documentation [0%]"
                )
                $this.TaskList.SetItems($tasks)
            }
            6 {
                # Step 6: Finalize
                $this.LoadingProgress.SetProgress(100, "✅ Loading complete!")
                
                # Stop and clean up timer
                if ($this._pendingData['timer']) {
                    $this._pendingData['timer'].Stop()
                    $this._pendingData['timer'].Dispose()
                    $this._pendingData.Remove('timer')
                }
                
                $this._isLoading = $false
                
                # Publish completion event
                $this.EventBus.Publish('dashboard.load.complete', @{})
            }
        }
        
        # Force UI update
        $this.Invalidate()
    }
    
    [void] OnBoundsChanged() {
        if ($this.MainLayout) {
            $this.MainLayout.SetBounds($this.X, $this.Y, $this.Width, $this.Height)
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::F5) {
                if (-not $this._isLoading) {
                    Write-Host "Refreshing dashboard..."
                    $this.ShowLoadingState()
                    $this.StartSimulatedAsyncLoad()
                }
                return $true
            }
            ([System.ConsoleKey]::Q) {
                # Clean up any active timers
                if ($this._pendingData['timer']) {
                    $this._pendingData['timer'].Stop()
                    $this._pendingData['timer'].Dispose()
                }
                $this.Active = $false
                return $true
            }
        }
        return ([Screen]$this).HandleInput($key)
    }
}

# Initialize and run
Write-Host "Simple Async Dashboard Demo" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This demo shows how background loading with progress indicators" -ForegroundColor Yellow
Write-Host "allows the UI to appear immediately while data loads." -ForegroundColor Yellow
Write-Host ""
Write-Host "Notice how:" -ForegroundColor Green
Write-Host "- The dashboard appears instantly with loading placeholders" -ForegroundColor Green
Write-Host "- Progress bar shows real-time loading status" -ForegroundColor Green
Write-Host "- Data appears progressively as it loads" -ForegroundColor Green
Write-Host "- UI remains responsive during loading" -ForegroundColor Green
Write-Host ""
Write-Host "Press F5 to refresh, Q to quit" -ForegroundColor Cyan
Write-Host ""

# Initialize services
$global:ServiceContainer = [ServiceContainer]::new()
$vt = [VT100]::new()
$global:ServiceContainer.RegisterService('VT100', $vt)

$logger = [Logger]::new("$PSScriptRoot/_Logs/simple-async.log")
$global:ServiceContainer.RegisterService('Logger', $logger)
$global:Logger = $logger

$theme = [ThemeManager]::new()
$theme.LoadTheme('Dark')
$global:ServiceContainer.RegisterService('ThemeManager', $theme)

$eventBus = [EventBus]::new()
$eventBus.Initialize($global:ServiceContainer)
$global:ServiceContainer.RegisterService('EventBus', $eventBus)

# Create and run the dashboard
$screenManager = [ScreenManager]::new()
$screenManager.Initialize($global:ServiceContainer)
$global:ScreenManager = $screenManager

$dashboard = [SimpleAsyncDashboardScreen]::new()
$screenManager.Push($dashboard)
$screenManager.Run()

Write-Host "`nDemo completed!" -ForegroundColor Green