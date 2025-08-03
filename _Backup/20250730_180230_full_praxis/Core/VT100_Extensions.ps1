# VT100_Extensions.ps1 - Extensions to VT100 for proper color management

class VTX {
    # Reset only foreground color, preserving background
    static [string] ResetForeground() {
        return "`e[39m"  # Default foreground color
    }
    
    # Reset only background color, preserving foreground
    static [string] ResetBackground() {
        return "`e[49m"  # Default background color
    }
    
    # Reset to theme colors instead of terminal defaults
    static [string] ResetToTheme([ThemeManager]$theme) {
        if (-not $theme) { return [VT]::Reset() }
        
        $sb = [System.Text.StringBuilder]::new()
        
        # Get theme colors
        $fgRgb = $theme.GetRGB("text.primary")
        $bgRgb = $theme.GetRGB("surface.background")
        
        if ($fgRgb) {
            $sb.Append([VT]::RGB($fgRgb[0], $fgRgb[1], $fgRgb[2]))
        }
        
        if ($bgRgb) {
            $sb.Append([VT]::RGBBG($bgRgb[0], $bgRgb[1], $bgRgb[2]))
        }
        
        return $sb.ToString()
    }
    
    # Get reset sequence with specific theme colors
    static [string] ThemedReset([string]$fgColor, [string]$bgColor) {
        return $fgColor + $bgColor
    }
}