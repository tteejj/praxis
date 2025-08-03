# ThemeValidator.ps1 - Validates themes and prevents hardcoded fallbacks

class ThemeValidator {
    # Required keys that MUST exist in every theme
    static [string[]]$RequiredKeys = @(
        # Text colors
        "text.primary", "text.secondary", "text.disabled", "text.heading", "text.placeholder",
        
        # Input field colors
        "input.text", "input.placeholder",
        
        # Surface colors  
        "surface.background", "surface.elevated", "surface.dialog",
        
        # Brand colors
        "color.primary", "color.secondary",
        
        # Status colors
        "status.success", "status.warning", "status.error", "status.info",
        
        # Border colors
        "border.normal", "border.focused", "border.dialog", "border.input", "border.input.focused",
        
        # Interaction states
        "state.selected", "state.hover", "state.pressed", "state.focused",
        
        # Focus system
        "focus.reverse.background", "focus.reverse.text",
        
        # Menu system
        "menu.background", "menu.background.selected", "menu.text", "menu.text.selected",
        
        # List system
        "list.header.text", "list.header.background"
    )
    
    # Create an obvious "ERROR THEME" that makes it clear something is wrong
    static [hashtable] GetErrorTheme() {
        return @{
            # ERROR THEME - Bright magenta/yellow to make problems obvious
            "text.primary" = @(255, 0, 255)           # Bright magenta text
            "text.secondary" = @(255, 255, 0)         # Bright yellow text  
            "text.disabled" = @(128, 0, 128)          # Dark magenta
            "text.heading" = @(255, 255, 255)         # White headings
            "text.placeholder" = @(200, 0, 200)       # Light magenta
            
            "input.text" = @(255, 255, 255)           # White input text
            "input.placeholder" = @(200, 0, 200)      # Light magenta placeholders
            
            "surface.background" = @(50, 0, 50)       # Dark magenta background
            "surface.elevated" = @(80, 0, 80)         # Slightly lighter magenta
            "surface.dialog" = @(100, 0, 100)         # Dialog magenta
            
            "color.primary" = @(255, 255, 0)          # Bright yellow primary
            "color.secondary" = @(255, 0, 255)        # Bright magenta secondary
            
            "status.success" = @(0, 255, 0)           # Bright green
            "status.warning" = @(255, 255, 0)         # Bright yellow
            "status.error" = @(255, 0, 0)             # Bright red
            "status.info" = @(0, 255, 255)            # Bright cyan
            
            "border.normal" = @(255, 255, 0)          # Yellow borders
            "border.focused" = @(255, 0, 255)         # Magenta focused borders
            "border.dialog" = @(255, 255, 0)          # Yellow dialog borders
            "border.input" = @(255, 255, 0)           # Yellow input borders
            "border.input.focused" = @(255, 0, 255)   # Magenta focused input
            
            "state.selected" = @(255, 255, 0)         # Yellow selection
            "state.hover" = @(200, 0, 200)            # Light magenta hover
            "state.pressed" = @(150, 0, 150)          # Darker magenta pressed
            "state.focused" = @(255, 0, 255)          # Magenta focus
            
            "focus.reverse.background" = @(255, 255, 0) # Yellow focus background
            "focus.reverse.text" = @(0, 0, 0)         # Black focus text
            
            "menu.background" = @(80, 0, 80)          # Dark magenta menu
            "menu.background.selected" = @(255, 255, 0) # Yellow selected menu
            "menu.text" = @(255, 0, 255)              # Magenta menu text
            "menu.text.selected" = @(0, 0, 0)         # Black selected text
            
            "list.header.text" = @(255, 255, 255)     # White header text
            "list.header.background" = @(150, 0, 150) # Dark magenta header bg
        }
    }
    
    # Validate a theme and return validation results
    static [hashtable] ValidateTheme([hashtable]$theme) {
        $results = @{
            IsValid = $true
            MissingKeys = @()
            InvalidValues = @()
            Warnings = @()
        }
        
        # Check for missing required keys
        foreach ($key in [ThemeValidator]::RequiredKeys) {
            if (-not $theme.ContainsKey($key)) {
                $results.MissingKeys += $key
                $results.IsValid = $false
            }
        }
        
        # Check for invalid color values
        foreach ($key in $theme.Keys) {
            $value = $theme[$key]
            if ($value -isnot [array] -or $value.Length -ne 3) {
                $results.InvalidValues += @{ Key = $key; Value = $value; Reason = "Must be [r,g,b] array" }
                $results.IsValid = $false
                continue
            }
            
            # Check RGB values are 0-255
            for ($i = 0; $i -lt 3; $i++) {
                if ($value[$i] -lt 0 -or $value[$i] -gt 255) {
                    $results.InvalidValues += @{ Key = $key; Value = $value; Reason = "RGB values must be 0-255" }
                    $results.IsValid = $false
                    break
                }
            }
        }
        
        return $results
    }
    
    # Get a validated theme - returns ERROR THEME if validation fails
    static [hashtable] GetValidatedTheme([hashtable]$theme, [string]$themeName = "Unknown") {
        $validation = [ThemeValidator]::ValidateTheme($theme)
        
        if ($validation.IsValid) {
            if ($global:Logger) {
                $global:Logger.Info("Theme '$themeName' passed validation")
            }
            return $theme
        }
        
        # Log validation errors
        if ($global:Logger) {
            $global:Logger.Error("Theme '$themeName' FAILED validation!")
            foreach ($key in $validation.MissingKeys) {
                $global:Logger.Error("  Missing required key: $key")
            }
            foreach ($invalid in $validation.InvalidValues) {
                $global:Logger.Error("  Invalid value for '$($invalid.Key)': $($invalid.Reason)")
            }
            $global:Logger.Warning("Falling back to ERROR THEME - this should NEVER be used in production!")
        }
        
        # Console warning too
        Write-Host "🚨 THEME VALIDATION FAILED: $themeName" -ForegroundColor Red
        Write-Host "🚨 Using ERROR THEME - fix your theme!" -ForegroundColor Red
        
        return [ThemeValidator]::GetErrorTheme()
    }
    
    # Remove all hardcoded fallbacks from a component's GetColor calls
    static [string] StripHardcodedFallbacks([string]$componentCode) {
        # Remove patterns like: if ($color) { $color } else { [VT]::RGB(128,128,128) }
        $patterns = @(
            'if\s*\(\$\w+\)\s*\{\s*\$\w+\s*\}\s*else\s*\{\s*\[VT\]::(RGB|RGBBG)\([^)]+\)\s*\}',
            '\[VT\]::(RGB|RGBBG)\s*\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)',
            '# [^`n]*fallback[^`n]*'
        )
        
        $cleaned = $componentCode
        foreach ($pattern in $patterns) {
            $cleaned = $cleaned -replace $pattern, '# HARDCODED FALLBACK REMOVED BY ThemeValidator'
        }
        
        return $cleaned
    }
}