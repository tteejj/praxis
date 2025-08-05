# TaskProApp.ps1 - Main application class

class TaskProApp {
    [TaskScreen]$Screen
    [bool]$Running = $true
    [System.Diagnostics.Stopwatch]$FrameTimer
    [int]$FrameTime = 16  # ~60 FPS
    
    TaskProApp() {
        $this.Screen = [TaskScreen]::new()
        $this.FrameTimer = [System.Diagnostics.Stopwatch]::new()
    }
    
    [void] Run() {
        try {
            # Initialize screen with console dimensions
            $width = [Console]::WindowWidth
            $height = [Console]::WindowHeight
            $this.Screen.Initialize($width, $height)
            
            # Initial render
            $this.Render()
            
            # Main loop
            while ($this.Running) {
                $this.FrameTimer.Restart()
                
                # Check for input (non-blocking)
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    
                    # Handle input
                    if (-not $this.Screen.HandleInput($key)) {
                        $this.Running = $false
                    } else {
                        $this.Render()
                    }
                }
                
                # Check if window was resized
                if ([Console]::WindowWidth -ne $width -or [Console]::WindowHeight -ne $height) {
                    $width = [Console]::WindowWidth
                    $height = [Console]::WindowHeight
                    $this.Screen.Initialize($width, $height)
                    $this.Render()
                }
                
                # Frame rate limiting
                $elapsed = $this.FrameTimer.ElapsedMilliseconds
                if ($elapsed -lt $this.FrameTime) {
                    Start-Sleep -Milliseconds ($this.FrameTime - $elapsed)
                }
            }
        } catch {
            Write-Host "`nError: $_" -ForegroundColor Red
            if ($global:Debug) {
                Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
            }
        } finally {
            $this.Cleanup()
        }
    }
    
    [void] Render() {
        try {
            $output = $this.Screen.Render()
            [Console]::Write($output)
        } catch {
            Write-Host "`nRender error: $_" -ForegroundColor Red
            if ($global:Debug) {
                Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
            }
        }
    }
    
    [void] Cleanup() {
        # Save any pending changes
        $this.Screen.SaveCurrentTask()
        
        # Reset console
        [Console]::CursorVisible = $true
        [Console]::Clear()
        
        # Show exit message
        Write-Host "TaskPro closed. Your tasks have been saved." -ForegroundColor Green
    }
}