# ScreenManager.ps1 - Manages screen lifecycle and rendering
# Optimized for minimal overhead

class ScreenManager {
    hidden [System.Collections.Generic.Stack[Screen]]$_screenStack
    hidden [Screen]$_activeScreen = $null
    hidden [bool]$_needsRender = $true
    hidden [System.ConsoleKeyInfo]$_lastKey
    hidden [ServiceContainer]$_services
    hidden [ShortcutManager]$_shortcutManager
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
        
        # Get ShortcutManager if available
        $this._shortcutManager = $services.GetService('ShortcutManager')
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
                if ($global:Logger -and $this._frameCount % 100 -eq 0) {
                    $global:Logger.Debug("ScreenManager: In main loop iteration, activeScreen = " + $(if ($this._activeScreen) { $this._activeScreen.GetType().Name } else { "null" }))
                    $global:Logger.Debug("ScreenManager: needsRender = $($this._needsRender), frameCount = $($this._frameCount)")
                }
                
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
                        $handled = $false
                        
                        # Log key press for debugging
                        if ($global:Logger) {
                            $global:Logger.Debug("Key pressed: $($key.Key) Char: '$($key.KeyChar)' Modifiers: $($key.Modifiers)")
                        }
                        
                        # PARENT-DELEGATED INPUT MODEL - Simple routing only
                        $handled = $false
                        
                        # 1. Check ShortcutManager for global shortcuts first
                        if ($this._shortcutManager) {
                            # Get the actual active screen (e.g., ProjectsScreen within MainScreen's TabContainer)
                            $currentScreenType = ""
                            if ($this._activeScreen) {
                                if ($this._activeScreen.GetType().Name -eq "MainScreen" -and $this._activeScreen.TabContainer) {
                                    $activeTab = $this._activeScreen.TabContainer.GetActiveTab()
                                    if ($activeTab -and $activeTab.Content) {
                                        $currentScreenType = $activeTab.Content.GetType().Name
                                    }
                                } else {
                                    $currentScreenType = $this._activeScreen.GetType().Name
                                }
                            }
                            
                            $currentContext = if ($this._activeScreen.CommandPalette -and $this._activeScreen.CommandPalette.IsVisible) { "CommandPalette" } else { "" }
                            
                            if ($global:Logger) {
                                $global:Logger.Debug("ShortcutManager.HandleKeyPress: Key=$($key.Key) Char='$($key.KeyChar)' ScreenType=$currentScreenType Context=$currentContext")
                            }
                            
                            $handled = $this._shortcutManager.HandleKeyPress($key, $currentScreenType, $currentContext)
                            
                            if ($global:Logger) {
                                $global:Logger.Debug("ShortcutManager handled=$handled")
                            }
                        }
                        
                        # 2. Command Palette override (when visible) - only if not handled by shortcuts
                        if (-not $handled -and $this._activeScreen -and $this._activeScreen.CommandPalette -and $this._activeScreen.CommandPalette.IsVisible) {
                            $handled = $this._activeScreen.CommandPalette.HandleInput($key)
                            if ($global:Logger) {
                                $global:Logger.Debug("Key routed to CommandPalette")
                            }
                        }
                        # 3. Fallback to hardcoded shortcuts if ShortcutManager not available
                        elseif (-not $this._shortcutManager) {
                            if ($key.KeyChar -eq '/' -or $key.KeyChar -eq ':') {
                                # Show command palette
                                if ($this._activeScreen -and $this._activeScreen.CommandPalette) {
                                    $this._activeScreen.CommandPalette.Show()
                                    $handled = $true
                                    if ($global:Logger) {
                                        $global:Logger.Debug("Key handled: Command palette opened")
                                    }
                                }
                            } 
                            elseif ($key.Key -eq [System.ConsoleKey]::Tab) {
                                # Handle Tab navigation via parent delegation
                                if ($this._activeScreen) {
                                    $handled = $this.HandleTabNavigation($key)
                                }
                            }
                            elseif ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                                # Ctrl+Q for quit
                                if ($key.Key -eq [System.ConsoleKey]::Q) {
                                    $this.RequestExit()
                                    $handled = $true
                                    if ($global:Logger) {
                                        $global:Logger.Debug("Key handled: Quit application")
                                    }
                                }
                            }
                            # Ctrl+Arrows for focus navigation
                            elseif ($key.Key -eq [System.ConsoleKey]::RightArrow -or $key.Key -eq [System.ConsoleKey]::LeftArrow) {
                                if ($this._activeScreen) {
                                    $handled = $this.HandleTabNavigation($key)
                                }
                            }
                        }
                        
                        # 4. Tab navigation (if not handled above)
                        if (-not $handled -and $key.Key -eq [System.ConsoleKey]::Tab -and $this._activeScreen) {
                            $handled = $this.HandleTabNavigation($key)
                        }
                        
                        # 5. If not handled by global shortcuts, let screen handle it
                        if (-not $handled -and $this._activeScreen) {
                            try {
                                $handled = $this._activeScreen.HandleInput($key)
                                if ($handled -and $global:Logger) {
                                    $global:Logger.Debug("Key handled by screen: $($this._activeScreen.GetType().Name)")
                                }
                            } catch {
                                if ($global:Logger) {
                                    $global:Logger.LogException($_.Exception, "Error in screen input handling")
                                }
                            }
                        }
                        
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
                    if ($global:Logger) {
                        $global:Logger.LogException($_.Exception, "Error in input handling")
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
        
        if ($global:Logger) {
            $global:Logger.Debug("ScreenManager.Render: Starting render")
        }
        
        # Get rendered content
        $content = $this._activeScreen.Render()
        
        if ($global:Logger) {
            $global:Logger.Debug("ScreenManager.Render: Content length = $($content.Length)")
        }
        
        # Always write to console
        [Console]::CursorVisible = $false
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
        $this._lastContent = ""  # Force full redraw on next render
        $this._needsRender = $true
    }
    
    # Request render on next frame
    [void] RequestRender() {
        $this._needsRender = $true
    }
    
    # Parent-delegated Tab navigation
    [bool] HandleTabNavigation([System.ConsoleKeyInfo]$key) {
        # Find the deepest focused element
        $focused = $this.FindDeepestFocusedElement($this._activeScreen)
        if ($global:Logger) {
            $global:Logger.Debug("HandleTabNavigation: Focused element = " + $(if ($focused) { $focused.GetType().Name } else { "null" }))
        }
        
        if (-not $focused) {
            # No focus, try to focus first focusable element
            if ($global:Logger) {
                $global:Logger.Debug("HandleTabNavigation: No focused element, focusing first")
            }
            $this._activeScreen.FocusFirst()
            return $true
        }
        
        # Ask the parent to handle navigation
        if ($focused.Parent) {
            $isReverse = ($key.Modifiers -band [System.ConsoleModifiers]::Shift) -or 
                         ($key.Key -eq [System.ConsoleKey]::LeftArrow)
            
            if ($global:Logger) {
                $global:Logger.Debug("HandleTabNavigation: Parent = $($focused.Parent.GetType().Name), Reverse = $isReverse")
            }
            
            if ($isReverse) {
                $focused.Parent.FocusPreviousChild($focused)
            } else {
                $focused.Parent.FocusNextChild($focused)
            }
            
            if ($global:Logger) {
                $direction = if ($isReverse) { "reverse" } else { "forward" }
                $global:Logger.Debug("Tab navigation: $direction via parent delegation")
            }
            return $true
        }
        
        return $false
    }
    
    # Find the deepest focused element in the tree
    [UIElement] FindDeepestFocusedElement([UIElement]$root) {
        if (-not $root) { return $null }
        
        if ($root.IsFocused) {
            # Check if any child is focused (go deeper)
            foreach ($child in $root.Children) {
                $deeper = $this.FindDeepestFocusedElement($child)
                if ($deeper) { return $deeper }
            }
            return $root
        }
        
        # Not focused, check children
        foreach ($child in $root.Children) {
            $found = $this.FindDeepestFocusedElement($child)
            if ($found) { return $found }
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
}

# Global screen manager instance
$global:ScreenManager = $null