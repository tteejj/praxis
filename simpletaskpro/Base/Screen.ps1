# Base/Screen.ps1 - Simple, practical screen base class
# Takes the best patterns from Praxis without over-engineering
# No templates, no complex lifecycle, just what's needed

class Screen {
    # Core services - injected once, used everywhere
    [ServiceContainer]$Services
    [RenderEngine]$RenderEngine
    [InputProcessor]$InputProcessor
    [SimpleStateManager]$StateManager
    [EventBus]$EventBus
    [Logger]$Logger
    
    # Screen dimensions - managed by app
    [int]$Width = 80
    [int]$Height = 25
    
    # Focus state (from Praxis FocusableComponent pattern)
    [bool]$IsFocused = $true
    
    # Title for display
    [string]$Title = "Screen"
    
    # Constructor - simple service injection only
    Screen([ServiceContainer]$services) {
        $this.Services = $services
        $this.RenderEngine = $services.GetService("RenderEngine")
        $this.InputProcessor = $services.GetService("InputProcessor") 
        $this.StateManager = $services.GetService("StateManager")
        $this.EventBus = $services.GetService("EventBus")
        $this.Logger = $services.GetService("Logger")
    }
    
    # This is the single, public entry point for initializing a screen.
    # The main application will call this after the screen is created.
    [void] Initialize() {
        $this.SetBounds([Console]::WindowWidth, [Console]::WindowHeight)
        $this.Logger.Debug("Screen $($this.GetType().Name) initializing...")
        
        # Subscribe to the core command execution event from the InputProcessor.
        # This is how the screen receives commands for keys the user presses.
        $this.Logger.Debug("Screen subscribing to command.executed events")
        $screenRef = $this  # Capture $this reference for closure
        $this.EventBus.Subscribe("command.executed", {
            param($eventData)
            $screenRef.Logger.Debug("EventBus received command.executed: $($eventData.Command)")
            $screenRef.HandleCommand($eventData.Command)
        }.GetNewClosure())
        
        # Call the overrideable hook for child classes to perform their specific setup.
        $this.OnInitialize()
        $this.Logger.Debug("Screen $($this.GetType().Name) OnInitialize hook completed.")
    }
    
    # Hook for derived classes to override
    [void] OnInitialize() {
        # Default implementation does nothing
    }
    
    # Simple bounds management (from Praxis pattern)
    [void] SetBounds([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
        $this.Logger.Debug("Screen $($this.GetType().Name) bounds set to ${width}x${height}")
    }
    
    # Focus management (simplified from Praxis)
    [void] SetFocused([bool]$focused) {
        if ($this.IsFocused -ne $focused) {
            $this.IsFocused = $focused
            if ($focused) {
                $this.OnFocusReceived()
            } else {
                $this.OnFocusLost()
            }
        }
    }
    
    # Core interface - hand implement in each screen (no templates!)
    [string] Render() {
        throw "Screen.Render() must be implemented in derived class $($this.GetType().Name)"
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Let our InputProcessor handle key mapping to commands
        return $this.InputProcessor.ProcessKey($key)
    }
    
    # Command handling - override in derived classes for screen-specific commands
    [void] HandleCommand([string]$command) {
        $this.Logger.Debug("Screen.HandleCommand called with: '$command'")
        switch ($command) {
            # Handle universal commands here
            "app.exit" {
                $this.EventBus.Publish("ApplicationExit")
            }
            "app.help" {
                # Show help - could be implemented later
                $this.Logger.Info("Help requested from $($this.GetType().Name)")
            }
            default {
                # Let derived class handle it
                $this.HandleScreenCommand($command)
            }
        }
    }
    
    # Override in derived classes for screen-specific commands
    [void] HandleScreenCommand([string]$command) {
        $this.Logger.Debug("Screen $($this.GetType().Name) received unhandled command: $command")
    }
    
    # Simple focus hooks (from Praxis pattern)
    [void] OnFocusReceived() {
        $this.Logger.Debug("Screen $($this.GetType().Name) received focus")
    }
    
    [void] OnFocusLost() {
        $this.Logger.Debug("Screen $($this.GetType().Name) lost focus")
    }
    
    # Utility methods for common operations
    
    # Get current application state
    [hashtable] GetState() {
        return $this.StateManager.GetState()
    }
    
    # Get specific state value
    [object] GetState([string]$key) {
        return $this.StateManager.Get($key)
    }
    
    # Set state value
    [void] SetState([string]$key, [object]$value) {
        $this.StateManager.Set($key, $value)
    }
    
    # Update multiple state values
    [void] UpdateState([hashtable]$updates) {
        $this.StateManager.Update($updates)
    }
    
    # Navigate to another screen (flat navigation)
    [void] NavigateTo([string]$screenName) {
        $this.EventBus.Publish("NavigateTo", $screenName)
    }
    
    # Render helpers using our performance infrastructure
    
    # Get cached spaces (from StringCache)
    [string] GetSpaces([int]$count) {
        return [StringCache]::GetSpaces($count)
    }
    
    # Get cached horizontal line
    [string] GetHorizontalLine([int]$count) {
        return [StringCache]::GetHorizontalLine($count)
    }
    
    # Move cursor (using RenderEngine)
    [string] MoveTo([int]$x, [int]$y) {
        return $this.RenderEngine.MoveTo($x, $y)
    }
    
    # Clear line
    [string] ClearLine() {
        return $this.RenderEngine.ClearLine()
    }
    
    # Reset formatting
    [string] Reset() {
        return $this.RenderEngine.Reset()
    }
    
    # Colors (basic - can be enhanced later)
    [string] SetForegroundColor([int]$r, [int]$g, [int]$b) {
        return $this.RenderEngine.SetForegroundColor($r, $g, $b)
    }
    
    [string] SetBackgroundColor([int]$r, [int]$g, [int]$b) {
        return $this.RenderEngine.SetBackgroundColor($r, $g, $b)
    }
    
    # Simple border rendering (from Praxis StringCache pattern)
    [string] RenderSimpleBorder([int]$x, [int]$y, [int]$width, [int]$height) {
        if ($width -lt 2 -or $height -lt 2) { return "" }
        
        $sb = $this.RenderEngine.GetStringBuilder()
        try {
            # Top border
            [void]$sb.Append($this.MoveTo($x, $y))
            [void]$sb.Append([StringCache]::GetBorderChar("TopLeft"))
            [void]$sb.Append([StringCache]::GetHorizontalLine($width - 2))
            [void]$sb.Append([StringCache]::GetBorderChar("TopRight"))
            
            # Side borders
            for ($i = 1; $i -lt ($height - 1); $i++) {
                [void]$sb.Append($this.MoveTo($x, $y + $i))
                [void]$sb.Append([StringCache]::GetBorderChar("Vertical"))
                [void]$sb.Append($this.MoveTo($x + $width - 1, $y + $i))
                [void]$sb.Append([StringCache]::GetBorderChar("Vertical"))
            }
            
            # Bottom border
            [void]$sb.Append($this.MoveTo($x, $y + $height - 1))
            [void]$sb.Append([StringCache]::GetBorderChar("BottomLeft"))
            [void]$sb.Append([StringCache]::GetHorizontalLine($width - 2))
            [void]$sb.Append([StringCache]::GetBorderChar("BottomRight"))
            
            return $sb.ToString()
        }
        finally {
            $this.RenderEngine.ReturnStringBuilder($sb)
        }
    }
    
    # Cleanup when screen is disposed (if needed)
    [void] Cleanup() {
        $this.Logger.Debug("Screen $($this.GetType().Name) cleanup")
        # Override in derived classes if needed
    }
}