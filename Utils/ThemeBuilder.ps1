# ThemeBuilder.ps1 - Helper for creating new themes easily

class ThemeBuilder {
    [string]$Name
    [hashtable]$Colors = @{}
    [string]$BaseTheme = "dark"
    
    ThemeBuilder([string]$name) {
        $this.Name = $name
    }
    
    # Fluent API for building themes
    [ThemeBuilder] BasedOn([string]$baseTheme) {
        $this.BaseTheme = $baseTheme
        return $this
    }
    
    [ThemeBuilder] WithPrimary([int]$r, [int]$g, [int]$b) {
        $this.Colors["primary"] = @($r, $g, $b)
        return $this
    }
    
    [ThemeBuilder] WithSecondary([int]$r, [int]$g, [int]$b) {
        $this.Colors["secondary"] = @($r, $g, $b)
        return $this
    }
    
    [ThemeBuilder] WithBackground([int]$r, [int]$g, [int]$b) {
        $this.Colors["background"] = @($r, $g, $b)
        return $this
    }
    
    [ThemeBuilder] WithSurface([int]$r, [int]$g, [int]$b) {
        $this.Colors["surface"] = @($r, $g, $b)
        return $this
    }
    
    [ThemeBuilder] WithError([int]$r, [int]$g, [int]$b) {
        $this.Colors["error"] = @($r, $g, $b)
        return $this
    }
    
    [ThemeBuilder] WithWarning([int]$r, [int]$g, [int]$b) {
        $this.Colors["warning"] = @($r, $g, $b)
        return $this
    }
    
    [ThemeBuilder] WithSuccess([int]$r, [int]$g, [int]$b) {
        $this.Colors["success"] = @($r, $g, $b)
        return $this
    }
    
    [ThemeBuilder] WithColor([string]$key, [int]$r, [int]$g, [int]$b) {
        $this.Colors[$key] = @($r, $g, $b)
        return $this
    }
    
    # Generate contrasting text colors automatically
    [ThemeBuilder] AutoGenerateTextColors() {
        $keys = @($this.Colors.Keys)
        foreach ($key in $keys) {
            if ($key -notmatch "^on-") {
                $rgb = $this.Colors[$key]
                $luminance = $this.GetLuminance($rgb)
                
                # Generate contrasting text color
                $textKey = "on-$key"
                if (-not $this.Colors.ContainsKey($textKey)) {
                    if ($luminance -gt 0.5) {
                        # Light background, use dark text
                        $this.Colors[$textKey] = @(0, 0, 0)
                    } else {
                        # Dark background, use light text
                        $this.Colors[$textKey] = @(255, 255, 255)
                    }
                }
            }
        }
        return $this
    }
    
    hidden [double] GetLuminance([array]$rgb) {
        $r = $rgb[0] / 255.0
        $g = $rgb[1] / 255.0
        $b = $rgb[2] / 255.0
        return 0.2126 * $r + 0.7152 * $g + 0.0722 * $b
    }
    
    # Build and register the theme
    [void] Build() {
        $themeManager = $global:ServiceContainer.GetService('ThemeManager')
        if ($themeManager -is [EnhancedThemeManager]) {
            $themeManager.CreateThemeFromBase($this.Name, $this.BaseTheme, $this.Colors)
        } else {
            # Fallback for standard ThemeManager
            $themeManager.RegisterTheme($this.Name, $this.Colors)
        }
    }
    
    # Export theme definition
    [string] Export() {
        $export = @{
            name = $this.Name
            base = $this.BaseTheme
            colors = $this.Colors
        }
        return $export | ConvertTo-Json -Depth 10 -Compress:$false
    }
}

# Predefined theme templates
class ThemeTemplates {
    # High contrast theme for accessibility
    static [void] CreateHighContrast() {
        [ThemeBuilder]::new("high-contrast").
            BasedOn("dark").
            WithPrimary(255, 255, 0).      # Yellow
            WithBackground(0, 0, 0).        # Pure black
            WithSurface(20, 20, 20).        # Very dark gray
            WithError(255, 0, 0).           # Pure red
            WithWarning(255, 165, 0).       # Orange
            WithSuccess(0, 255, 0).         # Pure green
            WithColor("border", 255, 255, 255).  # White borders
            AutoGenerateTextColors().
            Build()
    }
    
    # Solarized Dark
    static [void] CreateSolarizedDark() {
        [ThemeBuilder]::new("solarized-dark").
            BasedOn("dark").
            WithPrimary(38, 139, 210).      # Blue
            WithSecondary(203, 75, 22).     # Orange
            WithBackground(0, 43, 54).       # Base03
            WithSurface(7, 54, 66).          # Base02
            WithError(220, 50, 47).          # Red
            WithWarning(181, 137, 0).        # Yellow
            WithSuccess(133, 153, 0).        # Green
            WithColor("on-background", 131, 148, 150).  # Base0
            WithColor("on-surface", 147, 161, 161).     # Base1
            Build()
    }
    
    # Dracula
    static [void] CreateDracula() {
        [ThemeBuilder]::new("dracula").
            BasedOn("dark").
            WithPrimary(139, 233, 253).     # Cyan
            WithSecondary(255, 121, 198).   # Pink
            WithBackground(40, 42, 54).      # Background
            WithSurface(68, 71, 90).         # Current Line
            WithError(255, 85, 85).          # Red
            WithWarning(241, 250, 140).      # Yellow
            WithSuccess(80, 250, 123).       # Green
            WithColor("on-background", 248, 248, 242).  # Foreground
            WithColor("border", 98, 114, 164).          # Purple
            Build()
    }
    
    # Nord
    static [void] CreateNord() {
        [ThemeBuilder]::new("nord").
            BasedOn("dark").
            WithPrimary(136, 192, 208).     # Nord8 - Frost cyan
            WithSecondary(129, 161, 193).   # Nord9 - Frost blue
            WithBackground(46, 52, 64).      # Nord0 - Polar Night
            WithSurface(59, 66, 82).         # Nord1
            WithError(191, 97, 106).         # Nord11 - Aurora red
            WithWarning(235, 203, 139).      # Nord13 - Aurora yellow
            WithSuccess(163, 190, 140).      # Nord14 - Aurora green
            WithColor("on-background", 216, 222, 233).  # Nord4 - Snow Storm
            WithColor("border", 76, 86, 106).           # Nord2
            Build()
    }
    
    # Monokai
    static [void] CreateMonokai() {
        [ThemeBuilder]::new("monokai").
            BasedOn("dark").
            WithPrimary(102, 217, 239).     # Cyan
            WithSecondary(249, 38, 114).    # Pink
            WithBackground(39, 40, 34).      # Background
            WithSurface(62, 61, 50).         # Line Highlight
            WithError(249, 38, 114).         # Pink (also error)
            WithWarning(230, 219, 116).      # Yellow
            WithSuccess(166, 226, 46).       # Green
            WithColor("on-background", 248, 248, 242).  # Foreground
            WithColor("border", 117, 113, 94).          # Comment gray
            Build()
    }
}