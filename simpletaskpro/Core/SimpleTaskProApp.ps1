# SimpleTaskProApp.ps1 - Main application class

class SimpleTaskProApp {
    [TaskListScreen]$Screen
    [bool]$Running = $true
    hidden [datetime]$_lastActivityTime = [datetime]::Now
    hidden [bool]$_hasFocus = $true
    
    SimpleTaskProApp() {
        $this.Screen = [TaskListScreen]::new()
        
        # Give screen access to app reference for F4 toggle
        $this.Screen.SetAppReference($this)
        
        # Register shutdown handler for crash recovery
        Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
            # This ensures auto-save on any exit
            if ($global:CurrentEditor) {
                $global:CurrentEditor.OnExit()
            }
        } | Out-Null
    }
    
    # TIME ENTRY MODE SWITCHING
    [void] SwitchToTimeEntry() {
        try {
            $this.Screen.SwitchToTimeEntryMode()
        } catch {
            Write-Host "`nError switching to time entry mode: $_" -ForegroundColor Red
            if ($global:Debug) {
                Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
            }
        }
    }
    
    [void] SwitchToTasks() {
        $this.Screen.SwitchToTaskMode()
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
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    $this._lastActivityTime = [datetime]::Now
                    
                    if (-not $this.Screen.HandleInput($key)) {
                        $this.Running = $false
                    } else {
                        Write-Host -NoNewline $this.Screen.Render()
                    }
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