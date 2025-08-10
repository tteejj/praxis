# SimpleTaskProApp.ps1 - Main application class

class SimpleTaskProApp {
    [TaskListScreen]$TaskScreen
    [CommandLibraryScreen]$CommandScreen
    [ExcelMappingScreen]$ExcelScreen
    [object]$Screen  # Current active screen
    [string]$CurrentMode = "Tasks"  # "Tasks", "Commands", or "Excel"
    [bool]$Running = $true
    hidden [datetime]$_lastActivityTime = [datetime]::Now
    hidden [bool]$_hasFocus = $true
    
    SimpleTaskProApp() {
        "DEBUG: Creating TaskScreen... $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        $this.TaskScreen = [TaskListScreen]::new()
        "DEBUG: Creating CommandScreen... $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        $this.CommandScreen = [CommandLibraryScreen]::new()
        "DEBUG: Creating ExcelScreen... $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        $this.ExcelScreen = [ExcelMappingScreen]::new()
        "DEBUG: Setting initial screen... $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        $this.Screen = $this.TaskScreen  # Start with task screen
        
        # Give screens access to app reference for mode switching
        $this.TaskScreen.SetAppReference($this)
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
    
    # MODE SWITCHING
    [void] SwitchToTimeEntry() {
        try {
            # Only TaskScreen has time entry mode
            if ($this.CurrentMode -eq "Tasks") {
                $this.TaskScreen.SwitchToTimeEntryMode()
            }
        } catch {
            Write-Host "`nError switching to time entry mode: $_" -ForegroundColor Red
            if ($global:Debug) {
                Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
            }
        }
    }
    
    [void] SwitchToTasks() {
        if ($this.CurrentMode -eq "Tasks") {
            $this.TaskScreen.SwitchToTaskMode()
        } else {
            # Switch from other screens back to Tasks
            $this.CurrentMode = "Tasks"
            $this.Screen = $this.TaskScreen
        }
    }
    
    [void] SwitchToCommands() {
        $this.CurrentMode = "Commands"
        $this.Screen = $this.CommandScreen
    }
    
    [void] SwitchToExcel() {
        try {
            "DEBUG: SwitchToExcel START $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            "DEBUG: Current mode before: $($this.CurrentMode)" | Out-File -FilePath "./startup-debug.log" -Append
            "DEBUG: ExcelScreen object exists: $($this.ExcelScreen -ne $null)" | Out-File -FilePath "./startup-debug.log" -Append
            
            $this.CurrentMode = "Excel"
            "DEBUG: CurrentMode set to Excel $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            
            "DEBUG: About to set Screen property $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            $this.Screen = $this.ExcelScreen
            "DEBUG: Screen property set to ExcelScreen $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            
            "DEBUG: About to call Initialize $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            $width = [Console]::WindowWidth
            $height = [Console]::WindowHeight
            "DEBUG: Console dimensions: ${width}x${height}" | Out-File -FilePath "./startup-debug.log" -Append
            
            $this.Screen.Initialize($width, $height)
            "DEBUG: Initialize completed $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            
            "DEBUG: SwitchToExcel COMPLETED $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        } catch {
            "DEBUG: SwitchToExcel EXCEPTION: $_ $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            "DEBUG: Exception type: $($_.Exception.GetType().FullName)" | Out-File -FilePath "./startup-debug.log" -Append
            "DEBUG: Stack trace: $($_.ScriptStackTrace)" | Out-File -FilePath "./startup-debug.log" -Append
            # Fall back to tasks
            $this.CurrentMode = "Tasks"
            $this.Screen = $this.TaskScreen
            throw
        }
    }
    
    [void] Run() {
        try {
            # Initialize screen
            $width = [Console]::WindowWidth
            $height = [Console]::WindowHeight
            $this.Screen.Initialize($width, $height)
            
            # Initial render
            Write-Host -NoNewline $this.Screen.Render()
            
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
                            if (-not $this.Screen.HandleInput($key)) {
                                $this.Running = $false
                            }
                        }
                        
                        Write-Host -NoNewline $this.Screen.Render()
                    } else {
                        Start-Sleep -Milliseconds 50
                    }
                    
                    # Check window resize
                    if ([Console]::WindowWidth -ne $width -or [Console]::WindowHeight -ne $height) {
                        $width = [Console]::WindowWidth
                        $height = [Console]::WindowHeight
                        $this.Screen.Initialize($width, $height)
                        Write-Host -NoNewline $this.Screen.Render()
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