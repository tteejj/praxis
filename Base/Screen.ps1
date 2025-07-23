# Screen.ps1 - Base class for all screens
# Simplified from ALCAR with focus on speed

class Screen : Container {
    [string]$Title = "Screen"
    [bool]$Active = $true
    hidden [hashtable]$_keyBindings = @{}
    hidden [ThemeManager]$Theme
    
    # Protected service container for dependency injection
    hidden [ServiceContainer]$ServiceContainer
    
    Screen() : base() {
        $this.IsFocusable = $true
        $this.DrawBackground = $true
    }
    
    # Initialize with services
    [void] Initialize([ServiceContainer]$services) {
        $this.ServiceContainer = $services
        $this.Theme = $services.GetService("ThemeManager")
        $this.Theme.Subscribe({ $this.OnThemeChanged() })
        $this.OnThemeChanged()
        $this.OnInitialize()
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
    [void] OnInitialize() {}
    
    # Theme change handler
    [void] OnThemeChanged() {
        $this.SetBackgroundColor($this.Theme.GetColor("background"))
        $this.Invalidate()
    }
    
    # Override this method in derived screens to handle screen-specific input
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        return $false  # Base implementation - no screen-specific handling
    }
    
    # Input handling - screen-specific then container
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # First try screen-specific input handling
        if ($this.HandleScreenInput($keyInfo)) {
            return $true
        }
        
        # Then let container handle focused child input
        return ([Container]$this).HandleInput($keyInfo)
    }
    
    # Lifecycle methods - simple and fast
    [void] OnActivated() {
        # Force a render when screen is activated
        $this.Invalidate()
    }
    
    [void] OnDeactivated() {
        # Override in derived classes if needed
    }
    
    # Simple focus navigation - works with PowerShell patterns
    [void] FocusNext() {
        $focusable = [System.Collections.ArrayList]::new()
        $this.CollectFocusableElements($this, $focusable)
        
        if ($focusable.Count -eq 0) { return }
        
        # Find current focused element
        $currentIndex = -1
        for ($i = 0; $i -lt $focusable.Count; $i++) {
            if ($focusable[$i].IsFocused) {
                $currentIndex = $i
                break
            }
        }
        
        # Move to next (wrap around)
        $nextIndex = ($currentIndex + 1) % $focusable.Count
        $focusable[$nextIndex].Focus()
    }
    
    # Collect all focusable descendants
    [void] CollectFocusableElements([UIElement]$element, [System.Collections.ArrayList]$list) {
        if ($element.Visible) {
            if ($element.IsFocusable) {
                $list.Add($element) | Out-Null
            }
            foreach ($child in $element.Children) {
                $this.CollectFocusableElements($child, $list)
            }
        }
    }

    # Request a re-render
    [void] RequestRender() {
        $this.Invalidate()
        # The ScreenManager will handle the actual rendering
    }
}