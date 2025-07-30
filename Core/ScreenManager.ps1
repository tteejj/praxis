# ScreenManager.ps1 - Manages screen lifecycle and rendering
# Optimized for minimal overhead

class ScreenManager {
    hidden [System.Collections.Generic.Stack[Screen]]$_screenStack
    hidden [Screen]$_activeScreen = $null
    hidden [bool]$_needsRender = $true
    hidden [System.ConsoleKeyInfo]$_lastKey
    hidden [ServiceContainer]$_services
    # hidden [ShortcutManager]$_shortcutManager  # Removed - deprecated
    hidden [FocusManager]$_focusManager
    hidden [bool]$_exitRequested = $false
    
    # Performance tracking
    hidden [System.Diagnostics.Stopwatch]$_renderTimer
    hidden [int]$_frameCount = 0
    hidden [double]$_lastFPS = 0
    
    # Double buffering
    hidden [string]$_lastContent = ""
    
    ScreenManager([ServiceContainer]$services) {
        $this._screenStack = [System.Collections.Generic.Stack[Screen]]::new()
        $this._services = $services
        $this._renderTimer = [System.Diagnostics.Stopwatch]::new()
        
        # Get managers - with protection against initialization order issues
        try {
            # $this._shortcutManager = $services.GetService('ShortcutManager')  # Removed - deprecated
            if ($global:Logger) {
                $global:Logger.Debug("ScreenManager: ShortcutManager deprecated - removed")
            }
        } catch {
            if ($global:Logger) {
                $global:Logger.LogWarning("ScreenManager: ShortcutManager deprecated - removed")
            }
            # $this._shortcutManager = $null  # Removed - deprecated
        }
        
        try {
            $this._focusManager = $services.GetService('FocusManager')
            if ($global:Logger) {
                $global:Logger.Debug("ScreenManager: FocusManager loaded successfully")
            }
        } catch {
            if ($global:Logger) {
                $global:Logger.LogWarning("ScreenManager: FocusManager not available during construction: $_")
            }
            $this._focusManager = $null
        }
    }
    
    # Push a new screen
    [void] Push([Screen]$screen) {
        if ($global:Logger) {
            $global:Logger.Info("ScreenManager.Push: Pushing screen $($screen.GetType().Name)")
        }
        
        # Deactivate current
        if ($this._activeScreen) {
            $this._activeScreen.Active = $false
            $this._activeScreen.OnDeactivated()
        }
        
        try {
            # Initialize and activate new screen
            $screen.Initialize($this._services)
            
            # Ensure we have valid console dimensions
            $width = [Math]::Max([Console]::WindowWidth, 80)
            $height = [Math]::Max([Console]::WindowHeight, 24)
            $screen.SetBounds(0, 0, $width, $height)
            
            if ($global:Logger) {
                $global:Logger.Debug("ScreenManager.Push: Set screen bounds to (0,0,$width,$height)")
            }
            
            $this._screenStack.Push($screen)
            $this._activeScreen = $screen
            $this._activeScreen.Active = $true
            $this._activeScreen.OnActivated()
            
            # Clear last content to force redraw on screen change
            $this._lastContent = ""
            $this._needsRender = $true
            
            if ($global:Logger) {
                $global:Logger.Info("ScreenManager.Push: Successfully pushed $($screen.GetType().Name), Active=$($this._activeScreen.Active)")
            }
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("ScreenManager.Push: Error pushing screen - $_")
                $global:Logger.Error("Stack trace: $($_.ScriptStackTrace)")
            }
            throw
        }
    }
    
    # Pop current screen
    [Screen] Pop() {
        if ($this._screenStack.Count -eq 0) { return $null }
        
        if ($global:Logger) {
            $global:Logger.Debug("ScreenManager.Pop: Stack count before pop = $($this._screenStack.Count)")
        }
        
        $popped = $this._screenStack.Pop()
        if ($popped) {
            $popped.Active = $false
            $popped.OnDeactivated()
        }
        
        # Activate previous screen if any
        if ($this._screenStack.Count -gt 0) {
            $this._activeScreen = $this._screenStack.Peek()
            if ($this._activeScreen) {
                if ($global:Logger) {
                    $global:Logger.Debug("ScreenManager.Pop: Activating previous screen: $($this._activeScreen.GetType().Name)")
                }
                try {
                    $this._activeScreen.Active = $true
                    $this._activeScreen.OnActivated()
                    $this._activeScreen.Invalidate()  # Force redraw of the screen
                } catch {
                    if ($global:Logger) {
                        $global:Logger.Error("ScreenManager.Pop: Error activating previous screen - $_")
                        $global:Logger.Error("Stack trace: $($_.ScriptStackTrace)")
                    }
                }
            } else {
                if ($global:Logger) {
                    $global:Logger.Error("ScreenManager.Pop: Previous screen is null!")
                }
            }
        } else {
            $this._activeScreen = $null
        }
        
        # Clear last content to force redraw
        $this._lastContent = ""
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
            if ($this._activeScreen) {
                $global:Logger.Info("Active screen: $($this._activeScreen.GetType().Name)")
                $global:Logger.Info("Active screen.Active: $($this._activeScreen.Active)")
            } else {
                $global:Logger.Info("Active screen: null")
            }
            $global:Logger.Flush()
        }
        
        # Track window size
        $lastWidth = [Console]::WindowWidth
        $lastHeight = [Console]::WindowHeight
        
        # Set needsRender to true to ensure first frame renders
        $this._needsRender = $true
        
        try {
            while ($this._activeScreen -and $this._activeScreen.Active -and -not $this._exitRequested) {
                # Debug logging removed for performance
                
                # Check for window resize
                $currentWidth = [Console]::WindowWidth
                $currentHeight = [Console]::WindowHeight
                if ($currentWidth -ne $lastWidth -or $currentHeight -ne $lastHeight) {
                    $lastWidth = $currentWidth
                    $lastHeight = $currentHeight
                    
                    # Update screen bounds
                    if ($this._activeScreen) {
                        $this._activeScreen.SetBounds(0, 0, $currentWidth, $currentHeight)
                        $this._needsRender = $true
                        
                        if ($global:Logger) {
                            $global:Logger.Debug("ScreenManager: Window resized to ${currentWidth}x${currentHeight}")
                        }
                    }
                }
                
                # Handle terminal resize
                if ([Console]::WindowWidth -ne $this._activeScreen.Width -or 
                    [Console]::WindowHeight -ne $this._activeScreen.Height) {
                    $this.HandleResize()
                }
                
                # Render if needed
                if ($this._needsRender -or $this._activeScreen._cacheInvalid) {
                    $this.Render()
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
                    
                    # Check if console input is available (not redirected)
                    if ([Console]::IsInputRedirected) {
                        Start-Sleep -Milliseconds 50
                        continue
                    }
                    
                    if ([Console]::KeyAvailable) {
                        $key = [Console]::ReadKey($true)
                        $this._lastKey = $key
                        $handled = $false
                        
                        # Standard key processing
                        
                        # SIMPLIFIED INPUT CHAIN - Clean priority order
                        $handled = $this.ProcessInputChain($key)
                        
                        # Input chain completed
                        
                        if ($handled) {
                            $this._needsRender = $true
                        }
                        
                        # Emergency exit (Ctrl+Esc)
                        if ($key.Key -eq [System.ConsoleKey]::Escape -and 
                            ($key.Modifiers -band [System.ConsoleModifiers]::Control)) {
                            break  # Ctrl+Esc to exit
                        }
                    } else {
                        # Small sleep to prevent CPU spinning
                        Start-Sleep -Milliseconds 10
                    }
                } catch {
                    # Only log if it's not the expected console redirect error
                    if ($_.Exception.Message -notlike "*cannot see if a key has been pressed*") {
                        if ($global:Logger) {
                            $global:Logger.LogException($_.Exception, "Error in input handling")
                        }
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
        
        # Clear screen if content changed significantly (like dialog closing)
        if ($this._lastContent -eq "") {
            [Console]::Clear()
        }
        
        # Always write to console
        [Console]::CursorVisible = $false
        [Console]::SetCursorPosition(0, 0)
        [Console]::Write($content)
        
        # Store content for next comparison
        $this._lastContent = $content
        
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
        $this._lastContent = ""  # Force full redraw on next render
        $this._needsRender = $true
    }
    
    # Request render on next frame
    [void] RequestRender() {
        $this._needsRender = $true
    }
    
    # Fast Tab navigation using FocusManager
    [bool] HandleTabNavigation([System.ConsoleKeyInfo]$key) {
        if (-not $this._focusManager) { 
            if ($global:Logger) {
                $global:Logger.Debug("HandleTabNavigation: FocusManager not available")
            }
            return $false 
        }
        
        $isReverse = ($key.Modifiers -band [System.ConsoleModifiers]::Shift) -ne 0
        
        # Use FocusManager for O(1) navigation
        if ($isReverse) {
            return $this._focusManager.FocusPrevious($this._activeScreen)
        } else {
            return $this._focusManager.FocusNext($this._activeScreen)
        }
    }
    
    # Get focused element using FocusManager (O(1))
    [UIElement] GetFocusedElement() {
        if ($this._focusManager) {
            return $this._focusManager.GetFocused()
        }
        return $null
    }
    
    # Get current FPS
    [double] GetFPS() {
        return $this._lastFPS
    }
    
    # Request application exit
    [void] RequestExit() {
        $this._exitRequested = $true
        if ($this._activeScreen) {
            $this._activeScreen.Active = $false
        }
    }
    
    # Show command palette
    [void] ShowCommandPalette() {
        if ($this._activeScreen -and $this._activeScreen.CommandPalette) {
            $this._activeScreen.CommandPalette.Show()
        }
    }
    
    # Simplified input processing chain - clean priority order
    hidden [bool] ProcessInputChain([System.ConsoleKeyInfo]$key) {
        # Process input through priority chain
        
        # PRIORITY 1: CommandPalette gets absolute priority when visible
        if ($this._activeScreen -and $this._activeScreen.CommandPalette -and $this._activeScreen.CommandPalette.IsVisible) {
            $handled = $this._activeScreen.CommandPalette.HandleInput($key)
            return $handled
        }
        
        # PRIORITY 2: ShortcutManager for global and screen-specific shortcuts - DEPRECATED
        # if ($this._shortcutManager) {
        #     $currentScreenType = $this.GetCurrentScreenType()
        #     $handled = $this._shortcutManager.HandleKeyPress($key, $currentScreenType, "")
        #     
        #     if ($handled) {
        #         if ($global:Logger) {
        #             $global:Logger.Debug("ShortcutManager handled: $handled")
        #         }
        #         return $true
        #     }
        # } else {
        #     if ($global:Logger -and $this._frameCount % 100 -eq 0) {
        #         $global:Logger.Debug("ProcessInputChain: ShortcutManager not available")
        #     }
        # }
        
        # PRIORITY 3: Screen and component input handling
        
        if ($this._activeScreen) {
            try {
                $handled = $this._activeScreen.HandleInput($key)
                return $handled
            } catch {
                if ($global:Logger) {
                    $global:Logger.LogException($_.Exception, "Error in screen input handling")
                }
            }
        }
        
        # PRIORITY 4: Emergency fallbacks
        return $this.HandleEmergencyInput($key)
    }
    
    # Get current screen type for ShortcutManager
    hidden [string] GetCurrentScreenType() {
        if (-not $this._activeScreen) { return "" }
        
        # Handle MainScreen with TabContainer specially
        if ($this._activeScreen.GetType().Name -eq "MainScreen" -and $this._activeScreen.TabContainer) {
            $activeTab = $this._activeScreen.TabContainer.GetActiveTab()
            if ($activeTab -and $activeTab.Content) {
                return $activeTab.Content.GetType().Name
            }
        }
        
        return $this._activeScreen.GetType().Name
    }
    
    # Emergency input handling (Ctrl+Esc, basic fallbacks)
    hidden [bool] HandleEmergencyInput([System.ConsoleKeyInfo]$key) {
        # Emergency exit (Ctrl+Esc) - always available
        if ($key.Key -eq [System.ConsoleKey]::Escape -and 
            ($key.Modifiers -band [System.ConsoleModifiers]::Control)) {
            $this.RequestExit()
            return $true
        }
        
        # Ctrl+Q fallback (ShortcutManager deprecated)
        if ($key.Key -eq [System.ConsoleKey]::Q -and 
            ($key.Modifiers -band [System.ConsoleModifiers]::Control)) {
            $this.RequestExit()
            return $true
        }
        
        # REMOVED: Command palette fallback - replaced with per-screen action popups
        # Old global command palette is deprecated
        
        return $false
    }
}

# Global screen manager instance
$global:ScreenManager = $null