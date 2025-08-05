# ColorThemeService.ps1 - Color theme management for CommandLibrary
# Based on TaskPro's visual theming system

class ColorThemeService {
    static [hashtable]$Themes = @{
        "default" = @{
            # Command display colors
            Command = "`e[38;2;250;248;240m"          # Cream white for commands
            CommandSelected = "`e[38;2;255;255;255m"   # Pure white for selected
            CommandHighlight = "`e[38;2;100;149;237m"  # Cornflower blue
            
            # Tag colors
            Tag = "`e[38;2;255;20;147m"                # Deep pink for tags
            TagHighlight = "`e[38;2;255;105;180m"      # Hot pink for highlighted tags
            
            # Group colors
            Group = "`e[38;2;255;165;0m"               # Orange for groups
            GroupHeader = "`e[38;2;255;140;0m"         # Dark orange for headers
            
            # UI elements
            Title = "`e[38;2;135;206;235m"             # Sky blue for titles
            Border = "`e[38;2;169;169;169m"            # Dark gray for borders
            StatusBar = "`e[38;2;105;105;105m"         # Dim gray for status
            Search = "`e[38;2;50;205;50m"              # Lime green for search
            
            # Interactive elements
            Button = "`e[38;2;70;130;180m"             # Steel blue for buttons
            ButtonHover = "`e[38;2;100;149;237m"       # Cornflower blue for hover
            
            # Background colors
            Background = "`e[48;2;25;25;25m"           # Dark background
            SelectionBG = "`e[48;2;60;60;60m"          # Selection background
            PillboxBG = "`e[48;2;45;45;45m"            # Pillbox background
            
            # Status colors
            Success = "`e[38;2;50;205;50m"             # Lime green
            Warning = "`e[38;2;255;165;0m"             # Orange
            Error = "`e[38;2;220;20;60m"               # Crimson
            Info = "`e[38;2;135;206;235m"              # Sky blue
        }
        
        "vibrant" = @{
            # Command display colors
            Command = "`e[38;2;255;255;255m"          # Pure white
            CommandSelected = "`e[38;2;255;215;0m"     # Gold for selected
            CommandHighlight = "`e[38;2;0;191;255m"    # Deep sky blue
            
            # Tag colors
            Tag = "`e[38;2;255;20;147m"                # Deep pink
            TagHighlight = "`e[38;2;255;69;0m"         # Red orange
            
            # Group colors
            Group = "`e[38;2;50;205;50m"               # Lime green
            GroupHeader = "`e[38;2;34;139;34m"         # Forest green
            
            # UI elements
            Title = "`e[38;2;255;215;0m"               # Gold for titles
            Border = "`e[38;2;138;43;226m"             # Blue violet
            StatusBar = "`e[38;2;169;169;169m"         # Dark gray
            Search = "`e[38;2;0;255;127m"              # Spring green
            
            # Interactive elements
            Button = "`e[38;2;138;43;226m"             # Blue violet
            ButtonHover = "`e[38;2;255;20;147m"        # Deep pink
            
            # Background colors
            Background = "`e[48;2;0;0;0m"              # Pure black
            SelectionBG = "`e[48;2;75;0;130m"          # Indigo
            PillboxBG = "`e[48;2;25;25;112m"           # Midnight blue
            
            # Status colors
            Success = "`e[38;2;0;255;0m"               # Lime
            Warning = "`e[38;2;255;140;0m"             # Dark orange
            Error = "`e[38;2;255;0;0m"                 # Red
            Info = "`e[38;2;0;191;255m"                # Deep sky blue
        }
        
        "mono" = @{
            # Command display colors (monochrome theme)
            Command = "`e[38;2;200;200;200m"          # Light gray
            CommandSelected = "`e[38;2;255;255;255m"   # White for selected
            CommandHighlight = "`e[38;2;150;150;150m"  # Medium gray
            
            # Tag colors
            Tag = "`e[38;2;180;180;180m"               # Light gray
            TagHighlight = "`e[38;2;220;220;220m"      # Very light gray
            
            # Group colors
            Group = "`e[38;2;160;160;160m"             # Medium light gray
            GroupHeader = "`e[38;2;140;140;140m"       # Medium gray
            
            # UI elements
            Title = "`e[38;2;240;240;240m"             # Very light gray
            Border = "`e[38;2;100;100;100m"            # Dark gray
            StatusBar = "`e[38;2;120;120;120m"         # Medium dark gray
            Search = "`e[38;2;200;200;200m"            # Light gray
            
            # Interactive elements
            Button = "`e[38;2;180;180;180m"            # Light gray
            ButtonHover = "`e[38;2;220;220;220m"       # Very light gray
            
            # Background colors
            Background = "`e[48;2;0;0;0m"              # Black
            SelectionBG = "`e[48;2;40;40;40m"          # Dark gray
            PillboxBG = "`e[48;2;30;30;30m"            # Very dark gray
            
            # Status colors
            Success = "`e[38;2;180;180;180m"           # Light gray
            Warning = "`e[38;2;160;160;160m"           # Medium light gray
            Error = "`e[38;2;120;120;120m"             # Medium dark gray
            Info = "`e[38;2;200;200;200m"              # Light gray
        }
    }
    
    static [string]$CurrentTheme = "default"
    
    # Get color for specific element
    static [string] GetColor([string]$element) {
        $theme = [ColorThemeService]::Themes[[ColorThemeService]::CurrentTheme]
        if ($theme.ContainsKey($element)) {
            return $theme[$element]
        }
        # Fallback to default theme if element not found
        $defaultTheme = [ColorThemeService]::Themes["default"]
        if ($defaultTheme.ContainsKey($element)) {
            return $defaultTheme[$element]
        }
        return [VT]::Reset()
    }
    
    # Set theme
    static [void] SetTheme([string]$themeName) {
        if ([ColorThemeService]::Themes.ContainsKey($themeName)) {
            [ColorThemeService]::CurrentTheme = $themeName
        } else {
            Write-Warning "Theme '$themeName' not found. Available themes: $([ColorThemeService]::Themes.Keys -join ', ')"
        }
    }
    
    # Get available themes
    static [string[]] GetAvailableThemes() {
        return [ColorThemeService]::Themes.Keys
    }
    
    # Create pillbox selection highlight
    static [string] GetPillboxHighlight([string]$text, [int]$width) {
        $theme = [ColorThemeService]::Themes[[ColorThemeService]::CurrentTheme]
        $bg = $theme["PillboxBG"]
        $fg = $theme["CommandSelected"]
        
        # Create pillbox effect with background color and padding
        $paddedText = [Measure]::Pad($text, $width - 2, "Left")
        return "$bg$fg $paddedText $([VT]::Reset())"
    }
    
    # Create tag highlight
    static [string] GetTagDisplay([string]$tag, [bool]$highlighted = $false) {
        $color = if ($highlighted) {
            [ColorThemeService]::GetColor("TagHighlight")
        } else {
            [ColorThemeService]::GetColor("Tag")
        }
        return "$color#$tag$([VT]::Reset())"
    }
    
    # Create group header display
    static [string] GetGroupHeader([string]$groupName) {
        $color = [ColorThemeService]::GetColor("GroupHeader")
        $border = [ColorThemeService]::GetColor("Border")
        return "$color$groupName$([VT]::Reset())`n$border$([VT]::H() * $groupName.Length)$([VT]::Reset())"
    }
    
    # Create status message with appropriate color
    static [string] GetStatusMessage([string]$message, [string]$type = "Info") {
        $color = [ColorThemeService]::GetColor($type)
        return "$color$message$([VT]::Reset())"
    }
    
    # Create usage count display
    static [string] GetUsageDisplay([int]$count) {
        if ($count -eq 0) { return "" }
        $color = [ColorThemeService]::GetColor("Info")
        return "$color★$count$([VT]::Reset())"
    }
    
    # Create command highlight for search results
    static [string] GetSearchHighlight([string]$text, [string]$searchTerm) {
        if ([string]::IsNullOrWhiteSpace($searchTerm)) {
            return $text
        }
        
        $highlightColor = [ColorThemeService]::GetColor("CommandHighlight")
        $resetColor = [ColorThemeService]::GetColor("Command")
        
        # Simple case-insensitive highlighting
        $pattern = [regex]::Escape($searchTerm)
        return $text -replace "(?i)($pattern)", "$highlightColor`$1$resetColor"
    }
}

# Global theme functions for easy access
function Get-ThemeColor {
    param([string]$Element)
    return [ColorThemeService]::GetColor($Element)
}

function Set-CommandTheme {
    param([string]$ThemeName)
    [ColorThemeService]::SetTheme($ThemeName)
}

function Get-AvailableThemes {
    return [ColorThemeService]::GetAvailableThemes()
}

# Enhanced display functions
function Format-CommandDisplay {
    param(
        [object]$Command,
        [bool]$Selected = $false,
        [int]$Width = 80,
        [string]$SearchTerm = ""
    )
    
    if (-not $Command) { return "" }
    
    $displayText = $Command.GetDisplayText()
    
    # Apply search highlighting
    if ($SearchTerm) {
        $displayText = [ColorThemeService]::GetSearchHighlight($displayText, $SearchTerm)
    }
    
    # Add usage count if > 0
    if ($Command.UseCount -gt 0) {
        $usageDisplay = [ColorThemeService]::GetUsageDisplay($Command.UseCount)
        $displayText += " $usageDisplay"
    }
    
    # Add tags with color
    if ($Command.Tags.Count -gt 0) {
        $tagDisplay = ""
        foreach ($tag in $Command.Tags) {
            $tagDisplay += " " + [ColorThemeService]::GetTagDisplay($tag)
        }
        $displayText += $tagDisplay
    }
    
    # Apply selection highlighting
    if ($Selected) {
        return [ColorThemeService]::GetPillboxHighlight($displayText, $Width)
    } else {
        $color = [ColorThemeService]::GetColor("Command")
        return "$color$displayText$([VT]::Reset())"
    }
}

function Format-GroupHeader {
    param([string]$GroupName)
    return [ColorThemeService]::GetGroupHeader($GroupName)
}

function Format-StatusMessage {
    param([string]$Message, [string]$Type = "Info")
    return [ColorThemeService]::GetStatusMessage($Message, $Type)
}