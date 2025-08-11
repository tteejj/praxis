# SimpleTaskProApp.ps1 - Main application class with EventBus and Screen Stack

class SimpleTaskProApp {
    [TaskListScreen]$TaskScreen
    [TimeEntryScreen]$TimeScreen
    [CommandLibraryScreen]$CommandScreen
    [ExcelMappingScreen]$ExcelScreen
    
    # NEW: Screen Stack Management
    [System.Collections.Generic.Stack[object]]$ScreenStack
    [object]$CurrentScreen  # Current active screen (top of stack)
    
    [string]$CurrentMode = "Tasks"  # "Tasks", "Commands", or "Excel" - for compatibility
    [bool]$Running = $true
    hidden [datetime]$_lastActivityTime = [datetime]::Now
    hidden [bool]$_hasFocus = $true
    
    SimpleTaskProApp() {
        # Initialize screen stack
        $this.ScreenStack = [System.Collections.Generic.Stack[object]]::new()
        
        "DEBUG: Creating TaskScreen... $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        $this.TaskScreen = [TaskListScreen]::new()
        "DEBUG: Creating TimeScreen... $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        $this.TimeScreen = [TimeEntryScreen]::new()
        "DEBUG: Creating CommandScreen... $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        $this.CommandScreen = [CommandLibraryScreen]::new()
        "DEBUG: Creating ExcelScreen... $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        $this.ExcelScreen = [ExcelMappingScreen]::new()
        
        "DEBUG: Setting up EventBus subscriptions... $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        $this.SetupEventBusSubscriptions()
        
        "DEBUG: Pushing initial TaskScreen to stack... $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        $this.ScreenStack.Push($this.TaskScreen)
        $this.CurrentScreen = $this.TaskScreen
        
        # Give screens access to app reference for mode switching (legacy compatibility)
        $this.TaskScreen.SetAppReference($this)
        $this.TimeScreen.SetAppReference($this)
        $this.CommandScreen.SetAppReference($this)
        # ExcelMappingScreen doesn't need app reference (inherits from BaseListScreen)
        
        # Register shutdown handler for crash recovery
        Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
            # This ensures auto-save on any exit
            if ($global:CurrentEditor) {
                $global:CurrentEditor.OnExit()
            }
        } | Out-Null
    }
    
    # NEW: Setup EventBus subscriptions for navigation
    [void] SetupEventBusSubscriptions() {
        # Navigation events - using object method references (PowerShell-safe)
        [EventBus]::Subscribe("NavigateTo", $this, "NavigateToScreen")
        [EventBus]::Subscribe("NavigateBack", $this, "NavigateBack") 
        [EventBus]::Subscribe("ApplicationExit", $this, "HandleApplicationExit")
        
        if ($global:Debug) {
            Write-Host "EventBus subscriptions setup complete" -ForegroundColor Green
        }
    }
    
    # NEW: Navigate to a screen by name
    [void] NavigateToScreen([string]$screenName) {
        try {
            $targetScreen = $null
            
            switch ($screenName.ToLower()) {
                "tasks" { 
                    $targetScreen = $this.TaskScreen
                    $this.CurrentMode = "Tasks"
                }
                "timeentry" { 
                    $targetScreen = $this.TimeScreen
                    $this.CurrentMode = "TimeEntry"
                }
                "commands" { 
                    $targetScreen = $this.CommandScreen
                    $this.CurrentMode = "Commands"
                }
                "excel" { 
                    $targetScreen = $this.ExcelScreen
                    $this.CurrentMode = "Excel"
                }
                default {
                    Write-Host "Unknown screen: $screenName" -ForegroundColor Red
                    return
                }
            }
            
            if ($targetScreen) {
                $this.ScreenStack.Push($targetScreen)
                $this.CurrentScreen = $targetScreen
                
                # Initialize the screen
                $width = [Console]::WindowWidth
                $height = [Console]::WindowHeight
                $targetScreen.Initialize($width, $height)
                
                if ($global:Debug) {
                    Write-Host "Navigated to: $screenName (Stack depth: $($this.ScreenStack.Count))" -ForegroundColor Cyan
                }
            }
        } catch {
            Write-Host "Error navigating to $screenName : $_" -ForegroundColor Red
            if ($global:Debug) {
                Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
            }
        }
    }
    
    # NEW: Navigate back to previous screen
    [void] NavigateBack() {
        try {
            if ($this.ScreenStack.Count -gt 1) {
                # Pop current screen
                $this.ScreenStack.Pop()
                
                # Set previous screen as current
                $this.CurrentScreen = $this.ScreenStack.Peek()
                
                # Update mode based on screen type
                if ($this.CurrentScreen -is [TaskListScreen]) {
                    $this.CurrentMode = "Tasks"
                } elseif ($this.CurrentScreen -is [TimeEntryScreen]) {
                    $this.CurrentMode = "TimeEntry"
                } elseif ($this.CurrentScreen -is [CommandLibraryScreen]) {
                    $this.CurrentMode = "Commands" 
                } elseif ($this.CurrentScreen -is [ExcelMappingScreen]) {
                    $this.CurrentMode = "Excel"
                }
                
                if ($global:Debug) {
                    Write-Host "Navigated back (Stack depth: $($this.ScreenStack.Count))" -ForegroundColor Cyan
                }
            } else {
                # Can't navigate back from base screen - exit application
                [EventBus]::Publish("ApplicationExit")
            }
        } catch {
            Write-Host "Error navigating back: $_" -ForegroundColor Red
            if ($global:Debug) {
                Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
            }
        }
    }
    
    # EventBus callback methods
    [void] HandleApplicationExit() {
        $this.Running = $false
    }
    
    # MODE SWITCHING
    [void] SwitchToTimeEntry() {
        [EventBus]::Publish("NavigateTo", "timeentry")
    }
    
    [void] SwitchToTasks() {
        [EventBus]::Publish("NavigateTo", "tasks")
    }
    
    [void] SwitchToCommands() {
        [EventBus]::Publish("NavigateTo", "commands")
    }
    
    [void] SwitchToExcel() {
        try {
            "DEBUG: SwitchToExcel using EventBus $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            [EventBus]::Publish("NavigateTo", "excel")
            "DEBUG: SwitchToExcel COMPLETED $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        } catch {
            "DEBUG: SwitchToExcel EXCEPTION: $_ $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            # Fall back to tasks using EventBus
            [EventBus]::Publish("NavigateTo", "tasks")
            throw
        }
    }
    
    [void] Run() {
        try {
            # Initialize current screen (already set in constructor)
            $width = [Console]::WindowWidth
            $height = [Console]::WindowHeight
            $this.CurrentScreen.Initialize($width, $height)
            
            # Initial render
            Write-Host -NoNewline $this.CurrentScreen.Render()
            
            # Main loop
            while ($this.Running) {
                try {
                    if ([Console]::KeyAvailable) {
                        $key = [Console]::ReadKey($true)
                        $this._lastActivityTime = [datetime]::Now
                        
                        # Debug: Log key presses for F6 specifically
                        if ($key.Key -eq [System.ConsoleKey]::F6) {
                            "DEBUG: F6 detected in main loop $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
                        }
                        
                        # Handle global screen switching first
                        $handled = $false
                        switch ($key.Key) {
                            ([System.ConsoleKey]::F6) {
                                if ($this.CurrentMode -ne "Excel") {
                                    $this.SwitchToExcel()
                                    $handled = $true
                                }
                            }
                            ([System.ConsoleKey]::F10) {
                                if ($this.CurrentMode -ne "Tasks") {
                                    $this.SwitchToTasks()
                                    $handled = $true
                                }
                            }
                            ([System.ConsoleKey]::F5) {
                                if ($this.CurrentMode -ne "Commands") {
                                    $this.SwitchToCommands()
                                    $handled = $true
                                }
                            }
                        }
                        
                        # If not handled globally, let screen handle it
                        if (-not $handled) {
                            if (-not $this.CurrentScreen.HandleInput($key)) {
                                # Check if this was an exit request or navigation back
                                if ($this.ScreenStack.Count -gt 1) {
                                    $this.NavigateBack()
                                } else {
                                    $this.Running = $false
                                }
                            }
                        }
                        
                        Write-Host -NoNewline $this.CurrentScreen.Render()
                    } else {
                        Start-Sleep -Milliseconds 50
                    }
                    
                    # Check window resize
                    if ([Console]::WindowWidth -ne $width -or [Console]::WindowHeight -ne $height) {
                        $width = [Console]::WindowWidth
                        $height = [Console]::WindowHeight
                        $this.CurrentScreen.Initialize($width, $height)
                        Write-Host -NoNewline $this.CurrentScreen.Render()
                    }
                    
                    # Detect focus loss (no activity for 30 seconds)
                    if (([datetime]::Now - $this._lastActivityTime).TotalSeconds -gt 30) {
                        if ($this._hasFocus) {
                            $this._hasFocus = $false
                            # Notify editor of focus loss
                            if ($global:CurrentEditor) {
                                $global:CurrentEditor.OnFocusLost()
                            }
                        }
                    } else {
                        $this._hasFocus = $true
                    }
                    
                    Start-Sleep -Milliseconds 50
                } catch {
                    Write-Host "`nConsole error: $_" -ForegroundColor Red
                    $this.Running = $false
                }
            }
        } catch {
            Write-Host "`nError: $_" -ForegroundColor Red
            if ($global:Debug) {
                Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
            }
        } finally {
            [Console]::CursorVisible = $true
            [Console]::Clear()
            Write-Host "TaskPro closed." -ForegroundColor Green
        }
    }
}