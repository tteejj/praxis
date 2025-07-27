# Screen.ps1 - Base class for all screens
# Simplified from ALCAR with focus on speed

class Screen : Container {
    [string]$Title = "Screen"
    [bool]$Active = $true
    hidden [hashtable]$_keyBindings = @{}
    hidden [ThemeManager]$Theme
    hidden [HelpOverlay]$_helpOverlay
    
    # Protected service container for dependency injection
    hidden [ServiceContainer]$ServiceContainer
    
    Screen() : base() {
        $this.IsFocusable = $false  # Screens are containers, not focusable elements
        $this.DrawBackground = $true
    }
    
    # Initialize with services
    [void] Initialize([ServiceContainer]$services) {
        # Call base initialization
        ([UIElement]$this).Initialize($services)
        
        # Screen-specific initialization
        $this.Theme = $services.GetService("ThemeManager")
        $this.Theme.Subscribe({ $this.OnThemeChanged() })
        $this.OnThemeChanged()
    }
    
    # Helper method for service access with error handling
    [object] GetService([string]$serviceName) {
        if (-not $this.ServiceContainer) {
            if ($global:Logger) {
                $global:Logger.Warning("Screen.GetService: ServiceContainer not available, falling back to global access for $serviceName")
            }
            return $global:ServiceContainer.GetService($serviceName)
        }
        return $this.ServiceContainer.GetService($serviceName)
    }
    
    # Override for custom initialization
    [void] OnInitialize() {
        # Create help overlay
        $this._helpOverlay = [HelpOverlay]::new()
        $this._helpOverlay.Initialize($this.ServiceContainer)
        $this.AddChild($this._helpOverlay)
    }
    
    # Theme change handler
    [void] OnThemeChanged() {
        # Use background color for screen background
        $bgColor = $this.Theme.GetBgColor("background")
        $this.SetBackgroundColor($bgColor)
        $this.InvalidateBackground()
        $this.Invalidate()
    }
    
    # Override this method in derived screens to handle screen-specific input
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        return $false  # Base implementation - no screen-specific handling
    }
    
    # PARENT-DELEGATED INPUT MODEL
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # Check if help overlay is visible and let it handle input first
        if ($this._helpOverlay -and $this._helpOverlay.IsVisible) {
            return $this._helpOverlay.HandleInput($keyInfo)
        }
        
        # Handle F1 for help
        if ($keyInfo.Key -eq [System.ConsoleKey]::F1) {
            $this.ShowHelp()
            return $true
        }
        
        # Debug logging removed for performance
        
        # 1. Let focused child handle first (components get priority)
        $handled = ([Container]$this).HandleInput($keyInfo)
        if ($global:Logger) {
            $global:Logger.Debug("Screen base handled: $handled")
        }
        if ($handled) {
            return $true
        }
        
        # 2. Screen shortcuts as fallback only
        $screenHandled = $this.HandleScreenInput($keyInfo)
        if ($global:Logger) {
            $global:Logger.Debug("Screen shortcuts handled: $screenHandled")
        }
        return $screenHandled
    }
    
    # Lifecycle methods - simple and fast
    [void] OnActivated() {
        # Force a render when screen is activated
        $this.Invalidate()
    }
    
    [void] OnDeactivated() {
        # Override in derived classes if needed
    }
    
    # Removed old FocusNext/FocusPrevious - now handled by parent delegation
    
    # Delegate to Container's FocusFirst
    [void] FocusFirst() {
        ([Container]$this).FocusFirst()
    }

    # Get help text for this screen - override in derived classes
    [string] GetHelpText() {
        return @"
No help available for this screen.

Press F1 to toggle help.
Press ESC to close help.
"@
    }
    
    # Show help overlay
    [void] ShowHelp() {
        if ($this._helpOverlay) {
            $helpText = $this.GetHelpText()
            $this._helpOverlay.Show($helpText)
        }
    }
    
    
    # Override OnBoundsChanged to update help overlay
    [void] OnBoundsChanged() {
        ([Container]$this).OnBoundsChanged()
        
        # Make help overlay cover the entire screen
        if ($this._helpOverlay) {
            $this._helpOverlay.SetBounds($this.X, $this.Y, $this.Width, $this.Height)
        }
    }
    
    # Request a re-render
    [void] RequestRender() {
        $this.Invalidate()
        # The ScreenManager will handle the actual rendering
    }
}