#!/usr/bin/env pwsh
# TaskProPro.ps1 - Professional Task Management Application

param(
    [string]$DataFile = "$PSScriptRoot/Data/tasks.json",
    [switch]$Debug,
    [switch]$Retro
)

# Set debug mode
$global:Debug = $Debug.IsPresent

# Initialize logging
$global:LogFile = "$PSScriptRoot/TaskProPro-$(Get-Date -Format 'yyyy-MM-dd').log"

function Write-DebugLog {
    param([string]$Message, [string]$Level = "DEBUG")
    if ($global:Debug) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $logEntry = "[$timestamp] [$Level] $Message"
        Add-Content -Path $global:LogFile -Value $logEntry -Encoding UTF8
    }
}

# Debug timing
if ($global:Debug) {
    $startTime = Get-Date
    Write-DebugLog "TaskProPro starting at $startTime"
}

# Allow splash screen and startup messages
$ProgressPreference = 'SilentlyContinue'

try {
    # Check if we have an interactive console
    $hasInteractiveConsole = $true
    try {
        $null = [Console]::KeyAvailable
        Write-DebugLog "Interactive console detected successfully"
    } catch {
        $hasInteractiveConsole = $false
        Write-Host "Warning: Non-interactive console detected. TaskProPro requires an interactive terminal." -ForegroundColor Yellow
        Write-Host "Please run TaskProPro from an interactive PowerShell session." -ForegroundColor Yellow
        Write-DebugLog "Non-interactive console detected - exiting"
        exit 1
    }
    
    # CYBERPUNK SPLASH SCREEN
    Clear-Host
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    if ($Retro.IsPresent) {
        Write-Host "║              ★ TASKPROPRO RETRO CYBERPUNK EDITION ★              ║" -ForegroundColor Green  
        Write-Host "║                                                                  ║" -ForegroundColor Green
        Write-Host "║  🚀 INITIALIZING RETRO ASCII TERMINAL INTERFACE...               ║" -ForegroundColor Yellow
    } else {
        Write-Host "║                 ★ TASKPROPRO CYBERPUNK EDITION ★                ║" -ForegroundColor Cyan  
        Write-Host "║                                                                  ║" -ForegroundColor Cyan
        Write-Host "║  🚀 INITIALIZING ENHANCED TERMINAL INTERFACE...                  ║" -ForegroundColor Yellow
    }
    Write-Host "║    • Loading quantum-encrypted task database                     ║" -ForegroundColor Green
    Write-Host "║    • Activating cyberpunk rendering engine                      ║" -ForegroundColor Green
    Write-Host "║    • Establishing neural link protocols                         ║" -ForegroundColor Green
    Write-Host "║                                                                  ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Start-Sleep -Milliseconds 1500
    
    # LOAD PRE-COMPILED ASSEMBLY - ONE SYSTEM ONLY
    Write-Host "Loading Enhanced TaskProPro..." -ForegroundColor Cyan
    
    $dllPath = "$PSScriptRoot/TaskPro.dll"
    
    # Check if DLL exists, build if needed
    if (-not (Test-Path $dllPath)) {
        Write-Host "  TaskPro.dll not found - building..." -ForegroundColor Yellow
        Write-DebugLog "TaskPro.dll missing - running Build-TaskProDll.ps1"
        
        try {
            & "$PSScriptRoot/Build-TaskProDll.ps1"
            if (-not (Test-Path $dllPath)) {
                throw "Build-TaskProDll.ps1 completed but TaskPro.dll was not created"
            }
        }
        catch {
            Write-Host "  ✗ FAILED to build TaskPro.dll: $($_.Exception.Message)" -ForegroundColor Red
            Write-DebugLog "CRITICAL: DLL build failed: $($_.Exception.Message)" "ERROR"
            Write-Host "CRITICAL: Enhanced UI failed to build - TaskProPro cannot continue" -ForegroundColor Red
            exit 1
        }
    }
    
    try {
        Write-DebugLog "Loading pre-compiled TaskPro.dll from: $dllPath"
        
        # Load the pre-compiled assembly - instant, no hanging!
        Add-Type -Path $dllPath
        Write-Host "  ✓ Enhanced UI loaded from DLL!" -ForegroundColor Green
        Write-DebugLog "Pre-compiled assembly loaded successfully"
        
        # Test that enhanced classes are available
        Write-DebugLog "Testing TaskListWidget class creation..."
        $testWidget = [TaskPro.UI.TaskListWidget]::new()
        Write-DebugLog "TaskListWidget created successfully - enhanced UI is active"
    }
    catch {
        Write-Host "  ✗ FAILED to load TaskPro.dll: $($_.Exception.Message)" -ForegroundColor Red
        Write-DebugLog "CRITICAL: DLL loading failed: $($_.Exception.Message)" "ERROR"
        Write-DebugLog "Full error details: $($_.Exception.ToString())" "ERROR"
        
        Write-Host "CRITICAL: Enhanced UI failed to load - TaskProPro cannot continue" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Starting TaskProPro..." -ForegroundColor Cyan
    
    # Initialize data directory
    $dataDir = Split-Path $DataFile -Parent
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
    
    # Initialize components with error handling
    try {
        Write-DebugLog "Creating TaskManager with data file: $DataFile"
        $taskManager = [TaskPro.Data.TaskManager]::new($DataFile)
        Write-DebugLog "TaskManager initialized successfully"
    }
    catch [TaskPro.Core.DataPersistenceException] {
        Write-Host "Data persistence error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Creating new task database..." -ForegroundColor Yellow
        $taskManager = [TaskPro.Data.TaskManager]::new($DataFile)
    }
    catch {
        Write-Host "Failed to initialize TaskManager: $($_.Exception.Message)" -ForegroundColor Red
        throw [TaskPro.Core.TaskProException]::new("TaskManager initialization failed", $_.Exception)
    }
    
    try {
        Write-DebugLog "Creating UI components - ScreenBuffer, TaskListWidget, StatusBar"
        $screen = [TaskPro.Core.ScreenBuffer]::new([Console]::WindowWidth, [Console]::WindowHeight)
        Write-DebugLog "ScreenBuffer created: $([Console]::WindowWidth)x$([Console]::WindowHeight)"
        
        # Use TaskListWidgetRetro as default for now
        $taskListWidget = [TaskPro.UI.TaskListWidgetRetro]::new()
        Write-DebugLog "TaskListWidgetRetro created as DEFAULT - ASCII mode active"
        Write-Host "  ✓ Retro ASCII mode enabled as default!" -ForegroundColor Green
        
        $statusBar = [TaskPro.UI.StatusBar]::new()
        Write-DebugLog "StatusBar created successfully"
        
        # Initialize time tracking components
        Write-DebugLog "Creating TimeTrackingService and TimeTrackingWidget"
        $timeTrackingService = [TaskPro.Data.TimeTrackingService]::new($dataDir)
        $timeTrackingWidget = [TaskPro.UI.TimeTrackingWidget]::new()
        $timeTrackingWidget.Initialize($timeTrackingService, $taskManager)
        $timeTrackingWidget.StatusBar = $statusBar
        Write-DebugLog "Time tracking components initialized with task integration"
    }
    catch {
        throw [TaskPro.Core.RenderingException]::new("Failed to initialize UI components", $_.Exception)
    }
    
    # Configure task list widget
    Write-DebugLog "Configuring task list widget dependencies"
    $taskListWidget.TaskManager = $taskManager
    Write-DebugLog "TaskManager assigned to widget"
    $taskListWidget.StatusBar = $statusBar
    Write-DebugLog "StatusBar assigned to widget"
    $taskListWidget.UpdateDependencies()
    Write-DebugLog "UpdateDependencies called successfully"
    
    # Enable retro features - now default
    if ($taskListWidget -is [TaskPro.UI.TaskListWidgetRetro]) {
        $taskListWidget.ToggleMatrixMode()  # Enable Matrix theme by default
        Write-Host "  ✓ Matrix cyberpunk theme activated!" -ForegroundColor Green
        Write-DebugLog "Retro widget Matrix mode enabled"
    }
    
    $taskListWidget.RefreshTaskList()
    Write-DebugLog "RefreshTaskList completed successfully"
    
    # Create sample data if no tasks exist
    $allTasks = $taskManager.GetAllTasks()
    if ($allTasks.Count -eq 0) {
        Write-Host "Creating sample tasks..." -ForegroundColor Yellow
        
        # Create some CYBERPUNK sample tasks with FULL FIELD SUPPORT
        $task1 = [TaskPro.Data.SimpleTask]::new()
        $task1.Title = "Review project documentation"
        $task1.Priority = [TaskPro.Data.Priority]::High
        $task1.DueDate = [DateTime]::Today.AddDays(2)
        $task1.ID1 = "PRJ001"
        $task1.ID2 = "DOC"
        $task1.Tags.Add("work")
        $task1.Tags.Add("urgent")
        $task1.Notes = "Need to review all API documentation and update examples. Critical for project delivery."
        $taskManager.AddTask($task1)
        
        $task2 = [TaskPro.Data.SimpleTask]::new()
        $task2.Title = "Implement TaskProPro cyberpunk features"
        $task2.Priority = [TaskPro.Data.Priority]::Today
        $task2.DueDate = [DateTime]::Today
        $task2.ID1 = "TPRO"
        $task2.ID2 = "CYBER"
        $task2.Tags.Add("development")
        $task2.Tags.Add("taskpro")
        $task2.Tags.Add("cyberpunk")
        $task2.Notes = "Complete the professional task management implementation with cyberpunk aesthetic."
        $taskManager.AddTask($task2)
        
        $task3 = [TaskPro.Data.SimpleTask]::new()
        $task3.Title = "Weekly planning session"
        $task3.Priority = [TaskPro.Data.Priority]::Medium
        $task3.DueDate = [DateTime]::Today.AddDays(7)
        $task3.ID1 = "PLAN"
        $task3.ID2 = "WEEK"
        $task3.Tags.Add("personal")
        $task3.Tags.Add("planning")
        $task3.Notes = "Plan tasks and priorities for the upcoming week. Review completed tasks."
        $taskManager.AddTask($task3)
        
        # Add a completed task to show cyberpunk completion styling
        $task4 = [TaskPro.Data.SimpleTask]::new()
        $task4.Title = "Set up TaskProPro environment"
        $task4.Priority = [TaskPro.Data.Priority]::High
        $task4.DueDate = [DateTime]::Today.AddDays(-1)
        $task4.ID1 = "SETUP"
        $task4.ID2 = "ENV"
        $task4.Tags.Add("development")
        $task4.Tags.Add("completed")
        $task4.Notes = "Development environment is now configured and ready."
        $task4.Completed = $true
        $taskManager.AddTask($task4)
        
        Write-Host "Sample tasks created!" -ForegroundColor Green
        # Retro mode is now default
        Write-Host "RETRO MODE: Arrow keys=Navigate, Enter=Notes, N=New Task, Space=Complete" -ForegroundColor Yellow
        Write-Host "Cyberpunk: Ctrl+M=Matrix Theme, Ctrl+B=BladeRunner, Ctrl+G=Glitch, Ctrl+S=Scanlines" -ForegroundColor Green
        Write-Host "Time Tracking: F1=Switch to Time Tracking Mode" -ForegroundColor Cyan
        $statusBar.ShowSuccess("RETRO MODE DEFAULT! Matrix theme enabled. Fixed columns with field highlights.")
    } else {
        # Retro mode is now default
        $statusBar.ShowMessage("RETRO CYBERPUNK MODE - $(($allTasks | Where-Object { -not $_.Completed }).Count) active tasks loaded into neural matrix")
    }
    
    # Initialize filter
    $currentFilter = [TaskPro.Data.FilterCriteria]::new()
    $taskListWidget.CurrentFilter = $currentFilter
    
    # Application mode state - Tasks or Time Tracking
    $currentMode = "Tasks"  # "Tasks" or "TimeTracking"
    
    # Hide cursor and clear screen
    [Console]::CursorVisible = $false
    Clear-Host
    
    # Main application loop
    $running = $true
    $lastWindowSize = @{ Width = [Console]::WindowWidth; Height = [Console]::WindowHeight }
    
    while ($running) {
        try {
            # Check for window resize with error handling
            try {
                $currentSize = @{ Width = [Console]::WindowWidth; Height = [Console]::WindowHeight }
                
                # Enforce minimum window size for cyberpunk UI
                if ($currentSize.Width -lt 40 -or $currentSize.Height -lt 10) {
                    $screen.WriteAt(0, 0, "Terminal too small! Need 40x10 minimum", [ConsoleColor]::Red)
                    Start-Sleep -Milliseconds 100
                    continue
                }
                
                if ($currentSize.Width -ne $lastWindowSize.Width -or $currentSize.Height -ne $lastWindowSize.Height) {
                    $screen = [TaskPro.Core.ScreenBuffer]::new($currentSize.Width, $currentSize.Height)
                    $lastWindowSize = $currentSize
                    if ($global:Debug) {
                        Write-Host "Window resized to $($currentSize.Width)x$($currentSize.Height)" -ForegroundColor Yellow
                    }
                }
            }
            catch {
                if ($global:Debug) {
                    Write-Host "Window resize error (continuing): $($_.Exception.Message)" -ForegroundColor Yellow
                }
                # Continue with current screen size
            }
            
            # Rendering with error recovery
            try {
                # Begin frame
                $screen.BeginFrame()
                
                if ($currentMode -eq "Tasks") {
                    # UNIFIED TASK MANAGEMENT MODE - Full screen control to TaskListWidget
                    
                    # Update current filter
                    $taskListWidget.CurrentFilter = $currentFilter
                    
                    # UNIFIED RENDERING - TaskListWidget handles everything
                    $fullRect = [TaskPro.Core.Rectangle]::new(0, 0, $screen.Width, $screen.Height)
                    $taskListWidget.Render($screen, $fullRect)
                    
                } else {
                    # TIME TRACKING MODE
                    
                    # Use full screen for time tracking widget
                    $fullRect = [TaskPro.Core.Rectangle]::new(0, 0, $screen.Width, $screen.Height)
                    $timeTrackingWidget.Render($screen, $fullRect)
                    
                    # Add mode indicator in header area
                    $screen.WriteAt($screen.Width - 20, 1, "[F1:TASK_MGMT]", [ConsoleColor]::Green)
                }
                
                # End frame - single write, zero flicker!
                $screen.EndFrame()
            }
            catch {
                # NO FALLBACK - Enhanced system must work or exit
                Write-Host "Enhanced UI failed: $($_.Exception.Message)" -ForegroundColor Red
                $running = $false
                throw
            }
            
            # Handle input with error handling
            try {
                $hasInput = $false
                try {
                    $hasInput = [TaskPro.Core.InputManager]::IsInputAvailable()
                } catch {
                    # Console input not available - skip input handling this frame
                    if ($global:Debug) {
                        Write-Host "Input check failed (continuing): $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                    $hasInput = $false
                }
                
                if ($hasInput) {
                    try {
                        $input = [TaskPro.Core.InputManager]::ReadInput()
                        
                        # Global shortcuts
                        if ($input.IsCtrlQ) {
                            $running = $false
                            continue
                        }
                        
                        # Mode switching shortcuts
                        if ($input.Key -eq [ConsoleKey]::F1) {
                            # Switch between Tasks and TimeTracking modes
                            if ($currentMode -eq "Tasks") {
                                $currentMode = "TimeTracking"
                                $statusBar.ShowSuccess("Switched to Time Tracking mode")
                            } else {
                                $currentMode = "Tasks"
                                $statusBar.ShowSuccess("Switched to Task Management mode")
                            }
                            continue
                        }
                        
                        if ($input.IsCtrlR) {
                            # Refresh current mode
                            if ($currentMode -eq "Tasks") {
                                $taskListWidget.RefreshTaskList()
                                $statusBar.ShowSuccess("Task list refreshed")
                            } else {
                                $timeTrackingWidget.RefreshList()
                                $statusBar.ShowSuccess("Time entries refreshed")
                            }
                            if ($global:Debug) {
                                Write-Host "Data refreshed for $currentMode mode" -ForegroundColor Green
                            }
                            continue
                        }
                        
                        # Route input to appropriate widget based on current mode
                        if ($currentMode -eq "Tasks") {
                            $null = $taskListWidget.HandleInput($input)
                        } else {
                            $null = $timeTrackingWidget.HandleInput($input)
                        }
                    }
                    catch [TaskPro.Core.InputHandlingException] {
                        if ($global:Debug) {
                            Write-Host "Input handling error (ignoring): $($_.Exception.Message)" -ForegroundColor Yellow
                        }
                        # Ignore invalid inputs and continue
                    }
                    catch {
                        if ($global:Debug) {
                            Write-Host "Unexpected input error: $($_.Exception.Message)" -ForegroundColor Red
                        }
                        # Log but continue - don't crash on input errors
                    }
                }
            }
            catch {
                if ($global:Debug) {
                    Write-Host "Input subsystem error: $($_.Exception.Message)" -ForegroundColor Red
                }
                # Continue without input for this frame
            }
            
            # 60 FPS refresh rate
            Start-Sleep -Milliseconds 16
            
        } catch [TaskPro.Core.TaskProException] {
            # TaskProPro specific errors - try to recover or exit gracefully
            Write-Host "TaskProPro Error: $($_.Exception.Message)" -ForegroundColor Red
            if ($global:Debug) {
                Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
            }
            $running = $false
        } catch {
            # Unexpected errors - exit immediately
            Write-Host "Unexpected system error: $($_.Exception.Message)" -ForegroundColor Red
            if ($global:Debug) {
                Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
            }
            $running = $false
            throw
        }
    }
    
} catch [TaskPro.Core.TaskProException] {
    Write-Host "TaskProPro Application Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($global:Debug) {
        Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
        Write-Host "Inner Exception: $($_.Exception.InnerException?.Message)" -ForegroundColor DarkRed
    }
    exit 1
} catch [TaskPro.Core.DataPersistenceException] {
    Write-Host "Data Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Your task data may not have been saved properly." -ForegroundColor Yellow
    Write-Host "Check the backup files in the Data/backups directory." -ForegroundColor Yellow
    if ($global:Debug) {
        Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
    }
    exit 2
} catch [TaskPro.Core.RenderingException] {
    Write-Host "Display Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Try resizing your terminal window or running with -Debug for details." -ForegroundColor Yellow
    if ($global:Debug) {
        Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
    }
    exit 3
} catch {
    Write-Host "Unexpected Error: $_" -ForegroundColor Red
    Write-Host "This may be a system or PowerShell compatibility issue." -ForegroundColor Yellow
    if ($global:Debug) {
        Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
        Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor DarkRed
    }
    exit 99
} finally {
    # Cleanup with error handling
    try {
        [Console]::CursorVisible = $true
        Clear-Host
    }
    catch {
        # Even cleanup failed - just write to console
        if ($global:Debug) {
            Write-Host "Cleanup error: $($_.Exception.Message)" -ForegroundColor DarkRed
        }
    }
    
    Write-Host ""
    Write-Host "TaskProPro session ended." -ForegroundColor Green
    Write-Host "Your tasks have been saved automatically." -ForegroundColor Gray
    
    # Performance stats in debug mode
    if ($global:Debug) {
        $endTime = Get-Date
        $duration = $endTime - $startTime
        Write-Host "Debug: Session ended at $endTime" -ForegroundColor DarkGray
        Write-Host "Debug: Total session duration: $($duration.TotalSeconds.ToString('F2')) seconds" -ForegroundColor DarkGray
    }
}
