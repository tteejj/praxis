# ThemeStandardizer.ps1 - Utilities for standardizing theme key naming and fallback patterns

class ThemeStandardizer {
    # Standard theme key mapping - maps legacy/inconsistent keys to standard ones
    static [hashtable] $KeyMappings = @{
        # Text colors
        "foreground" = "text.primary"
        "normal" = "text.primary"
        "text" = "text.primary"
        "disabled" = "text.disabled"
        "muted" = "text.secondary"
        
        # Surface colors
        "background" = "surface.background"
        "surface" = "surface.elevated"
        
        # Interactive states
        "selected" = "state.selected"
        "hover" = "state.hover"
        "pressed" = "state.pressed"
        "focused" = "state.focused"
        
        # Border colors
        "border" = "border.normal"
        "border.focused" = "border.focused"
        "border.normal" = "border.normal"
        
        # Component-specific standardization
        "title" = "text.heading"
        "accent" = "color.primary"
        "primary" = "color.primary"
        "secondary" = "color.secondary"
        
        # Status colors (these are already well-named)
        "success" = "status.success"
        "warning" = "status.warning"
        "error" = "status.error"
        "info" = "status.info"
        
        # Dialog-specific
        "dialog.text" = "text.primary"
        "dialog.background" = "surface.dialog"
        "dialog.border" = "border.dialog"
        "dialog.title" = "text.heading"
        
        # Input-specific  
        "input.placeholder" = "text.placeholder"
        "input.border" = "border.input"
        "input.focused.border" = "border.input.focused"
        
        # File browser
        "directory" = "file.directory"
        "file" = "file.normal"
        
        # Editor-specific
        "linenumber" = "editor.linenumber"
        "cursor" = "editor.cursor"
        "cursor.text" = "editor.cursor.text"
        "selection" = "editor.selection"
        "selection.text" = "editor.selection.text"
        "status" = "editor.status"
    }
    
    # Fallback hierarchy - if a key isn't found, try these fallbacks in order
    static [hashtable] $FallbackChains = @{
        # Text fallbacks
        "text.secondary" = @("text.primary", "foreground")
        "text.disabled" = @("text.secondary", "text.primary")
        "text.placeholder" = @("text.disabled", "text.secondary")
        "text.heading" = @("text.primary", "color.primary")
        
        # Surface fallbacks
        "surface.elevated" = @("surface.background", "background")
        "surface.dialog" = @("surface.elevated", "surface.background")
        
        # Border fallbacks
        "border.focused" = @("color.primary", "border.normal")
        "border.dialog" = @("border.normal", "border")
        "border.input" = @("border.normal", "border")
        "border.input.focused" = @("border.focused", "color.primary")
        
        # State fallbacks
        "state.hover" = @("state.selected", "color.primary")
        "state.pressed" = @("state.hover", "color.primary")
        "state.focused" = @("color.primary", "border.focused")
        
        # Component fallbacks
        "file.directory" = @("color.primary", "text.primary")
        "file.normal" = @("text.primary", "foreground")
        
        # Editor fallbacks
        "editor.linenumber" = @("text.disabled", "text.secondary")
        "editor.cursor" = @("text.primary", "foreground")
        "editor.cursor.text" = @("surface.background", "background")
        "editor.selection" = @("state.selected", "color.primary")
        "editor.selection.text" = @("text.primary", "surface.background")
        "editor.status" = @("text.secondary", "text.primary")
    }
    
    # Enhanced GetColor method with automatic fallbacks and key mapping
    static [string] GetColorSafe([object]$themeManager, [string]$key) {
        if (-not $themeManager) {
            return ""
        }
        
        # First try the key as-is
        $color = $themeManager.GetColor($key)
        if ($color -and $color -ne "") {
            return $color
        }
        
        # Try mapped key if one exists
        if ([ThemeStandardizer]::KeyMappings.ContainsKey($key)) {
            $mappedKey = [ThemeStandardizer]::KeyMappings[$key]
            $color = $themeManager.GetColor($mappedKey)
            if ($color -and $color -ne "") {
                return $color
            }
            $key = $mappedKey  # Use mapped key for fallback chain
        }
        
        # Try fallback chain
        if ([ThemeStandardizer]::FallbackChains.ContainsKey($key)) {
            foreach ($fallbackKey in [ThemeStandardizer]::FallbackChains[$key]) {
                $color = $themeManager.GetColor($fallbackKey)
                if ($color -and $color -ne "") {
                    return $color
                }
            }
        }
        
        # Final fallbacks based on key patterns
        if ($key -match "^text\.") {
            return $themeManager.GetColor('text.primary')
        } elseif ($key -match "^surface\.") {
            return $themeManager.GetColor('surface.background')
        } elseif ($key -match "^border\.") {
            return $themeManager.GetColor('border.normal')
        } elseif ($key -match "^color\.") {
            return $themeManager.GetColor('color.primary')
        }
        
        # Last resort - return empty string
        return ""
    }
    
    # Method to update a theme to use standardized keys
    static [hashtable] StandardizeTheme([hashtable]$theme) {
        $standardized = @{}
        
        # Copy existing keys
        foreach ($key in $theme.Keys) {
            $standardized[$key] = $theme[$key]
        }
        
        # Add standardized equivalents
        foreach ($legacyKey in [ThemeStandardizer]::KeyMappings.Keys) {
            if ($theme.ContainsKey($legacyKey)) {
                $standardKey = [ThemeStandardizer]::KeyMappings[$legacyKey]
                if (-not $standardized.ContainsKey($standardKey)) {
                    $standardized[$standardKey] = $theme[$legacyKey]
                }
            }
        }
        
        return $standardized
    }
    
    # Validate theme completeness and suggest missing keys
    static [string[]] ValidateTheme([hashtable]$theme) {
        $missing = @()
        $requiredKeys = @(
            "text.primary", "text.secondary", "text.disabled", "text.heading",
            "surface.background", "surface.elevated", "surface.dialog",
            "border.normal", "border.focused", "border.dialog",
            "color.primary", "color.secondary",
            "status.success", "status.warning", "status.error", "status.info",
            "state.selected", "state.hover", "state.focused"
        )
        
        foreach ($key in $requiredKeys) {
            if (-not $theme.ContainsKey($key)) {
                $missing += $key
            }
        }
        
        return $missing
    }
}

# Extension method for ThemeManager to use safe color retrieval
class EnhancedThemeManager : ThemeManager {
    # Enhanced GetColor with automatic fallbacks
    [string] GetColorSafe([string]$key) {
        return [ThemeStandardizer]::GetColorSafe($this, $key)
    }
    
    # Apply standardization to current theme
    [void] StandardizeCurrentTheme() {
        $currentTheme = $this._themes[$this._currentTheme]
        $standardized = [ThemeStandardizer]::StandardizeTheme($currentTheme)
        $this._themes[$this._currentTheme] = $standardized
        $this.RebuildCache()
    }
    
    # Validate current theme
    [string[]] ValidateCurrentTheme() {
        $currentTheme = $this._themes[$this._currentTheme]
        return [ThemeStandardizer]::ValidateTheme($currentTheme)
    }
}