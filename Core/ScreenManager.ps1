# ScreenManager.ps1 - Manages screen lifecycle and rendering
# Optimized for minimal overhead

class ScreenManager {
    hidden [System.Collections.Generic.Stack[Screen]]$_screenStack
    hidden [Screen]$_activeScreen = $null
    hidden [bool]$_needsRender = $true
    hidden [System.ConsoleKeyInfo]$_lastKey
    hidden [ServiceContainer]$_services
    
    # Performance tracking
    hidden [System.Diagnostics.Stopwatch]$_renderTimer
    hidden [int]$_frameCount = 0
    hidden [double]$_lastFPS = 0
    
    ScreenManager([ServiceContainer]$services) {
        $this._screenStack = [System.Collections.Generic.Stack[Screen]]::new()
        $this._services = $services
        $this._renderTimer = [System.Diagnostics.Stopwatch]::new()
    }
    
    # Push a new screen
    [void] Push([Screen]$screen) {
        # Deactivate current
        if ($this._activeScreen) {
            $this._activeScreen.Active = $false
            $this._activeScreen.OnDeactivated()
        }
        
        # Initialize and activate new screen
        $screen.Initialize($this._services)
        $screen.SetBounds(0, 0, [Console]::WindowWidth, [Console]::WindowHeight)
        
        $this._screenStack.Push($screen)
        $this._activeScreen = $screen
        $this._activeScreen.Active = $true
        $this._activeScreen.OnActivated()
        
        $this._needsRender = $true
    }
    
    # Pop current screen
    [Screen] Pop() {
        if ($this._screenStack.Count -eq 0) { return $null }
        
        $popped = $this._screenStack.Pop()
        $popped.Active = $false
        $popped.OnDeactivated()
        
        # Activate previous screen if any
        if ($this._screenStack.Count -gt 0) {
            $this._activeScreen = $this._screenStack.Peek()
            $this._activeScreen.Active = $true
            $this._activeScreen.OnActivated()
        } else {
            $this._activeScreen = $null
        }
        
        $this._needsRender = $true
        return $popped
    }
    
    # Replace current screen
    [void] Replace([Screen]$screen) {
        if ($this._screenStack.Count -gt 0) {
            $this.Pop() | Out-Null
        }
        $this.Push($screen)
    }
    
    # Get active screen
    [Screen] GetActiveScreen() {
        return $this._activeScreen
    }
    
    # Main run loop
    [void] Run() {
        # Initial setup
        [Console]::CursorVisible = $false
        [Console]::Clear()
        
        if ($global:Logger) {
            $global:Logger.Info("ScreenManager.Run: Starting main loop")
            $global:Logger.Info("Active screen: $($this._activeScreen.GetType().Name)")
            $global:Logger.Info("Active screen.Active: $($this._activeScreen.Active)")
            $global:Logger.Flush()
        }
        
        try {
            while ($this._activeScreen -and $this._activeScreen.Active) {
                if ($global:Logger) {
                    $global:Logger.Debug("ScreenManager: In main loop iteration")
                }
                
                # Handle terminal resize
                if ([Console]::WindowWidth -ne $this._activeScreen.Width -or 
                    [Console]::WindowHeight -ne $this._activeScreen.Height) {
                    $this.HandleResize()
                }
                
                # Render if needed
                if ($this._needsRender -or $this._activeScreen._cacheInvalid) {
                    if ($global:Logger) {
                        $global:Logger.Debug("ScreenManager: Rendering (needsRender=$($this._needsRender), cacheInvalid=$($this._activeScreen._cacheInvalid))")
                    }
                    $this.Render()
                } else {
                    # Log occasionally why we're not rendering
                    if ($this._frameCount % 100 -eq 0 -and $global:Logger) {
                        $global:Logger.Debug("ScreenManager: Not rendering (needsRender=$($this._needsRender), cacheInvalid=$($this._activeScreen._cacheInvalid))")
                    }
                }
                
                # Handle input
                try {
                    # Check if running in test mode
                    if ($env:PRAXIS_TEST_MODE) {
                        if ($global:Logger) {
                            $global:Logger.Debug("Running in test mode - skipping input")
                        }
                        Start-Sleep -Milliseconds 100
                        continue
                    }
                    
                    if ([Console]::KeyAvailable) {
                        $key = [Console]::ReadKey($true)
                        $this._lastKey = $key
                        
                        # Log key press for debugging
                        if ($global:Logger) {
                            $global:Logger.Debug("Key pressed: $($key.Key) Char: '$($key.KeyChar)' Modifiers: $($key.Modifiers)")
                        }
                        
                        # Let active screen handle it
                        $handled = $false
                        try {
                            $handled = $this._activeScreen.HandleInput($key)
                            if ($global:Logger) {
                                $global:Logger.Debug("Key handled by screen: $handled")
                            }
                        } catch {
                            if ($global:Logger) {
                                $global:Logger.LogException($_, "Error handling input")
                            }
                        }
                        
                        if ($handled) {
                            $this._needsRender = $true
                        }
                        
                        # Global hotkeys
                        if ($key.Key -eq [System.ConsoleKey]::Escape -and 
                            ($key.Modifiers -band [System.ConsoleModifiers]::Control)) {
                            break  # Ctrl+Esc to exit
                        }
                    } else {
                        # Small sleep to prevent CPU spinning
                        Start-Sleep -Milliseconds 10
                    }
                } catch {
                    if ($global:Logger) {
                        $global:Logger.LogException($_, "Error in input handling")
                    }
                    
                    # In non-interactive mode, just sleep
                    Start-Sleep -Milliseconds 50
                    
                    # Check if we should exit (for testing)
                    if ($env:PRAXIS_TEST_MODE) {
                        break
                    }
                }
            }
        } finally {
            # Cleanup
            [Console]::CursorVisible = $true
            [Console]::Clear()
            [Console]::SetCursorPosition(0, 0)
        }
    }
    
    # Render current screen
    hidden [void] Render() {
        $this._renderTimer.Restart()
        
        # Get rendered content
        $content = $this._activeScreen.Render()
        
        # Write to console in one shot
        [Console]::SetCursorPosition(0, 0)
        [Console]::Write($content)
        
        $this._renderTimer.Stop()
        $this._frameCount++
        
        # Update FPS every second
        if ($this._frameCount % 60 -eq 0) {
            $this._lastFPS = 1000.0 / $this._renderTimer.ElapsedMilliseconds
        }
        
        $this._needsRender = $false
    }
    
    # Handle terminal resize
    hidden [void] HandleResize() {
        $newWidth = [Console]::WindowWidth
        $newHeight = [Console]::WindowHeight
        
        # Update all screens in stack
        foreach ($screen in $this._screenStack) {
            $screen.SetBounds(0, 0, $newWidth, $newHeight)
        }
        
        # Clear and force full redraw
        [Console]::Clear()
        $this._needsRender = $true
    }
    
    # Request render on next frame
    [void] RequestRender() {
        $this._needsRender = $true
    }
    
    # Get current FPS
    [double] GetFPS() {
        return $this._lastFPS
    }
}

# Global screen manager instance
$global:ScreenManager = $null