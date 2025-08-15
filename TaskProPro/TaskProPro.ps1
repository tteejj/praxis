#!/usr/bin/env pwsh
# TaskProPro.ps1 - Professional Task Management Application

param(
    [string]$DataFile = "$PSScriptRoot/Data/tasks.json",
    [switch]$Debug
)

# Set debug mode
$global:Debug = $Debug.IsPresent

# Debug timing
if ($global:Debug) {
    $startTime = Get-Date
    Write-Host "Debug: TaskProPro starting at $startTime" -ForegroundColor DarkGray
}

try {
    # Check if we have an interactive console
    $hasInteractiveConsole = $true
    try {
        $null = [Console]::KeyAvailable
    } catch {
        $hasInteractiveConsole = $false
        Write-Host "Warning: Non-interactive console detected. TaskProPro requires an interactive terminal." -ForegroundColor Yellow
        Write-Host "Please run TaskProPro from an interactive PowerShell session." -ForegroundColor Yellow
        exit 1
    }
    
    # Load professional TUI foundation
    . "$PSScriptRoot/Load-TaskProPro.ps1"
    
    Write-Host "Starting TaskProPro..." -ForegroundColor Cyan
    
    # Initialize data directory
    $dataDir = Split-Path $DataFile -Parent
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
    
    # Initialize components with error handling
    try {
        $taskManager = [TaskPro.Data.TaskManager]::new($DataFile)
        if ($global:Debug) {
            Write-Host "TaskManager initialized successfully" -ForegroundColor Green
        }
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
        $screen = [TaskPro.Core.ScreenBuffer]::new([Console]::WindowWidth, [Console]::WindowHeight)
        $taskListWidget = [TaskPro.UI.TaskListWidget]::new()
        $statusBar = [TaskPro.UI.StatusBar]::new()
    }
    catch {
        throw [TaskPro.Core.RenderingException]::new("Failed to initialize UI components", $_.Exception)
    }
    
    # Configure task list widget
    $taskListWidget.TaskManager = $taskManager
    $taskListWidget.ShowPillboxSelection = $true
    $taskListWidget.StatusBar = $statusBar
    $taskListWidget.RefreshList($true)
    
    # Create sample data if no tasks exist
    $allTasks = $taskManager.GetAllTasks()
    if ($allTasks.Count -eq 0) {
        Write-Host "Creating sample tasks..." -ForegroundColor Yellow
        
        # Create some sample tasks for demonstration
        $task1 = [TaskPro.Data.SimpleTask]::new()
        $task1.Title = "Review project documentation"
        $task1.Priority = [TaskPro.Data.Priority]::High
        $task1.DueDate = [DateTime]::Today.AddDays(2)
        $task1.Tags.Add("work")
        $task1.Tags.Add("urgent")
        $task1.Notes = "Need to review all API documentation and update examples."
        $taskManager.AddTask($task1)
        
        $task2 = [TaskPro.Data.SimpleTask]::new()
        $task2.Title = "Implement TaskProPro features"
        $task2.Priority = [TaskPro.Data.Priority]::Today
        $task2.DueDate = [DateTime]::Today
        $task2.Tags.Add("development")
        $task2.Tags.Add("taskpro")
        $task2.Notes = "Complete the professional task management implementation."
        $taskManager.AddTask($task2)
        
        $task3 = [TaskPro.Data.SimpleTask]::new()
        $task3.Title = "Weekly planning session"
        $task3.Priority = [TaskPro.Data.Priority]::Medium
        $task3.DueDate = [DateTime]::Today.AddDays(7)
        $task3.Tags.Add("personal")
        $task3.Tags.Add("planning")
        $task3.Notes = "Plan tasks and priorities for the upcoming week."
        $taskManager.AddTask($task3)
        
        Write-Host "Sample tasks created!" -ForegroundColor Green
        $statusBar.ShowSuccess("Welcome! Sample tasks created")
    } else {
        $statusBar.ShowMessage("TaskProPro ready - $(($allTasks | Where-Object { -not $_.Completed }).Count) active tasks")
    }
    
    # Initialize filter
    $currentFilter = [TaskPro.Data.FilterCriteria]::new()
    $taskListWidget.CurrentFilter = $currentFilter
    
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
                
                # Header
                $headerText = "TaskProPro - Professional Task Manager"
                $filterText = $currentFilter.GetDisplayText()
                if ($filterText -ne "All") {
                    $headerText += " | Filter: $filterText"
                }
                $screen.WriteAt(0, 0, $headerText, [ConsoleColor]::Cyan)
                
                # Task count info
                $taskCount = $taskListWidget.TotalItems
                $selectedInfo = if ($taskCount -gt 0) { "Selected: $($taskListWidget.SelectedIndex + 1)/$taskCount" } else { "No tasks" }
                $screen.WriteAt(0, 1, $selectedInfo, [ConsoleColor]::DarkGray)
                
                # Separator
                $screen.WriteAt(0, 2, "─" * $screen.Width, [ConsoleColor]::DarkGray)
                
                # Task list widget rendering (leave more room for enhanced status bar)
                $listRect = [TaskPro.Core.Rectangle]::new(0, 3, $screen.Width, $screen.Height - 6)
                $taskListWidget.Render($screen, $listRect)
                
                # Professional status bar with adaptive layout
                $statusY = $screen.Height - 3
                $statusRect = [TaskPro.Core.Rectangle]::new(0, $statusY, $screen.Width, 2)
                
                # Build status information
                $statusInfo = [TaskPro.UI.StatusInfo]::new()
                $statusInfo.TaskCount = $taskListWidget.TotalItems
                $statusInfo.SelectedIndex = if ($taskListWidget.TotalItems -gt 0) { $taskListWidget.SelectedIndex } else { 0 }
                $statusInfo.FilterText = $currentFilter.GetDisplayText()
                
                # Count completed tasks and check for due tasks
                $allTasks = $taskManager.GetAllTasks()
                $statusInfo.CompletedCount = ($allTasks | Where-Object { $_.Completed }).Count
                $today = [DateTime]::Today
                $statusInfo.HasDueTasks = ($allTasks | Where-Object { 
                    $_.DueDate -ne [DateTime]::MinValue -and $_.DueDate.Date -le $today -and -not $_.Completed 
                }).Count -gt 0
                
                $statusBar.Render($screen, $statusRect, $statusInfo)
                
                # End frame - single write, zero flicker!
                $screen.EndFrame()
            }
            catch [TaskPro.Core.RenderingException] {
                if ($global:Debug) {
                    Write-Host "Rendering error (recovering): $($_.Exception.Message)" -ForegroundColor Red
                }
                # Clear screen and try basic recovery
                try {
                    Clear-Host
                    Write-Host "TaskProPro - Rendering Error Recovery Mode" -ForegroundColor Red
                    Write-Host "Press Ctrl+Q to quit" -ForegroundColor Yellow
                }
                catch {
                    # Even recovery failed - bail out
                    $running = $false
                    throw [TaskPro.Core.RenderingException]::new("Critical rendering failure", $_.Exception)
                }
            }
            catch {
                if ($global:Debug) {
                    Write-Host "Unexpected rendering error: $($_.Exception.Message)" -ForegroundColor Red
                }
                throw [TaskPro.Core.RenderingException]::new("Rendering subsystem error", $_.Exception)
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
                        
                        if ($input.IsCtrlR) {
                            # Refresh task list
                            $taskListWidget.RefreshList($true)
                            $statusBar.ShowSuccess("Task list refreshed")
                            if ($global:Debug) {
                                Write-Host "Task list refreshed" -ForegroundColor Green
                            }
                            continue
                        }
                        
                        # Route input to task list widget
                        $taskListWidget.HandleInput($input)
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
