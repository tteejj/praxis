# ColorThemeService.ps1 - Bridge ColorThemeService for CommandLibrary integration
# Provides ColorThemeService API that works with TaskPro's UnifiedThemeService

class ColorThemeService {
    # Static theme data - simplified for compatibility
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
    }
    
    static [string]$CurrentTheme = "default"
    
    # Get color for specific element
    static [string] GetColor([string]$element) {
        # Try to use TaskPro's theme system if available
        try {
            if ([UnifiedThemeService] -and [UnifiedThemeService]::IsInitialized) {
                # Map CommandLibrary elements to TaskPro theme keys
                $themeKey = switch ($element) {
                    "Border" { "window.border" }
                    "Command" { "text.primary" }
                    "CommandSelected" { "text.accent" }
                    "CommandHighlight" { "text.accent" }
                    "Tag" { "text.secondary" }
                    "TagHighlight" { "text.accent" }
                    "PillboxBG" { "background.secondary" }
                    "Success" { "status.success" }
                    "Warning" { "status.warning" }
                    "Error" { "status.error" }
                    "Info" { "status.info" }
                    default { $element }
                }
                
                $color = [UnifiedThemeService]::GetColor($themeKey)
                if ($color) {
                    return $color
                }
            }
        } catch {
            # Fall through to static themes
        }
        
        # Fallback to static theme
        $theme = [ColorThemeService]::Themes[[ColorThemeService]::CurrentTheme]
        if ($theme.ContainsKey($element)) {
            return $theme[$element]
        }
        
        # Final fallback - return reset
        return "`e[0m"
    }
    
    # Set theme (compatibility method)
    static [void] SetTheme([string]$themeName) {
        if ([ColorThemeService]::Themes.ContainsKey($themeName)) {
            [ColorThemeService]::CurrentTheme = $themeName
        }
    }
    
    # Get available themes
    static [string[]] GetAvailableThemes() {
        return [ColorThemeService]::Themes.Keys
    }
    
    # Create pillbox selection highlight
    static [string] GetPillboxHighlight([string]$text, [int]$width) {
        $bg = [ColorThemeService]::GetColor("PillboxBG")
        $fg = [ColorThemeService]::GetColor("CommandSelected")
        
        # Simple padding - pad to width-2 for borders
        $maxTextWidth = [Math]::Max(1, $width - 2)
        $paddedText = if ($text.Length -gt $maxTextWidth) {
            $text.Substring(0, $maxTextWidth)
        } else {
            $text.PadRight($maxTextWidth)
        }
        
        return "$bg$fg $paddedText `e[0m"
    }
    
    # Create tag highlight
    static [string] GetTagDisplay([string]$tag, [bool]$highlighted = $false) {
        $color = if ($highlighted) {
            [ColorThemeService]::GetColor("TagHighlight")
        } else {
            [ColorThemeService]::GetColor("Tag")
        }
        return "$color#$tag`e[0m"
    }
    
    # Create group header display
    static [string] GetGroupHeader([string]$groupName) {
        $color = [ColorThemeService]::GetColor("GroupHeader")
        $border = [ColorThemeService]::GetColor("Border")
        $line = "-" * $groupName.Length
        return "$color$groupName`e[0m`n$border$line`e[0m"
    }
    
    # Create status message with appropriate color
    static [string] GetStatusMessage([string]$message, [string]$type = "Info") {
        $color = [ColorThemeService]::GetColor($type)
        return "$color$message`e[0m"
    }
    
    # Create usage count display
    static [string] GetUsageDisplay([int]$count) {
        if ($count -eq 0) { return "" }
        $color = [ColorThemeService]::GetColor("Info")
        return "$color★$count`e[0m"
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

# Global formatting functions for CommandLibrary compatibility
function global:Format-CommandDisplay {
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
            $tagDisplay += " " + [ColorThemeService]::GetTagDisplay($tag, $false)
        }
        $displayText += $tagDisplay
    }
    
    # Apply selection highlighting
    if ($Selected) {
        return [ColorThemeService]::GetPillboxHighlight($displayText, $Width)
    } else {
        $color = [ColorThemeService]::GetColor("Command")
        return "$color$displayText`e[0m"
    }
}

function global:Format-GroupHeader {
    param([string]$GroupName)
    return [ColorThemeService]::GetGroupHeader($GroupName)
}

function global:Format-StatusMessage {
    param([string]$Message, [string]$Type = "Info")
    return [ColorThemeService]::GetStatusMessage($Message, $Type)
}