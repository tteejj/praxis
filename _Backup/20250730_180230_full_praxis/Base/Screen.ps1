# Screen.ps1 - Base class for all screens
# Simplified from ALCAR with focus on speed

class Screen : Container {
    [string]$Title = "Screen"
    [bool]$Active = $true
    hidden [hashtable]$_keyBindings = @{}
    hidden [object]$Theme
    
    # Protected service container for dependency injection
    hidden [object]$ServiceContainer
    
    Screen() : base() {
        $this.IsFocusable = $false  # Screens are containers, not focusable elements
        $this.DrawBackground = $true
    }
    
    # Initialize with services
    [void] Initialize([object]$services) {
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
        # Force theme refresh for all child components
        $this.Theme = $this.ServiceContainer.GetService("ThemeManager")
        if ($this.Theme) {
            $this.Theme.Subscribe({
                $this.ForceThemeRefresh()
            })
        }
        # Override in derived classes
    }
    
    # Theme change handler
    [void] OnThemeChanged() {
        # Use standardized surface background color for screen
        $bgColor = if ($this.Theme) {
            # Try standardized key first, fall back to legacy
            $color = $this.Theme.GetBgColor("surface.background")
            if (-not $color -or $color -eq "") {
                $color = $this.Theme.GetBgColor('surface.background')
            }
            $color
        } else {
            ""
        }
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
        # Force theme refresh
        if ($this.Theme) {
            $this.InvalidateAll($this)
        }
        # FORCE COMPLETE REFRESH ON ACTIVATION
        $this.ForceCompleteRefresh()
        if ($global:Logger) {
            $global:Logger.Debug("Screen.OnActivated: $($this.GetType().Name) activating")
        }
        
        # Force a render when screen is activated
        $this.Invalidate()
        
        # Ensure first focusable child gets focus
        # This ensures consistent behavior across all screens
        $this.FocusFirst()
        
        if ($global:Logger) {
            $global:Logger.Debug("Screen.OnActivated: $($this.GetType().Name) activation complete")
        }
    }
    
    [void] OnDeactivated() {
        # Override in derived classes if needed
    }
    
    # Removed old FocusNext/FocusPrevious - now handled by parent delegation
    
    # Delegate to Container's FocusFirst
    [void] FocusFirst() {
        ([Container]$this).FocusFirst()
    }

    # Override OnBoundsChanged
    [void] OnBoundsChanged() {
        ([Container]$this).OnBoundsChanged()
    }
    
    # Request a re-render
    [void] RequestRender() {
        $this.Invalidate()
        # The ScreenManager will handle the actual rendering
    }
    
    [void] ForceThemeRefresh() {
        # Recursively refresh all components
        $this.InvalidateRecursive($this)
    }
    
    hidden [void] InvalidateRecursive([UIElement]$element) {
        $element.Invalidate()
        if ($element.PSObject.Properties['UpdateThemeCache']) {
            $element.UpdateThemeCache()
        }
        if ($element -is [Container]) {
            foreach ($child in $element.GetChildren()) {
                $this.InvalidateRecursive($child)
            }
        }
    }
    
    [void] ForceCompleteRefresh() {
        # Force all children to refresh
        $this.InvalidateAll($this)
    }
    
    hidden [void] InvalidateAll([UIElement]$element) {
        $element.Invalidate()
        if ($element.PSObject.Methods['GetChildren']) {
            foreach ($child in $element.GetChildren()) {
                $this.InvalidateAll($child)
            }
        } elseif ($element.Children) {
            foreach ($child in $element.Children) {
                $this.InvalidateAll($child)
            }
        }
    }
}

