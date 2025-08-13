# Core/SimpleTaskProApp-Phase3.ps1 - Enhanced app with Phase 1 services and new Screen architecture
# Flat navigation, no over-engineering, uses our Phase 1 foundation

class SimpleTaskProApp {
    # Phase 1 services
    hidden [ServiceContainer]$_services
    hidden [RenderEngine]$_renderEngine
    hidden [InputProcessor]$_inputProcessor
    hidden [StateManager]$_stateManager
    
    # Screen management - flat navigation (no stack)
    hidden [hashtable]$_screens = @{}
    hidden [Screen]$_currentScreen = $null
    hidden [string]$_currentScreenName = "Tasks"
    
    # Application state
    hidden [bool]$_running = $true
    hidden [datetime]$_lastActivityTime = [datetime]::Now
    
    # Constructor with Phase 1 service injection
    SimpleTaskProApp([ServiceContainer]$services) {
        $this._services = $services
        $this._renderEngine = $services.GetService("RenderEngine")
        $this._inputProcessor = $services.GetService("InputProcessor")
        $this._stateManager = $services.GetService("StateManager")
        
        [Logger]::Info("SimpleTaskProApp initializing with Phase 1 services")
        
        # Setup EventBus subscriptions for flat navigation
        $this.SetupEventBusSubscriptions()
        
        # Initialize screens (will create actual screen classes later)
        $this.InitializeScreens()
        
        # Set initial screen
        $this.SetCurrentScreen("Tasks")
        
        [Logger]::Info("SimpleTaskProApp initialization complete")
    }
    
    # Initialize all application screens
    [void] InitializeScreens() {
        try {
            # For now, create placeholder screens
            # In the next phase, these will be actual TaskListScreen, etc.
            $this._screens["Tasks"] = [PlaceholderScreen]::new($this._services, "Tasks", "Task Management")
            $this._screens["TimeEntry"] = [PlaceholderScreen]::new($this._services, "TimeEntry", "Time Entry")  
            $this._screens["Commands"] = [PlaceholderScreen]::new($this._services, "Commands", "Command Library")
            $this._screens["Excel"] = [PlaceholderScreen]::new($this._services, "Excel", "Excel Mappings")
            
            [Logger]::Info("Initialized $($this._screens.Keys.Count) screens")
            
        } catch {
            [Logger]::Error("Failed to initialize screens", $_)
            throw
        }
    }
    
    # Setup EventBus subscriptions for navigation and app control
    [void] SetupEventBusSubscriptions() {
        # App control events
        [EventBus]::Subscribe("ApplicationExit", {
            $this._running = $false
            [Logger]::Info("Application exit requested")
        }.GetNewClosure())
        
        # Navigation events (flat navigation)
        [EventBus]::Subscribe("NavigateTo", {
            param($screenName)
            $this.SetCurrentScreen($screenName)
        }.GetNewClosure())
        
        # Window resize events
        [EventBus]::Subscribe("WindowResized", {
            param($eventData)
            $this.HandleWindowResize($eventData.Width, $eventData.Height)
        }.GetNewClosure())
        
        [Logger]::Debug("EventBus subscriptions setup complete")
    }
    
    # Set current screen (flat navigation)
    [void] SetCurrentScreen([string]$screenName) {
        if (-not $this._screens.ContainsKey($screenName)) {
            [Logger]::Error("Unknown screen: $screenName. Available: $($this._screens.Keys -join ', ')")
            return
        }
        
        # Lose focus on current screen
        if ($this._currentScreen) {
            $this._currentScreen.SetFocused($false)
        }
        
        # Switch to new screen
        $this._currentScreen = $this._screens[$screenName]
        $this._currentScreenName = $screenName
        
        # Set focus and bounds
        $this._currentScreen.SetFocused($true)
        $this._currentScreen.SetBounds([Console]::WindowWidth, [Console]::WindowHeight)
        
        # Update state manager
        $this._stateManager.Dispatch([StateManager]::SetCurrentScreen($screenName))
        
        [Logger]::Info("Switched to screen: $screenName")
    }
    
    # Handle window resize
    [void] HandleWindowResize([int]$width, [int]$height) {
        if ($this._currentScreen) {
            $this._currentScreen.SetBounds($width, $height)
        }
        
        # Update state manager
        $this._stateManager.Dispatch([StateManager]::SetWindowDimensions($width, $height))
        
        [Logger]::Debug("Window resized to ${width}x${height}")
    }
    
    # Main application run loop
    [void] Run() {
        try {
            [Logger]::Info("Starting SimpleTaskPro main loop")
            
            # Optimize console for rendering
            $this._renderEngine.OptimizeConsole()
            
            # Initial render
            $this.RenderFrame()
            
            # Main loop
            while ($this._running) {
                try {
                    # Handle input if available
                    if ([Console]::KeyAvailable) {
                        $key = [Console]::ReadKey($true)
                        $this._lastActivityTime = [datetime]::Now
                        
                        # Let current screen handle input (which uses our InputProcessor)
                        if ($this._currentScreen) {
                            $handled = $this._currentScreen.HandleInput($key)
                            
                            # If not handled by screen, check for global shortcuts
                            if (-not $handled) {
                                $this.HandleGlobalShortcuts($key)
                            }
                        }
                        
                        # Re-render after input
                        $this.RenderFrame()
                    }
                    
                    # Check for window resize
                    $currentWidth = [Console]::WindowWidth
                    $currentHeight = [Console]::WindowHeight
                    $stateSize = $this._stateManager.GetState("UI.WindowDimensions")
                    
                    if ($currentWidth -ne $stateSize.Width -or $currentHeight -ne $stateSize.Height) {
                        $this.HandleWindowResize($currentWidth, $currentHeight)
                        $this.RenderFrame()
                    }
                    
                    # Small delay to prevent CPU spinning
                    Start-Sleep -Milliseconds 16  # ~60 FPS
                    
                } catch {
                    [Logger]::Error("Error in main loop", $_)
                    # Continue running unless it's critical
                }
            }
            
        } catch {
            [Logger]::Error("Critical error in Run()", $_)
            throw
        } finally {
            # Cleanup
            $this.Cleanup()
        }
    }
    
    # Render complete frame using our RenderEngine
    [void] RenderFrame() {
        if (-not $this._currentScreen) { return }
        
        try {
            # Get screen content
            $screenContent = $this._currentScreen.Render()
            
            # Use RenderEngine to render everything
            $renderables = @($this._currentScreen)
            $this._renderEngine.RenderFrame($renderables)
            
        } catch {
            [Logger]::Error("Error rendering frame", $_)
        }
    }
    
    # Handle global keyboard shortcuts
    [void] HandleGlobalShortcuts([System.ConsoleKeyInfo]$key) {
        # These are handled by InputProcessor, but we can add fallbacks here
        switch ($key.Key) {
            ([System.ConsoleKey]::F1) { $this.SetCurrentScreen("Tasks") }
            ([System.ConsoleKey]::F3) { $this.SetCurrentScreen("TimeEntry") }
            ([System.ConsoleKey]::F4) { $this.SetCurrentScreen("Commands") }
            ([System.ConsoleKey]::F6) { $this.SetCurrentScreen("Excel") }
            ([System.ConsoleKey]::Escape) {
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    [EventBus]::Publish("ApplicationExit")
                }
            }
        }
    }
    
    # Application cleanup
    [void] Cleanup() {
        [Logger]::Info("SimpleTaskProApp cleanup starting")
        
        try {
            # Cleanup current screen
            if ($this._currentScreen) {
                $this._currentScreen.SetFocused($false)
                $this._currentScreen.Cleanup()
            }
            
            # Cleanup all screens
            foreach ($screen in $this._screens.Values) {
                if ($screen) {
                    $screen.Cleanup()
                }
            }
            
            # Restore console
            $this._renderEngine.RestoreConsole()
            
        } catch {
            [Logger]::Error("Error during cleanup", $_)
        }
        
        [Logger]::Info("SimpleTaskProApp cleanup complete")
    }
    
    # Public API for external access
    [Screen] GetCurrentScreen() {
        return $this._currentScreen
    }
    
    [string] GetCurrentScreenName() {
        return $this._currentScreenName
    }
    
    [bool] IsRunning() {
        return $this._running
    }
}

# Placeholder screen for testing - will be replaced with actual screens
class PlaceholderScreen : Screen {
    hidden [string]$_screenName
    hidden [string]$_description
    
    PlaceholderScreen([ServiceContainer]$services, [string]$screenName, [string]$description) : base($services) {
        $this._screenName = $screenName
        $this._description = $description
    }
    
    [string] Render() {
        $sb = $this.RenderEngine.GetStringBuilder()
        try {
            # Clear screen and move to top
            [void]$sb.Append($this.RenderEngine.ClearScreen())
            [void]$sb.Append($this.MoveTo(0, 0))
            
            # Header
            [void]$sb.Append($this.SetForegroundColor(100, 150, 255))
            [void]$sb.Append("SimpleTaskPro - $($this._description)")
            [void]$sb.Append($this.Reset())
            
            # Content area
            [void]$sb.Append($this.MoveTo(0, 2))
            [void]$sb.Append("Screen: $($this._screenName)")
            [void]$sb.Append($this.MoveTo(0, 3))
            [void]$sb.Append("Phase 1 services active - Logger, StateManager, InputProcessor, RenderEngine")
            [void]$sb.Append($this.MoveTo(0, 4))
            [void]$sb.Append("Flat navigation: F1=Tasks, F3=TimeEntry, F4=Commands, F6=Excel")
            
            # Footer
            [void]$sb.Append($this.MoveTo(0, $this.Height - 2))
            [void]$sb.Append($this.GetHorizontalLine($this.Width))
            [void]$sb.Append($this.MoveTo(0, $this.Height - 1))
            [void]$sb.Append("F1-F6: Navigate | Ctrl+Esc: Exit | Current: $($this._screenName)")
            
            return $sb.ToString()
        }
        finally {
            $this.RenderEngine.ReturnStringBuilder($sb)
        }
    }
    
    [void] HandleScreenCommand([string]$command) {
        switch ($command) {
            "screen.tasks" { $this.NavigateTo("Tasks") }
            "screen.time" { $this.NavigateTo("TimeEntry") }
            "screen.commands" { $this.NavigateTo("Commands") }
            "screen.excel" { $this.NavigateTo("Excel") }
            default {
                [Logger]::Debug("PlaceholderScreen received command: $command")
            }
        }
    }
}