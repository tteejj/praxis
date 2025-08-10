# AppThemeManager.ps1 - Centralized theme system for entire SimpleTaskPro application
# Replaces hardcoded colors scattered across TaskListScreen, ProjectSettingsDialog, etc.
# Enables single-hotkey theme switching for consistent application-wide styling

class AppThemeManager {
    # Current active theme - shared across ALL screens and dialogs
    static [hashtable]$CurrentTheme = @{
        # Primary UI colors
        Header = @(100, 150, 255)      # Blue - headers, titles
        Field = @(255, 215, 0)         # Gold - field labels, form elements  
        Value = @(250, 248, 240)       # Warm white - user content, data
        Button = @(80, 200, 120)       # Green - buttons, actions
        
        # Content colors
        Text = @(180, 180, 180)        # Light gray - general text
        Muted = @(120, 120, 120)       # Medium gray - secondary info
        Accent = @(255, 215, 0)        # Gold - highlights, current items
        
        # Status colors (preserve existing task system)
        High = @(255, 100, 100)        # Red - high priority
        Medium = @(255, 165, 0)        # Orange - medium priority  
        Low = @(80, 200, 120)          # Green - low priority
        Today = @(255, 215, 0)         # Gold - today tasks
        
        # Background colors
        Selected = @(45, 45, 55)       # Dark - selected item background
        EvenRow = @(25, 25, 30)        # Subtle - alternate row background
        
        # UI chrome colors
        StatusBar = @(60, 60, 70)      # Dark gray - status bar
        Browser = @(160, 160, 160)     # Medium gray - file browser
    }
    
    # Available theme presets - easy to add more
    static [hashtable]$ThemePresets = @{
        "Default" = @{
            Header = @(100, 150, 255); Field = @(255, 215, 0); Value = @(250, 248, 240)
            Button = @(80, 200, 120); Text = @(180, 180, 180); Muted = @(120, 120, 120)
            Accent = @(255, 215, 0); High = @(255, 100, 100); Medium = @(255, 165, 0)
            Low = @(80, 200, 120); Today = @(255, 215, 0); Selected = @(45, 45, 55)
            EvenRow = @(25, 25, 30); StatusBar = @(60, 60, 70); Browser = @(160, 160, 160)
        }
        "Warm" = @{
            Header = @(255, 140, 100); Field = @(255, 200, 120); Value = @(255, 248, 240)
            Button = @(200, 160, 100); Text = @(200, 180, 160); Muted = @(140, 130, 120)
            Accent = @(255, 180, 100); High = @(255, 120, 100); Medium = @(255, 180, 100)
            Low = @(180, 200, 120); Today = @(255, 200, 100); Selected = @(60, 45, 35)
            EvenRow = @(35, 30, 25); StatusBar = @(70, 60, 50); Browser = @(160, 150, 140)
        }
        "Cool" = @{
            Header = @(100, 180, 220); Field = @(120, 200, 255); Value = @(240, 248, 255)
            Button = @(100, 180, 160); Text = @(160, 180, 200); Muted = @(100, 120, 140)
            Accent = @(120, 180, 255); High = @(255, 120, 140); Medium = @(180, 160, 255)
            Low = @(100, 200, 180); Today = @(140, 200, 255); Selected = @(35, 45, 60)
            EvenRow = @(25, 30, 40); StatusBar = @(50, 60, 80); Browser = @(140, 160, 180)
        }
    }
    
    static [string[]]$ThemeNames = @("Default", "Warm", "Cool")
    static [int]$CurrentThemeIndex = 0
    
    # Get VT100 color string - unified method for all screens
    static [string] GetColor([string]$colorType) {
        $rgb = [AppThemeManager]::CurrentTheme[$colorType]
        if (-not $rgb) {
            # Fallback to default text color if type not found
            $rgb = [AppThemeManager]::CurrentTheme["Text"]
        }
        return [VT]::RGB($rgb[0], $rgb[1], $rgb[2])
    }
    
    # Get background color string
    static [string] GetBackgroundColor([string]$colorType) {
        $rgb = [AppThemeManager]::CurrentTheme[$colorType]
        if (-not $rgb) {
            return ""  # No background if type not found
        }
        return [VT]::RGBBG($rgb[0], $rgb[1], $rgb[2])
    }
    
    # Apply complete theme preset - affects entire application
    static [void] ApplyTheme([string]$themeName) {
        if ([AppThemeManager]::ThemePresets.ContainsKey($themeName)) {
            [AppThemeManager]::CurrentTheme = [AppThemeManager]::ThemePresets[$themeName].Clone()
            [AppThemeManager]::CurrentThemeIndex = [AppThemeManager]::ThemeNames.IndexOf($themeName)
        }
    }
    
    # Cycle to next theme - for hotkey support
    static [string] CycleTheme() {
        [AppThemeManager]::CurrentThemeIndex = ([AppThemeManager]::CurrentThemeIndex + 1) % [AppThemeManager]::ThemeNames.Count
        $newTheme = [AppThemeManager]::ThemeNames[[AppThemeManager]::CurrentThemeIndex]
        [AppThemeManager]::ApplyTheme($newTheme)
        return $newTheme
    }
    
    # Get current theme name
    static [string] GetCurrentThemeName() {
        return [AppThemeManager]::ThemeNames[[AppThemeManager]::CurrentThemeIndex]
    }
    
    # Get pillbox color - matches current header theme
    static [string] GetPillboxColor() {
        return [AppThemeManager]::GetColor("Header")
    }
}