# ThemeManager.ps1 - Fast theme management with pre-cached ANSI sequences
# All colors are pre-computed to avoid runtime lookups

class ThemeManager {
    hidden [hashtable]$_themes = @{}
    hidden [string]$_currentTheme = "default"
    hidden [hashtable]$_cache = @{}
    hidden [System.Collections.Generic.List[scriptblock]]$_listeners
    hidden [EventBus]$EventBus
    
    ThemeManager() {
        $this._listeners = [System.Collections.Generic.List[scriptblock]]::new()
        $this.InitializeDefaultTheme()
        
        # EventBus will be set later via SetEventBus
    }
    
    [void] InitializeDefaultTheme() {
        # Define default theme with RGB values
        $defaultTheme = @{
            # Base colors
            "background" = @(24, 24, 24)        # Dark background
            "foreground" = @(204, 204, 204)     # Light gray text
            "accent" = @(0, 150, 255)           # Blue accent
            "success" = @(0, 200, 83)           # Green
            "warning" = @(255, 195, 0)          # Yellow
            "error" = @(255, 85, 85)            # Red
            
            # UI elements
            "border" = @(68, 68, 68)           # Dark gray
            "border.focused" = @(0, 150, 255)   # Blue
            "selection" = @(60, 60, 60)         # Selection background
            "disabled" = @(128, 128, 128)       # Gray
            
            # Component specific
            "button.background" = @(48, 48, 48)
            "button.foreground" = @(204, 204, 204)
            "button.focused.background" = @(0, 150, 255)
            "button.focused.foreground" = @(255, 255, 255)
            
            "input.background" = @(32, 32, 32)
            "input.foreground" = @(204, 204, 204)
            "input.focused.border" = @(0, 150, 255)
            
            "menu.background" = @(32, 32, 32)
            "menu.foreground" = @(204, 204, 204)
            "menu.selected.background" = @(0, 150, 255)
            "menu.selected.foreground" = @(255, 255, 255)
            
            "tab.background" = @(48, 48, 48)
            "tab.foreground" = @(170, 170, 170)
            "tab.active.background" = @(24, 24, 24)
            "tab.active.foreground" = @(255, 255, 255)
            "tab.active.accent" = @(0, 150, 255)
        }
        
        $this.RegisterTheme("default", $defaultTheme)
        
        # Define matrix theme - black background with green text
        $matrixTheme = @{
            # Base colors
            "background" = @(0, 0, 0)             # Pure black background
            "foreground" = @(0, 255, 0)           # Bright green text
            "accent" = @(0, 200, 0)               # Darker green accent
            "success" = @(0, 255, 0)              # Bright green
            "warning" = @(255, 255, 0)            # Yellow
            "error" = @(255, 0, 0)                # Red
            
            # UI elements
            "border" = @(0, 100, 0)               # Dark green borders
            "border.focused" = @(0, 255, 0)       # Bright green when focused
            "selection" = @(0, 100, 0)            # Dark green selection - more visible
            "disabled" = @(0, 128, 0)             # Medium green for disabled
            
            # Component specific
            "button.background" = @(0, 20, 0)
            "button.foreground" = @(0, 255, 0)
            "button.focused.background" = @(0, 100, 0)
            "button.focused.foreground" = @(0, 255, 0)
            
            "input.background" = @(0, 10, 0)
            "input.foreground" = @(0, 255, 0)
            "input.focused.border" = @(0, 255, 0)
            
            "menu.background" = @(0, 0, 0)
            "menu.foreground" = @(0, 200, 0)
            "menu.selected.background" = @(0, 80, 0)
            "menu.selected.foreground" = @(0, 255, 0)
            
            "tab.background" = @(0, 30, 0)
            "tab.foreground" = @(0, 150, 0)
            "tab.active.background" = @(0, 0, 0)
            "tab.active.foreground" = @(0, 255, 0)
            "tab.active.accent" = @(0, 255, 0)
            
            # Dialog colors
            "dialog.background" = @(0, 0, 0)
            "dialog.border" = @(0, 150, 0)
            "dialog.title" = @(0, 255, 0)
        }
        
        $this.RegisterTheme("matrix", $matrixTheme)
        $this.SetTheme("matrix")
    }
    
    # Register a new theme
    [void] RegisterTheme([string]$name, [hashtable]$colors) {
        $this._themes[$name] = $colors
        
        # If this is the current theme, rebuild cache
        if ($name -eq $this._currentTheme) {
            $this.RebuildCache()
        }
    }
    
    # Switch to a different theme
    [void] SetTheme([string]$name) {
        if (-not $this._themes.ContainsKey($name)) {
            throw "Theme '$name' not found"
        }
        
        $oldTheme = $this._currentTheme
        $this._currentTheme = $name
        $this.RebuildCache()
        
        # Notify via EventBus if available
        if ($this.EventBus) {
            $this.EventBus.Publish('app.themeChanged', @{
                OldTheme = $oldTheme
                NewTheme = $name
                ThemeManager = $this
            })
        }
        
        # Also notify legacy listeners for backward compatibility
        $this.NotifyListeners()
    }
    
    # Get pre-computed ANSI color sequence
    [string] GetColor([string]$key) {
        if ($this._cache.ContainsKey($key)) {
            return $this._cache[$key]
        }
        
        # Not in cache, compute it
        $rgb = $this.GetRGB($key)
        if ($rgb) {
            $ansi = [VT]::RGB($rgb[0], $rgb[1], $rgb[2])
            $this._cache[$key] = $ansi
            return $ansi
        }
        
        return ""  # No color defined
    }
    
    # Get background color sequence
    [string] GetBgColor([string]$key) {
        $bgKey = "$key.bg"
        if ($this._cache.ContainsKey($bgKey)) {
            return $this._cache[$bgKey]
        }
        
        # Not in cache, compute it
        $rgb = $this.GetRGB($key)
        if ($rgb) {
            $ansi = [VT]::RGBBG($rgb[0], $rgb[1], $rgb[2])
            $this._cache[$bgKey] = $ansi
            return $ansi
        }
        
        return ""  # No color defined
    }
    
    # Get raw RGB values
    [int[]] GetRGB([string]$key) {
        $theme = $this._themes[$this._currentTheme]
        
        if ($theme.ContainsKey($key)) {
            return $theme[$key]
        }
        
        # Try parent keys (e.g., "button" for "button.focused.background")
        $parts = $key -split '\.'
        for ($i = $parts.Count - 1; $i -gt 0; $i--) {
            $parentKey = $parts[0..($i-1)] -join '.'
            if ($theme.ContainsKey($parentKey)) {
                return $theme[$parentKey]
            }
        }
        
        return $null
    }
    
    # Rebuild the entire cache
    hidden [void] RebuildCache() {
        $this._cache.Clear()
        $theme = $this._themes[$this._currentTheme]
        
        # Pre-compute all theme colors
        foreach ($key in $theme.Keys) {
            $rgb = $theme[$key]
            if ($rgb -is [array] -and $rgb.Count -eq 3) {
                # Foreground
                $this._cache[$key] = [VT]::RGB($rgb[0], $rgb[1], $rgb[2])
                # Background
                $this._cache["$key.bg"] = [VT]::RGBBG($rgb[0], $rgb[1], $rgb[2])
            }
        }
        
        # Add common combinations
        $this._cache["reset"] = [VT]::Reset()
        $this._cache["clear"] = [VT]::Clear()
        $this._cache["clearline"] = [VT]::ClearLine()
    }
    
    # Subscribe to theme changes (legacy method - use EventBus instead)
    [void] Subscribe([scriptblock]$callback) {
        # Always use legacy listeners for now to avoid initialization order issues
        # EventBus subscription happens too early
        $this._listeners.Add($callback)
    }
    
    # Notify all listeners of theme change (legacy method)
    hidden [void] NotifyListeners() {
        # Only notify legacy listeners if EventBus is not available
        if (-not $this.EventBus) {
            foreach ($listener in $this._listeners) {
                try {
                    & $listener
                } catch {
                    # Ignore listener errors
                }
            }
        }
    }
    
    # Set EventBus after initialization (called by ServiceContainer)
    [void] SetEventBus([EventBus]$eventBus) {
        $this.EventBus = $eventBus
    }
    
    # Get list of available themes
    [string[]] GetThemeNames() {
        return $this._themes.Keys | Sort-Object
    }
    
    # Get current theme name
    [string] GetCurrentTheme() {
        return $this._currentTheme
    }
}