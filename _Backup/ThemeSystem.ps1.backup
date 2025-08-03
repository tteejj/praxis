# ThemeSystem.ps1 - Enhanced theme system with semantic colors and live editing

class ThemeSystem {
    # Core semantic color tokens
    static [hashtable]$SemanticTokens = @{
        # Base colors - these are the primitives
        "primary" = "Main brand/accent color"
        "secondary" = "Secondary accent color"
        "background" = "Main background"
        "surface" = "Elevated surface (cards, dialogs)"
        "error" = "Error states"
        "warning" = "Warning states"
        "success" = "Success states"
        "info" = "Informational"
        
        # Content colors
        "on-primary" = "Text/icons on primary"
        "on-secondary" = "Text/icons on secondary"
        "on-background" = "Text/icons on background"
        "on-surface" = "Text/icons on surface"
        "on-error" = "Text/icons on error"
        
        # State variations
        "hover" = "Hover state modifier"
        "pressed" = "Pressed state modifier"
        "disabled" = "Disabled state modifier"
        "focus" = "Focus state modifier"
        "selected" = "Selected state modifier"
    }
    
    # Component mappings to semantic colors
    static [hashtable]$ComponentMappings = @{
        # Buttons
        "button.background" = "surface"
        "button.foreground" = "on-surface"
        "button.hover.background" = "surface.hover"
        "button.pressed.background" = "surface.pressed"
        "button.focused.background" = "primary"
        "button.focused.foreground" = "on-primary"
        "button.disabled.background" = "surface.disabled"
        "button.disabled.foreground" = "on-surface.disabled"
        
        # Inputs
        "input.background" = "surface"
        "input.foreground" = "on-surface"
        "input.border" = "on-surface.disabled"
        "input.focused.border" = "primary"
        "input.error.border" = "error"
        
        # Lists/Menus
        "list.background" = "background"
        "list.foreground" = "on-background"
        "list.selected.background" = "primary"
        "list.selected.foreground" = "on-primary"
        "list.hover.background" = "surface"
        
        # Dialogs
        "dialog.background" = "surface"
        "dialog.foreground" = "on-surface"
        "dialog.border" = "primary"
        "dialog.title" = "primary"
        
        # Status
        "status.error" = "error"
        "status.warning" = "warning"
        "status.success" = "success"
        "status.info" = "info"
    }
    
    # Style modifiers beyond color
    static [hashtable]$StyleModifiers = @{
        "bold" = [VT]::Bold()
        "dim" = [VT]::Dim()
        "underline" = [VT]::Underline()
        "blink" = "`e[5m"
        "reverse" = "`e[7m"
        "italic" = "`e[3m"
    }
}

class EnhancedThemeManager : ThemeManager {
    hidden [hashtable]$_baseThemes = @{}  # Base themes for inheritance
    hidden [hashtable]$_userTheme = @{}   # User customizations
    hidden [hashtable]$_semanticCache = @{} # Cached semantic lookups
    hidden [bool]$_liveEditMode = $false
    hidden [ConfigurationService]$_configService
    
    EnhancedThemeManager() : base() {
        $this.InitializeBaseThemes()
    }
    
    [void] InitializeBaseThemes() {
        # Define base theme with semantic colors
        $baseLight = @{
            # Semantic primitives
            "primary" = @(0, 122, 255)        # Blue
            "secondary" = @(255, 149, 0)      # Orange
            "background" = @(255, 255, 255)   # White
            "surface" = @(245, 245, 247)      # Light gray
            "error" = @(255, 59, 48)          # Red
            "warning" = @(255, 204, 0)        # Yellow
            "success" = @(52, 199, 89)        # Green
            "info" = @(0, 122, 255)           # Blue
            
            # Content colors
            "on-primary" = @(255, 255, 255)
            "on-secondary" = @(255, 255, 255)
            "on-background" = @(0, 0, 0)
            "on-surface" = @(0, 0, 0)
            "on-error" = @(255, 255, 255)
            
            # State modifiers (as multipliers)
            "hover.factor" = 0.9
            "pressed.factor" = 0.8
            "disabled.factor" = 0.5
            "focus.factor" = 1.1
            "selected.factor" = 1.0
        }
        
        $baseDark = @{
            # Semantic primitives
            "primary" = @(10, 132, 255)       # Blue
            "secondary" = @(255, 159, 10)     # Orange
            "background" = @(0, 0, 0)         # Black
            "surface" = @(28, 28, 30)         # Dark gray
            "error" = @(255, 69, 58)          # Red
            "warning" = @(255, 214, 10)       # Yellow
            "success" = @(48, 209, 88)        # Green
            "info" = @(10, 132, 255)          # Blue
            
            # Content colors
            "on-primary" = @(255, 255, 255)
            "on-secondary" = @(255, 255, 255)
            "on-background" = @(255, 255, 255)
            "on-surface" = @(255, 255, 255)
            "on-error" = @(255, 255, 255)
            
            # State modifiers
            "hover.factor" = 1.2
            "pressed.factor" = 1.4
            "disabled.factor" = 0.4
            "focus.factor" = 1.3
            "selected.factor" = 1.0
        }
        
        $this._baseThemes["light"] = $baseLight
        $this._baseThemes["dark"] = $baseDark
        
        # Create actual themes from base + existing theme data
        $this.CreateThemeFromBase("default", "dark", $this._themes["default"])
        $this.CreateThemeFromBase("matrix", "dark", $this._themes["matrix"])
        $this.CreateThemeFromBase("amber", "dark", $this._themes["amber"])
    }
    
    # Create a theme by extending a base theme
    [void] CreateThemeFromBase([string]$name, [string]$baseName, [hashtable]$overrides = @{}) {
        if (-not $this._baseThemes.ContainsKey($baseName)) {
            throw "Base theme '$baseName' not found"
        }
        
        $baseTheme = $this._baseThemes[$baseName].Clone()
        $theme = $this.MergeThemes($baseTheme, $overrides)
        
        # Expand semantic colors to component colors
        $expandedTheme = $this.ExpandSemanticColors($theme)
        
        $this._themes[$name] = $expandedTheme
    }
    
    # Expand semantic colors to all component mappings
    hidden [hashtable] ExpandSemanticColors([hashtable]$theme) {
        $expanded = $theme.Clone()
        
        # First, generate state variations
        foreach ($key in @($theme.Keys)) {
            if ($theme[$key] -is [array] -and $theme[$key].Count -eq 3) {
                $rgb = $theme[$key]
                
                # Generate state variations if factors exist
                foreach ($state in @("hover", "pressed", "disabled", "focus")) {
                    $factorKey = "$state.factor"
                    if ($theme.ContainsKey($factorKey)) {
                        $factor = $theme[$factorKey]
                        $stateKey = "$key.$state"
                        
                        if (-not $expanded.ContainsKey($stateKey)) {
                            $expanded[$stateKey] = $this.ApplyColorModifier($rgb, $factor)
                        }
                    }
                }
            }
        }
        
        # Then map semantic colors to components
        foreach ($mapping in [ThemeSystem]::ComponentMappings.GetEnumerator()) {
            $componentKey = $mapping.Key
            $semanticKey = $mapping.Value
            
            # Resolve nested semantic references
            $resolvedColor = $this.ResolveSemanticColor($semanticKey, $expanded)
            if ($resolvedColor) {
                $expanded[$componentKey] = $resolvedColor
            }
        }
        
        return $expanded
    }
    
    # Resolve a semantic color reference
    hidden [array] ResolveSemanticColor([string]$key, [hashtable]$theme) {
        # Direct lookup
        if ($theme.ContainsKey($key)) {
            return $theme[$key]
        }
        
        # Handle dot notation (e.g., "primary.hover")
        $parts = $key -split '\.'
        if ($parts.Count -eq 2) {
            $baseKey = $parts[0]
            $modifier = $parts[1]
            
            if ($theme.ContainsKey($baseKey) -and $theme.ContainsKey("$modifier.factor")) {
                $baseColor = $theme[$baseKey]
                $factor = $theme["$modifier.factor"]
                return $this.ApplyColorModifier($baseColor, $factor)
            }
        }
        
        return $null
    }
    
    # Apply a modifier factor to a color
    hidden [array] ApplyColorModifier([array]$rgb, [double]$factor) {
        $r = [int]([Math]::Min(255, [Math]::Max(0, $rgb[0] * $factor)))
        $g = [int]([Math]::Min(255, [Math]::Max(0, $rgb[1] * $factor)))
        $b = [int]([Math]::Min(255, [Math]::Max(0, $rgb[2] * $factor)))
        return @($r, $g, $b)
    }
    
    # Merge two theme hashtables
    hidden [hashtable] MergeThemes([hashtable]$base, [hashtable]$overrides) {
        $merged = $base.Clone()
        foreach ($key in $overrides.Keys) {
            $merged[$key] = $overrides[$key]
        }
        return $merged
    }
    
    # Get color with style modifiers
    [string] GetStyledColor([string]$colorKey, [string[]]$styles = @()) {
        $color = $this.GetColor($colorKey)
        $result = $color
        
        foreach ($style in $styles) {
            if ([ThemeSystem]::StyleModifiers.ContainsKey($style)) {
                $result += [ThemeSystem]::StyleModifiers[$style]
            }
        }
        
        return $result
    }
    
    # Live theme editing
    [void] EnableLiveEdit() {
        $this._liveEditMode = $true
        $this._configService = $this.ServiceContainer.GetService('ConfigurationService')
        
        # Load user customizations
        $userTheme = $this._configService.Get("Theme.UserCustomizations", @{})
        if ($userTheme -is [hashtable]) {
            $this._userTheme = $userTheme
            $this.ApplyUserCustomizations()
        }
    }
    
    # Set a color in live edit mode
    [void] SetLiveColor([string]$key, [int[]]$rgb) {
        if (-not $this._liveEditMode) {
            throw "Live edit mode not enabled"
        }
        
        $this._userTheme[$key] = $rgb
        $this._configService.Set("Theme.UserCustomizations.$key", $rgb)
        
        # Apply immediately
        $this.ApplyUserCustomizations()
        
        # Notify all components
        if ($this.EventBus) {
            $this.EventBus.Publish('theme.colorChanged', @{
                Key = $key
                Color = $rgb
            })
        }
    }
    
    # Apply user customizations over current theme
    hidden [void] ApplyUserCustomizations() {
        foreach ($key in $this._userTheme.Keys) {
            $this._themes[$this._currentTheme][$key] = $this._userTheme[$key]
        }
        $this.RebuildCache()
    }
    
    # Export theme to JSON
    [string] ExportTheme([string]$themeName) {
        if (-not $this._themes.ContainsKey($themeName)) {
            throw "Theme '$themeName' not found"
        }
        
        $theme = $this._themes[$themeName]
        $export = @{
            name = $themeName
            colors = @{}
            metadata = @{
                created = Get-Date -Format "o"
                version = "2.0"
            }
        }
        
        # Only export non-generated colors
        foreach ($key in $theme.Keys) {
            if (-not [ThemeSystem]::ComponentMappings.ContainsKey($key)) {
                $export.colors[$key] = $theme[$key]
            }
        }
        
        return $export | ConvertTo-Json -Depth 10 -Compress:$false
    }
    
    # Import theme from JSON
    [void] ImportTheme([string]$json, [string]$name = $null) {
        $import = $json | ConvertFrom-Json -AsHashtable
        
        $themeName = if ($name) { $name } else { $import.name }
        $colors = $import.colors
        
        # Determine base theme (light or dark)
        $bgLuminance = $this.GetLuminance($colors["background"])
        $baseName = if ($bgLuminance -gt 0.5) { "light" } else { "dark" }
        
        $this.CreateThemeFromBase($themeName, $baseName, $colors)
        
        if ($this._configService) {
            # Save to available themes
            $availableThemes = $this._configService.Get("Theme.AvailableThemes", @())
            if ($availableThemes -notcontains $themeName) {
                $availableThemes += $themeName
                $this._configService.Set("Theme.AvailableThemes", $availableThemes)
            }
        }
    }
    
    # Calculate relative luminance
    hidden [double] GetLuminance([array]$rgb) {
        $r = $rgb[0] / 255.0
        $g = $rgb[1] / 255.0
        $b = $rgb[2] / 255.0
        return 0.2126 * $r + 0.7152 * $g + 0.0722 * $b
    }
    
    # Get contrast ratio between two colors
    [double] GetContrastRatio([string]$color1Key, [string]$color2Key) {
        $rgb1 = $this.GetRGB($color1Key)
        $rgb2 = $this.GetRGB($color2Key)
        
        if (-not $rgb1 -or -not $rgb2) {
            return 0
        }
        
        $lum1 = $this.GetLuminance($rgb1)
        $lum2 = $this.GetLuminance($rgb2)
        
        $lighter = [Math]::Max($lum1, $lum2)
        $darker = [Math]::Min($lum1, $lum2)
        
        return ($lighter + 0.05) / ($darker + 0.05)
    }
    
    # Validate theme accessibility
    [hashtable] ValidateAccessibility() {
        $results = @{
            Passed = @()
            Failed = @()
            Warnings = @()
        }
        
        # Check contrast ratios for key combinations
        $checks = @(
            @{ Foreground = "on-background"; Background = "background"; MinRatio = 4.5; Name = "Main text" }
            @{ Foreground = "on-primary"; Background = "primary"; MinRatio = 4.5; Name = "Primary button text" }
            @{ Foreground = "on-surface"; Background = "surface"; MinRatio = 4.5; Name = "Card text" }
            @{ Foreground = "on-error"; Background = "error"; MinRatio = 4.5; Name = "Error text" }
        )
        
        foreach ($check in $checks) {
            $ratio = $this.GetContrastRatio($check.Foreground, $check.Background)
            
            if ($ratio -ge $check.MinRatio) {
                $results.Passed += "$($check.Name): $([Math]::Round($ratio, 2)):1"
            }
            elseif ($ratio -ge 3.0) {
                $results.Warnings += "$($check.Name): $([Math]::Round($ratio, 2)):1 (Below AA standard)"
            }
            else {
                $results.Failed += "$($check.Name): $([Math]::Round($ratio, 2)):1 (Poor contrast)"
            }
        }
        
        return $results
    }
}