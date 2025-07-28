# ThemedComponent.ps1 - Base class that provides standardized theme color access

class ThemedComponent : FocusableComponent {
    hidden [ThemeManager]$Theme
    hidden [hashtable]$_colorCache = @{}
    
    ThemedComponent() : base() {
    }
    
    [void] OnInitialize() {
        $this.Theme = $this.ServiceContainer.GetService("ThemeManager")
        if ($this.Theme) {
            $this.Theme.Subscribe({ $this.OnThemeChanged() })
            $this.OnThemeChanged()
        }
    }
    
    [void] OnThemeChanged() {
        # Clear color cache when theme changes
        $this._colorCache.Clear()
        
        # Call virtual method for derived classes
        $this.UpdateColors()
        
        # Mark for re-render
        $this.Invalidate()
    }
    
    # Virtual method for derived classes to override
    [void] UpdateColors() {
        # Override in derived classes to update component-specific colors
    }
    
    # Get color with automatic fallback and caching
    [string] GetThemeColor([string]$key) {
        if ($this._colorCache.ContainsKey($key)) {
            return $this._colorCache[$key]
        }
        
        $color = [ThemeStandardizer]::GetColorSafe($this.Theme, $key)
        $this._colorCache[$key] = $color
        return $color
    }
    
    # Get background color with automatic fallback and caching
    [string] GetThemeBgColor([string]$key) {
        $bgKey = "$key.bg"
        if ($this._colorCache.ContainsKey($bgKey)) {
            return $this._colorCache[$bgKey]
        }
        
        # First try to get the color normally
        $rgb = $this.Theme.GetRGB($key)
        if (-not $rgb) {
            # Try with standardized key
            $standardKey = $key
            if ([ThemeStandardizer]::KeyMappings.ContainsKey($key)) {
                $standardKey = [ThemeStandardizer]::KeyMappings[$key]
                $rgb = $this.Theme.GetRGB($standardKey)
            }
            
            # Try fallback chain
            if (-not $rgb -and [ThemeStandardizer]::FallbackChains.ContainsKey($standardKey)) {
                foreach ($fallbackKey in [ThemeStandardizer]::FallbackChains[$standardKey]) {
                    $rgb = $this.Theme.GetRGB($fallbackKey)
                    if ($rgb) { break }
                }
            }
        }
        
        # Convert to background color
        if ($rgb) {
            $bgColor = [VT]::RGBBG($rgb[0], $rgb[1], $rgb[2])
            $this._colorCache[$bgKey] = $bgColor
            return $bgColor
        }
        
        return ""
    }
    
    # Common color getters with standardized keys
    [string] GetTextColor() { return $this.GetThemeColor("text.primary") }
    [string] GetSecondaryTextColor() { return $this.GetThemeColor("text.secondary") }
    [string] GetDisabledTextColor() { return $this.GetThemeColor("text.disabled") }
    [string] GetHeadingColor() { return $this.GetThemeColor("text.heading") }
    
    [string] GetBackgroundColor() { return $this.GetThemeBgColor("surface.background") }
    [string] GetElevatedBackgroundColor() { return $this.GetThemeBgColor("surface.elevated") }
    [string] GetDialogBackgroundColor() { return $this.GetThemeBgColor("surface.dialog") }
    
    [string] GetBorderColor() { return $this.GetThemeColor("border.normal") }
    [string] GetFocusedBorderColor() { return $this.GetThemeColor("border.focused") }
    
    [string] GetPrimaryColor() { return $this.GetThemeColor("color.primary") }
    [string] GetSecondaryColor() { return $this.GetThemeColor("color.secondary") }
    
    [string] GetSelectedBackgroundColor() { return $this.GetThemeBgColor("state.selected") }
    [string] GetHoverBackgroundColor() { return $this.GetThemeBgColor("state.hover") }
    [string] GetFocusedBackgroundColor() { return $this.GetThemeBgColor("state.focused") }
    
    [string] GetSuccessColor() { return $this.GetThemeColor("status.success") }
    [string] GetWarningColor() { return $this.GetThemeColor("status.warning") }
    [string] GetErrorColor() { return $this.GetThemeColor("status.error") }
    [string] GetInfoColor() { return $this.GetThemeColor("status.info") }
}